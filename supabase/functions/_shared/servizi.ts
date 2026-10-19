// Cio' che serve alle Edge Functions del generatore (pack-trip, trip-weather):
// risposte HTTP, utente dal JWT, limite d'uso per utente, Open-Meteo con la
// cache in tabella. Il client Supabase e' passato da fuori (service role).
import type { Risposta, Servizi } from "./clima/meteo.ts";

// deno-lint-ignore no-explicit-any
type Db = any;

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(status: number, corpo: unknown): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export const errore = (status: number, messaggio: string) => json(status, { error: messaggio });

/** L'utente del JWT (difesa in profondita': il gateway lo verifica gia'). */
export async function utente(db: Db, req: Request): Promise<{ id: string } | Response> {
  const h = req.headers.get("Authorization");
  if (!h) return errore(401, "Missing authorization");
  const { data: { user }, error } = await db.auth.getUser(h.startsWith("Bearer ") ? h.slice(7) : h);
  if (error || !user) return errore(401, "Invalid token");
  return { id: user.id };
}

/** Un uso in piu' nella finestra scorrevole; false se il tetto e' raggiunto. */
export async function consumaUso(db: Db, userId: string, tipo: string, tetto: number,
  finestraMinuti: number): Promise<boolean | Response> {
  const { data, error } = await db.rpc("increment_usage", {
    p_user_id: userId, p_kind: tipo, p_now: new Date().toISOString(),
    p_cap: tetto, p_window_minutes: finestraMinuti,
  });
  if (error) {
    console.error(`[${tipo}] increment_usage RPC error:`, error.message, error.code);
    return errore(500, "Rate-limit check failed");
  }
  return !!data;
}

const attesa = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** Con una chiave commerciale Open-Meteo risponde dagli host "customer-". */
function conChiave(url: string, chiave: string | undefined): string {
  return chiave ? url.replace("https://", "https://customer-") : url;
}

/** I servizi del meteo: rete con tre tentativi sulle cadute, cache in
 *  public.weather_cache (le normali climatiche non scadono, le previsioni
 *  valgono il giorno in cui sono state chieste). */
export function serviziMeteo(db: Db, chiaveOpenMeteo?: string, fetchFn: typeof fetch = fetch): Servizi {
  return {
    async scarica(url, params): Promise<Risposta> {
      const u = new URL(conChiave(url, chiaveOpenMeteo));
      for (const [k, v] of Object.entries(params)) u.searchParams.set(k, String(v));
      if (chiaveOpenMeteo) u.searchParams.set("apikey", chiaveOpenMeteo);
      for (let n = 0; ; n++) {
        try {
          const r = await fetchFn(u, { signal: AbortSignal.timeout(30000) });
          return { status: r.status, json: () => r.json() };
        } catch (e) {
          if (n === 2) throw e;
          await attesa(1000 * (n + 1));
        }
      }
    },
    async leggiCache(chiave) {
      const { data, error } = await db.from("weather_cache").select("data").eq("key", chiave).maybeSingle();
      if (error) console.error("[meteo] cache read:", error.message);
      return data?.data ?? null;
    },
    async scriviCache(chiave, valore) {
      const { error } = await db.from("weather_cache")
        .upsert({ key: chiave, data: valore, created_at: new Date().toISOString() });
      if (error) console.error("[meteo] cache write:", error.message);
    },
    // Il servizio gira in UTC: il giorno locale del bench e quello UTC coincidono.
    oggiUtc: () => new Date().toISOString().slice(0, 10),
    oggi: () => new Date().toISOString().slice(0, 10),
    attendi: (t) => attesa(1000 * (t + 1)),
  };
}

/** Il corpo JSON della richiesta, o una risposta 400. */
export async function corpo(req: Request, maxByte = 64 * 1024): Promise<Record<string, unknown> | Response> {
  const testo = await req.text();
  if (testo.length > maxByte) return errore(413, "Body too large");
  try {
    const x = JSON.parse(testo);
    return x && typeof x === "object" && !Array.isArray(x) ? x : errore(400, "Body must be a JSON object");
  } catch {
    return errore(400, "Invalid JSON");
  }
}
