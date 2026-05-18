# Users Table & GPT Usage Enforcement — Design Spec

## Obiettivo

Creare una tabella `public.users` su Supabase che specchi ogni utente autenticato e traccia il consumo mensile di chiamate GPT. La `openai-proxy` Edge Function viene estesa per verificare l'identità dell'utente, enforzare il cap mensile e incrementare il contatore in modo atomico (no race condition). In caso di errore OpenAI, il contatore viene decrementato (compensating transaction).

---

## Contesto esistente

- `auth.users`: tabella Supabase built-in, gestita da Auth. Tutte le tabelle sync (`houses`, `items`, `trips`) usano `user_id` come FK verso `auth.users`.
- `app_config`: tabella key-value esistente, usata da `TombstoneConfigService` per leggere `tombstone_retention_days`. **Non è la stessa cosa di `users`.**
- `supabase/functions/openai-proxy/index.ts`: proxy HTTP verso OpenAI. Attualmente **non verifica il JWT** — invia la anon key come token, non il JWT utente. Questo design lo mette in sicurezza e aggiunge autenticazione per-utente.
- `lib/features/ai_input/service/ai_clothing_analyzer_service.dart`: chiama la proxy con `http.Client` iniettato. Usa `gpt-4o` Vision con `max_tokens: 1000` — risposta JSON strutturata completa (no streaming).

---

## Schema della tabella `users`

```sql
CREATE TABLE public.users (
  id                  uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text NOT NULL,
  gpt_monthly_count   integer NOT NULL DEFAULT 0,
  gpt_monthly_cap     integer NOT NULL DEFAULT 50,
  gpt_count_reset_at  timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now()
);
```

### Campi

| Campo | Tipo | Note |
|---|---|---|
| `id` | `uuid` | PK = stesso UUID di `auth.users`. Nessun ID separato. |
| `email` | `text` | Copiato da `auth.users.email` al momento della creazione. Cosmetic — non sincronizzato se l'utente cambia email. |
| `gpt_monthly_count` | `integer` | Contatore chiamate GPT nel mese corrente. Reset lazy. |
| `gpt_monthly_cap` | `integer` | Cap massimo mensile. Default 50. Modificabile a mano dalla Dashboard Supabase. |
| `gpt_count_reset_at` | `timestamptz` | Timestamp dell'ultimo reset mensile. Usato per il lazy reset. |
| `created_at` | `timestamptz` | Immutabile. |

---

## Creazione automatica della riga utente

Trigger su `auth.users` — si attiva ad ogni nuovo signup/login Google. Usa `SECURITY DEFINER` (pattern standard Supabase).

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

`ON CONFLICT (id) DO NOTHING` garantisce idempotenza: se la riga esiste già (es. re-run della migration), non fallisce.

---

## Row Level Security (RLS)

```sql
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- L'utente autenticato può leggere solo il proprio record (es. per mostrare il contatore in UI)
CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- Nessuna UPDATE/DELETE dal client Flutter.
-- Tutte le scritture avvengono tramite la Edge Function con service role key.
```

La Edge Function usa `SUPABASE_SERVICE_ROLE_KEY` (env var iniettata automaticamente da Supabase) → bypassa RLS completamente.

---

## Funzioni SQL

### `increment_gpt_count` — check cap + incremento atomico

La logica di reset + check + increment è incapsulata in una singola funzione SQL transazionale — nessuna finestra di race (TOCTOU) tra lettura e scrittura.

```sql
CREATE OR REPLACE FUNCTION public.increment_gpt_count(
  p_user_id uuid,
  p_now     timestamptz
)
RETURNS boolean AS $$
DECLARE
  v_reset_needed boolean;
  v_new_count    integer;
BEGIN
  SELECT (
    date_trunc('month', p_now) > date_trunc('month', gpt_count_reset_at)
  )
  INTO v_reset_needed
  FROM public.users
  WHERE id = p_user_id;

  IF v_reset_needed THEN
    -- Nuovo mese: azzera e imposta a 1 (questa chiamata è la prima del mese)
    UPDATE public.users
    SET
      gpt_monthly_count  = 1,
      gpt_count_reset_at = p_now
    WHERE id = p_user_id
    RETURNING gpt_monthly_count INTO v_new_count;
    RETURN true;
  ELSE
    -- Stesso mese: incrementa solo se count < cap
    UPDATE public.users
    SET gpt_monthly_count = gpt_monthly_count + 1
    WHERE id = p_user_id
      AND gpt_monthly_count < gpt_monthly_cap
    RETURNING gpt_monthly_count INTO v_new_count;

    -- Se UPDATE non ha trovato righe (count >= cap) → false
    RETURN v_new_count IS NOT NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### `decrement_gpt_count` — rollback (compensating transaction)

Usata dall'Edge Function quando OpenAI restituisce un errore dopo che il contatore era già stato incrementato. `GREATEST(..., 0)` previene valori negativi in casi limite.

```sql
CREATE OR REPLACE FUNCTION public.decrement_gpt_count(p_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET gpt_monthly_count = GREATEST(gpt_monthly_count - 1, 0)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Edge Function — `openai-proxy` estesa

### Flusso completo

```
1. Verifica JWT (auth.getUser)
2. Check cap + incrementa (query atomica) → 429 se cap raggiunto
3. Forward a OpenAI
4a. Successo → return response
4b. Errore OpenAI → decrement_gpt_count (rollback) → return errore
```

### Note architetturali

- `supabaseAdmin` è inizializzato **fuori da `Deno.serve()`** per essere riutilizzato nelle warm invocations (cold start optimization).
- Il rollback su errore OpenAI è best-effort: se anche il decremento fallisce (es. Supabase temporaneamente irraggiungibile), il contatore rimane sfasato di 1. Limite accettabile dei sistemi distribuiti senza coordinator centralizzato.
- Il timeout delle Edge Function dipende dal piano Supabase: **2 secondi sul free plan** (insufficiente per GPT-4o Vision), **25 secondi sul Pro**. La funzione usa `await response.text()` (risposta completa, no streaming) — assicurarsi di essere su un piano con timeout adeguato.

### `openai-proxy/index.ts` completo

```typescript
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Inizializzato fuori dall'handler per riuso nelle warm invocations
const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed");
  }

  // 1. Verifica JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return errorResponse(401, "Missing authorization");

  const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (authError || !user) return errorResponse(401, "Invalid token");

  // 2. Check cap + incremento atomico
  const { data: allowed, error: rpcError } = await supabaseAdmin.rpc(
    "increment_gpt_count",
    { p_user_id: user.id, p_now: new Date().toISOString() },
  );
  if (rpcError) return errorResponse(500, "Usage check failed");
  if (!allowed) return errorResponse(429, "Monthly GPT limit reached");

  // 3. Forward a OpenAI (con rollback in caso di errore)
  const apiKey = Deno.env.get("OPENAI_KEY");
  if (!apiKey) {
    await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
    return errorResponse(500, "OPENAI_KEY not configured");
  }

  try {
    const body = await req.text();
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body,
    });

    if (!response.ok) {
      // Rollback: OpenAI ha risposto con 4xx/5xx — l'utente non ha ricevuto valore
      await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
      const errorText = await response.text();
      return errorResponse(response.status, `OpenAI error: ${errorText}`);
    }

    const data = await response.text();
    return new Response(data, {
      status: response.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error) {
    // Rollback: errore di rete (timeout, DNS, ecc.)
    await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
    return errorResponse(500, "Network error communicating with AI provider");
  }
});
```

---

## Flutter — invio del JWT

Il servizio attuale (`AiClothingAnalyzerService`) invia la **anon key** come Bearer token — non verificabile per-utente. Va sostituito con il client SDK Supabase, che inietta automaticamente il JWT dell'utente e gestisce il refresh del token.

### Approccio consigliato: `SupabaseClient` iniettato

Invece di `http.Client` + URL manuale, il servizio riceve un `SupabaseClient` e usa `functions.invoke()`:

```dart
// Costruzione del servizio (in bootstrap o provider)
AiClothingAnalyzerService(
  supabaseClient: Supabase.instance.client,
)

// Nel servizio, al posto di _client.post(Uri.parse(_proxyUrl), ...):
final response = await _supabaseClient.functions.invoke(
  'openai-proxy',
  body: jsonBody, // stesso payload costruito oggi
);

if (response.status == 429) {
  throw VisionAnalysisException('Monthly GPT limit reached');
}
if (response.status != 200) {
  throw VisionAnalysisException('OpenAI returned ${response.status}');
}
// response.data contiene il body già decodificato
```

Vantaggi: token refresh automatico, nessuna gestione manuale del JWT, testabile (inietti un `SupabaseClient` mock).

---

## File da creare/modificare

```
CREA (SQL — Dashboard Supabase → SQL Editor):
  - Tabella public.users
  - Funzione handle_new_user() + trigger on_auth_user_created
  - RLS policy "users_select_own"
  - Funzione increment_gpt_count()
  - Funzione decrement_gpt_count()

MODIFICA:
  supabase/functions/openai-proxy/index.ts
    — supabaseAdmin fuori dall'handler
    — auth JWT verification
    — atomic increment + rollback on OpenAI error

  lib/features/ai_input/service/ai_clothing_analyzer_service.dart
    — sostituisce http.Client con SupabaseClient iniettato
    — usa functions.invoke() invece di _client.post()
    — gestisce status 429 con VisionAnalysisException dedicata
```

**Nota**: il progetto non usa migration files Supabase (`supabase/migrations/`). L'approccio preferito è eseguire le query SQL dalla Dashboard Supabase → SQL Editor.

---

## Edge cases

- **Utente non ha ancora la riga in `users`** (es. utente esistente prima della migration): il trigger garantisce la riga al primo login. Per utenti già presenti, eseguire questo backfill una-tantum dalla Dashboard:
  ```sql
  INSERT INTO public.users (id, email)
  SELECT id, email FROM auth.users
  ON CONFLICT (id) DO NOTHING;
  ```
- **Reset mensile**: lazy, avviene sulla prima chiamata GPT del nuovo mese. Nessun cron.
- **Rollback che fallisce**: se `decrement_gpt_count` fallisce (Supabase irraggiungibile), il contatore rimane sfasato di +1. Limite noto dei sistemi distribuiti senza saga coordinator — accettabile per questa scala.
- **Timeout Edge Function**: su free plan (2s) la funzione verrà killata prima che GPT-4o Vision risponda. Richede piano Pro (25s). No streaming — la risposta JSON completa è necessaria prima del parsing.
- **JWT scaduto**: `auth.getUser` ritorna errore → 401. Il SDK Flutter (`supabase_flutter`) gestisce il refresh automaticamente quando si usa `functions.invoke()`.
