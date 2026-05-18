# Users Table & GPT Usage Enforcement — Design Spec

## Obiettivo

Creare una tabella `public.users` su Supabase che specchi ogni utente autenticato e traccia il consumo mensile di chiamate GPT. La `openai-proxy` Edge Function viene estesa per verificare l'identità dell'utente, enforzare il cap mensile e incrementare il contatore in modo atomico (no race condition).

---

## Contesto esistente

- `auth.users`: tabella Supabase built-in, gestita da Auth. Tutte le tabelle sync (`houses`, `items`, `trips`) usano `user_id` come FK verso `auth.users`.
- `app_config`: tabella key-value esistente, usata da `TombstoneConfigService` per leggere `tombstone_retention_days`. **Non è la stessa cosa di `users`.**
- `supabase/functions/openai-proxy/index.ts`: proxy HTTP verso OpenAI. Attualmente **non verifica il JWT** — chiunque con la anon key può chiamarla. Questo design la mette in sicurezza.

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

## Edge Function — `openai-proxy` estesa

### Flusso completo

```
1. Verifica JWT (auth.getUser)
2. Leggi + check cap + incrementa (query atomica)
3. Se cap raggiunto → 429
4. Forward a OpenAI
5. Return response
```

### Incremento atomico (fix race condition TOCTOU)

Check e increment avvengono in **una sola query** — nessuna finestra di race tra lettura e scrittura:

```typescript
// Controlla se serve reset mensile
const now = new Date();

// Tenta update atomico: incrementa solo se count < cap e (se mese cambiato) resetta prima
const { data: updated } = await supabase.rpc('increment_gpt_count', {
  p_user_id: user.id,
  p_now: now.toISOString(),
});

if (!updated) {
  return errorResponse(429, 'Monthly GPT limit reached');
}
```

La logica di reset + check + increment è incapsulata in una funzione SQL:

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
    UPDATE public.users
    SET
      gpt_monthly_count  = 1,
      gpt_count_reset_at = p_now
    WHERE id = p_user_id
    RETURNING gpt_monthly_count INTO v_new_count;
    RETURN true;
  ELSE
    UPDATE public.users
    SET gpt_monthly_count = gpt_monthly_count + 1
    WHERE id = p_user_id
      AND gpt_monthly_count < gpt_monthly_cap
    RETURNING gpt_monthly_count INTO v_new_count;

    RETURN v_new_count IS NOT NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

`RETURN false` (→ cap raggiunto) quando l'UPDATE nella branch ELSE non trova righe perché `count >= cap`.

### `openai-proxy/index.ts` completo

```typescript
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (authError || !user) return errorResponse(401, "Invalid token");

  // 2. Check cap + incremento atomico
  const { data: allowed, error: rpcError } = await supabase.rpc(
    "increment_gpt_count",
    { p_user_id: user.id, p_now: new Date().toISOString() },
  );
  if (rpcError) return errorResponse(500, "Usage check failed");
  if (!allowed) return errorResponse(429, "Monthly GPT limit reached");

  // 3. Forward a OpenAI
  const apiKey = Deno.env.get("OPENAI_KEY");
  if (!apiKey) return errorResponse(500, "OPENAI_KEY not configured");

  const body = await req.text();
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body,
  });

  const data = await response.text();
  return new Response(data, {
    status: response.status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
});
```

---

## Flutter — invio del JWT

La `openai-proxy` ora richiede il JWT nell'header `Authorization`. Il client deve includerlo:

```dart
// In AiClothingAnalyzerService (o dove viene costruita la request)
final session = Supabase.instance.client.auth.currentSession;
final jwt = session?.accessToken ?? '';

// Aggiungere all'header della chiamata HTTP esistente:
headers: {
  'Authorization': 'Bearer $jwt',
  'Content-Type': 'application/json',
  'apikey': AppConfig.supabaseAnonKey,
}
```

---

## File da creare/modificare

```
CREA (SQL — eseguiti dalla Dashboard Supabase o migration file):
  - Tabella public.users
  - Trigger on_auth_user_created + funzione handle_new_user()
  - RLS policies su public.users
  - Funzione SQL increment_gpt_count()

MODIFICA:
  supabase/functions/openai-proxy/index.ts   — authn + atomic increment
  lib/features/ai_input/...                  — aggiunge JWT header alla request HTTP
```

**Nota**: il progetto non usa migration files Supabase (`supabase/migrations/`). L'approccio preferito è eseguire le query SQL dalla Dashboard Supabase → SQL Editor, oppure creare un migration file se si vuole iniziare a versionare lo schema.

---

## Edge cases

- **Utente non ha ancora la riga in `users`** (creata prima del trigger): `increment_gpt_count` ritorna `null` per il SELECT → `v_reset_needed` è null → UPDATE non trova righe → `RETURN false` → 429. Soluzione: il trigger garantisce che la riga esista al primo login. Per utenti già esistenti in `auth.users` prima della migration, eseguire questo backfill una-tantum dalla Dashboard:
  ```sql
  INSERT INTO public.users (id, email)
  SELECT id, email FROM auth.users
  ON CONFLICT (id) DO NOTHING;
  ```
- **Reset il primo del mese**: lazy, avviene sulla prima chiamata GPT del nuovo mese. Nessun cron.
- **OpenAI ritorna errore**: il contatore è già stato incrementato prima del forward — si consuma quota anche su errori OpenAI. Trade-off accettabile per semplicità; l'alternativa sarebbe decrementare nel catch, ma introduce complessità.
- **JWT scaduto**: `auth.getUser` ritorna errore → 401. Il client Flutter deve fare refresh del token (gestito da `supabase_flutter` automaticamente).
