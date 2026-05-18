# Users Table & GPT Usage Enforcement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Creare `public.users` su Supabase con tracking mensile GPT, proteggere `openai-proxy` con JWT auth + cap atomico + rollback, e aggiornare il servizio Flutter per inviare il JWT corretto.

**Architecture:** Tre layer indipendenti eseguiti in ordine: SQL (Supabase Dashboard), Edge Function (TypeScript deployata su Supabase), Flutter (Dart). Il layer Flutter viene modificato per ultimo così punta a una Edge Function già protetta. La testabilità del servizio Flutter è preservata tramite un `jwtProvider` iniettabile che isola la dipendenza da `Supabase.instance`.

**Tech Stack:** PostgreSQL/Supabase, Deno/TypeScript (Edge Functions), Flutter/Dart, `package:http` (MockClient per test)

---

## File Map

```
CREA:
  supabase/schema_users.sql                                          — SQL di riferimento (documentazione git)
  test/features/ai_input/service/ai_clothing_analyzer_service_test.dart

MODIFICA:
  supabase/functions/openai-proxy/index.ts                           — full rewrite
  lib/features/ai_input/service/ai_clothing_analyzer_service.dart    — JWT fix + GptLimitExceededException + jwtProvider
  lib/features/ai_input/view/ai_clothing_sandbox_screen.dart         — catch GptLimitExceededException separatamente
```

---

### Task 1: SQL — Tabella `users`, trigger, RLS e funzioni

**Files:**
- Create: `supabase/schema_users.sql`

Tutti i blocchi SQL vanno eseguiti in **Supabase Dashboard → SQL Editor** nell'ordine indicato. Il file `schema_users.sql` è documentazione git — non viene eseguito automaticamente.

- [ ] **Step 1: Crea la tabella `users`**

Apri Supabase Dashboard → SQL Editor. Esegui:

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

Verifica: Dashboard → Table Editor → `users`. Deve avere 6 colonne.

- [ ] **Step 2: Crea la funzione trigger e il trigger**

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

- [ ] **Step 3: Abilita RLS e crea la policy SELECT**

```sql
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);
```

- [ ] **Step 4: Crea `increment_gpt_count`**

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

- [ ] **Step 5: Crea `decrement_gpt_count`**

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

- [ ] **Step 6: Backfill utenti esistenti**

```sql
INSERT INTO public.users (id, email)
SELECT id, email FROM auth.users
ON CONFLICT (id) DO NOTHING;
```

Verifica:

```sql
SELECT COUNT(*) FROM public.users;
-- Deve corrispondere al numero di utenti in Dashboard → Authentication → Users
```

- [ ] **Step 7: Verifica le funzioni SQL**

Sostituisci `'<tuo-user-id>'` con il tuo UUID (Dashboard → Authentication → Users):

```sql
-- Test cap: portalo a 50 e verifica il blocco
UPDATE public.users SET gpt_monthly_count = 50 WHERE id = '<tuo-user-id>';
SELECT public.increment_gpt_count('<tuo-user-id>', now());
-- Expected: false

-- Test reset mensile: simula mese precedente
UPDATE public.users SET gpt_count_reset_at = now() - interval '2 months' WHERE id = '<tuo-user-id>';
SELECT public.increment_gpt_count('<tuo-user-id>', now());
-- Expected: true (reset, count ora = 1)

SELECT gpt_monthly_count FROM public.users WHERE id = '<tuo-user-id>';
-- Expected: 1

-- Cleanup: rimetti count a 0 per non consumare quota reale
UPDATE public.users SET gpt_monthly_count = 0 WHERE id = '<tuo-user-id>';
```

- [ ] **Step 8: Crea il file SQL di riferimento e committa**

Crea `supabase/schema_users.sql` con questo contenuto (tutto il SQL degli Step 1-5):

```sql
-- Users table: mirrors auth.users with GPT usage tracking
-- Execute in Supabase Dashboard → SQL Editor

CREATE TABLE public.users (
  id                  uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text NOT NULL,
  gpt_monthly_count   integer NOT NULL DEFAULT 0,
  gpt_monthly_cap     integer NOT NULL DEFAULT 50,
  gpt_count_reset_at  timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now()
);

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

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

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

CREATE OR REPLACE FUNCTION public.decrement_gpt_count(p_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET gpt_monthly_count = GREATEST(gpt_monthly_count - 1, 0)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

```bash
git add supabase/schema_users.sql
git commit -m "docs: add users table SQL schema reference"
```

---

### Task 2: Edge Function — `openai-proxy` con auth + cap + rollback

**Files:**
- Modify: `supabase/functions/openai-proxy/index.ts`

- [ ] **Step 1: Sostituisci `index.ts` con il codice aggiornato**

Sostituisci l'intero contenuto di `supabase/functions/openai-proxy/index.ts`:

```typescript
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Inizializzato fuori dall'handler per riuso nelle warm invocations
const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
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

  const {
    data: { user },
    error: authError,
  } = await supabaseAdmin.auth.getUser(authHeader.replace("Bearer ", ""));
  if (authError || !user) return errorResponse(401, "Invalid token");

  // 2. Check cap + incremento atomico (TOCTOU-safe)
  const { data: allowed, error: rpcError } = await supabaseAdmin.rpc(
    "increment_gpt_count",
    { p_user_id: user.id, p_now: new Date().toISOString() },
  );
  if (rpcError) return errorResponse(500, "Usage check failed");
  if (!allowed) return errorResponse(429, "Monthly GPT limit reached");

  // 3. Forward a OpenAI con compensating transaction su errore
  const apiKey = Deno.env.get("OPENAI_KEY");
  if (!apiKey) {
    await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
    return errorResponse(500, "OPENAI_KEY not configured");
  }

  try {
    const body = await req.text();
    const response = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body,
      },
    );

    if (!response.ok) {
      await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
      const errorText = await response.text();
      return errorResponse(response.status, `OpenAI error: ${errorText}`);
    }

    const data = await response.text();
    return new Response(data, {
      status: response.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (_error) {
    await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
    return errorResponse(500, "Network error communicating with AI provider");
  }
});
```

- [ ] **Step 2: Deploy della funzione**

```bash
supabase functions deploy openai-proxy
```

Expected output: `Done: openai-proxy`

Se non hai la Supabase CLI: `npm install -g supabase`, poi `supabase login`, poi ri-esegui il comando. In alternativa, copia il contenuto del file nella Dashboard → Edge Functions → `openai-proxy` → Edit.

- [ ] **Step 3: Verifica — chiamata senza JWT deve ritornare 401**

Sostituisci `<project-ref>` con il ref del tuo progetto Supabase (visibile nell'URL della Dashboard):

```bash
curl -s -X POST https://<project-ref>.supabase.co/functions/v1/openai-proxy \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

Expected:
```json
{"error":"Missing authorization"}
```
HTTP status: 401

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/openai-proxy/index.ts
git commit -m "feat: add JWT auth, atomic GPT cap and rollback to openai-proxy"
```

---

### Task 3: Flutter — JWT corretto + gestione cap in UI

**Files:**
- Modify: `lib/features/ai_input/service/ai_clothing_analyzer_service.dart`
- Modify: `lib/features/ai_input/view/ai_clothing_sandbox_screen.dart`
- Create: `test/features/ai_input/service/ai_clothing_analyzer_service_test.dart`

Il servizio attualmente invia `Bearer $_anonKey` come token di autenticazione (riga 197) — la anon key non è un token utente verificabile. Va sostituita con il JWT della sessione corrente. La anon key rimane necessaria come header `apikey` separato (usato da Supabase per il routing).

Per mantenere la testabilità senza inizializzare `Supabase.instance` nei test, si introduce un `jwtProvider` iniettabile: in produzione legge `Supabase.instance`, nei test riceve una funzione mock.

- [ ] **Step 1: Scrivi il test che descrive i nuovi comportamenti (TDD)**

Crea `test/features/ai_input/service/ai_clothing_analyzer_service_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stuff_tracker_2/features/ai_input/service/ai_clothing_analyzer_service.dart';

File _fakeImageFile() {
  final f = File('${Directory.systemTemp.path}/test_img.png')
    ..writeAsBytesSync(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]));
  return f;
}

AiClothingAnalyzerService _makeService(http.Client mockClient) =>
    AiClothingAnalyzerService(
      proxyUrl: 'https://fake.supabase.co/functions/v1/openai-proxy',
      anonKey: 'fake-anon-key',
      client: mockClient,
      jwtProvider: () => 'fake-jwt-token',
    );

void main() {
  group('AiClothingAnalyzerService', () {
    test('throws GptLimitExceededException on HTTP 429', () {
      final service = _makeService(
        MockClient(
          (_) async => http.Response('{"error":"Monthly GPT limit reached"}', 429),
        ),
      );

      expect(
        () => service.processClothingItem(_fakeImageFile()),
        throwsA(isA<GptLimitExceededException>()),
      );
    });

    test('throws VisionAnalysisException on HTTP 500', () {
      final service = _makeService(
        MockClient(
          (_) async => http.Response('{"error":"internal"}', 500),
        ),
      );

      expect(
        () => service.processClothingItem(_fakeImageFile()),
        throwsA(isA<VisionAnalysisException>()),
      );
    });

    test('throws VisionAnalysisException when jwtProvider returns null', () {
      final service = AiClothingAnalyzerService(
        proxyUrl: 'https://fake.supabase.co/functions/v1/openai-proxy',
        anonKey: 'fake-anon-key',
        jwtProvider: () => null,
      );

      expect(
        () => service.processClothingItem(_fakeImageFile()),
        throwsA(isA<VisionAnalysisException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Esegui il test — deve fallire**

```bash
flutter test test/features/ai_input/service/ai_clothing_analyzer_service_test.dart -v
```

Expected: errori di compilazione (`GptLimitExceededException` non esiste, `jwtProvider` non esiste). Questo conferma che i test guidano l'implementazione.

- [ ] **Step 3: Aggiungi `GptLimitExceededException` e `jwtProvider` al servizio**

Apri `lib/features/ai_input/service/ai_clothing_analyzer_service.dart`.

**3a.** Aggiungi l'import di supabase_flutter dopo gli import esistenti (riga ~7):

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

**3b.** Aggiungi la nuova exception dopo `VisionAnalysisException` (riga ~26):

```dart
/// Thrown when the user has reached their monthly GPT usage cap (HTTP 429).
final class GptLimitExceededException extends ClothingAnalysisException {
  const GptLimitExceededException(super.message);
}
```

**3c.** Aggiungi il campo `_jwtProvider` dopo `_client` (riga ~80):

```dart
final String? Function() _jwtProvider;
```

**3d.** Aggiorna il costruttore — aggiungi il parametro `jwtProvider` e l'inizializzazione del campo. Il costruttore completo diventa:

```dart
AiClothingAnalyzerService({
  required String proxyUrl,
  required String anonKey,
  http.Client? client,
  String? Function()? jwtProvider,
}) : _proxyUrl = proxyUrl,
     _anonKey = anonKey,
     _client = client ?? http.Client(),
     _jwtProvider = jwtProvider ??
         () => Supabase.instance.client.auth.currentSession?.accessToken;
```

- [ ] **Step 4: Aggiorna `_analyzeImage` — JWT + handling 429**

In `_analyzeImage`, sostituisci il blocco `final http.Response response; try { response = await _client.post(...` (righe 191-203) con:

```dart
final jwt = _jwtProvider();
if (jwt == null || jwt.isEmpty) {
  throw const VisionAnalysisException('User not authenticated');
}

final http.Response response;
try {
  response = await _client.post(
    Uri.parse(_proxyUrl),
    headers: {
      'Authorization': 'Bearer $jwt',
      'apikey': _anonKey,
      'Content-Type': 'application/json',
    },
    body: body,
  );
} on Exception catch (e) {
  throw VisionAnalysisException('Network error during vision analysis: $e');
}
```

Poi, aggiungi il check 429 **prima** del check `statusCode < 200 || statusCode >= 300` esistente (riga ~205):

```dart
if (response.statusCode == 429) {
  throw const GptLimitExceededException('Hai raggiunto il limite mensile di analisi AI.');
}

if (response.statusCode < 200 || response.statusCode >= 300) {
  throw VisionAnalysisException(
    'OpenAI returned ${response.statusCode}: ${response.body}',
  );
}
```

- [ ] **Step 5: Esegui i test — devono passare**

```bash
flutter test test/features/ai_input/service/ai_clothing_analyzer_service_test.dart -v
```

Expected: tutti e 3 i test PASS.

- [ ] **Step 6: Aggiorna la UI — catch `GptLimitExceededException` separatamente**

Apri `lib/features/ai_input/view/ai_clothing_sandbox_screen.dart`. Aggiungi il catch specifico **prima** del catch generico `ClothingAnalysisException` (riga 106). `GptLimitExceededException` è una sottoclasse di `ClothingAnalysisException`, quindi deve venire prima:

```dart
    } on GptLimitExceededException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      _showErrorSnackBar(e.message);
    } on ClothingAnalysisException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      _showErrorSnackBar(e.message);
    } catch (e) {
```

- [ ] **Step 7: Analisi e test suite completa**

```bash
dart analyze lib/features/ai_input/
```

Expected: no issues.

```bash
flutter test
```

Expected: tutti i test passano (413+ test).

- [ ] **Step 8: Test end-to-end**

Lancia l'app su simulatore/device. Vai su una casa → AI Import. Seleziona una foto e premi analizza.

Verifica in Supabase Dashboard → Table Editor → `users`:
- La colonna `gpt_monthly_count` è incrementata di 1 dopo la chiamata riuscita.

Se la chiamata fallisce con errore 401 → il JWT non viene inviato correttamente (controlla Step 3d).
Se la chiamata fallisce con errore 500 "Usage check failed" → la funzione SQL non è stata creata (controlla Task 1 Step 4).

- [ ] **Step 9: Commit**

```bash
git add lib/features/ai_input/service/ai_clothing_analyzer_service.dart \
        lib/features/ai_input/view/ai_clothing_sandbox_screen.dart \
        test/features/ai_input/service/ai_clothing_analyzer_service_test.dart
git commit -m "feat: fix JWT auth in AI service and add monthly GPT cap handling"
```
