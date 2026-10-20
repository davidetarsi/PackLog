// La scheda di un capo dal nome (aggiunta a mano) o dei capi di una foto
// (scan): GPT riempie, il codice pulisce, Jev controlla. I servizi sono passati
// da fuori (veri nella Edge Function item-metadata, finti nei test).
import type { ChiediJev } from "../valigia/jev.ts";
import {
  domandeJev, dubbi, type Dubbio, leggiJson, MAX_CAPI_SCAN, normalizza, promptNome, promptScan, pulisciNome,
  statoJev,
} from "./scheda.ts";

type Record_ = Record<string, any>;

export const MODELLO = "gpt-4o-mini";
// Nome: le impostazioni della prova sulla lista di Davide (bench, call_llm).
export const NOME = { max_tokens: 400, temperature: 0.2 };
// Foto: quelle di openai-proxy.
export const FOTO = { max_tokens: 1500, temperature: 0.0, detail: "high" };

/** Una chiamata al modello: il contenuto del messaggio utente -> il testo della risposta. */
export type ChiediGpt = (contenuto: string | Record_[], opzioni: { max_tokens: number; temperature: number }) =>
  Promise<string>;

export interface ServiziScheda {
  gpt: ChiediGpt;
  jev: ChiediJev | null;
}

export interface Capo {
  /** Da salvare in items.ai_metadata (JSON). */
  metadata: Record_;
  /** items.category: vestiti, varie, toiletries, elettronica. */
  app_category: string;
  /** Le etichette da chiedere all'utente, nell'ordine; [] = niente da chiedere. */
  dubbi: Dubbio[];
}

export interface RisultatoScheda {
  items: Capo[];
  /** Cio' che non ha risposto (Jev e' un aiuto: la scheda si fa lo stesso). */
  note_tecniche: string[];
}

export class RispostaIlleggibile extends Error {}

async function controlla(z: ReturnType<typeof normalizza>, daFoto: boolean, jev: ChiediJev | null,
  note: string[]): Promise<Capo> {
  let risposte: Record_ | null = null;
  if (jev) {
    try {
      risposte = (await jev(statoJev(z.metadata, daFoto), domandeJev())).answers;
    } catch (e) {
      note.push(`jev: ${(e as Error).message}`);
    }
  }
  return { metadata: z.metadata, app_category: z.app_category, dubbi: dubbi(z, risposte) };
}

/** Aggiunta a mano: un capo dal nome digitato. GPT e Jev in parallelo; una
 *  risposta di GPT illeggibile si richiede una volta. */
export async function schedaDaNome(nome: string, s: ServiziScheda): Promise<RisultatoScheda> {
  const n = pulisciNome(nome);
  const note: string[] = [];
  const chiediGpt = async () => {
    for (let i = 1; ; i++) {
      const g = leggiJson(await s.gpt(promptNome(n), NOME));
      if (g !== null && typeof g === "object" && !Array.isArray(g)) return g;
      if (i >= 2) throw new RispostaIlleggibile("risposta del modello non leggibile");
    }
  };
  // Jev legge solo il nome: non aspetta GPT.
  const jevNome = s.jev
    ? s.jev(statoJev({ name: n }, false), domandeJev()).then((r) => r.answers, (e) => {
      note.push(`jev: ${(e as Error).message}`);
      return null;
    })
    : Promise.resolve(null);
  const [g, risposte] = await Promise.all([chiediGpt(), jevNome]);
  const z = normalizza(g, n);
  return { items: [{ metadata: z.metadata, app_category: z.app_category, dubbi: dubbi(z, risposte) }], note_tecniche: note };
}

/** Scan: i capi indossati nella foto (al massimo MAX_CAPI_SCAN). Una risposta
 *  che non e' JSON vale "nessun capo" (es. GPT dice che non vede vestiti). */
export async function schedeDaFoto(immagineBase64: string, s: ServiziScheda): Promise<RisultatoScheda> {
  const testo = await s.gpt([
    { type: "text", text: promptScan() },
    { type: "image_url", image_url: { url: `data:image/png;base64,${immagineBase64}`, detail: FOTO.detail } },
  ], { max_tokens: FOTO.max_tokens, temperature: FOTO.temperature });
  const g = leggiJson(testo);
  const grezzi = Array.isArray(g) ? g : g !== null && typeof g === "object" ? [g] : [];
  const note: string[] = [];
  const items = await Promise.all(grezzi.slice(0, MAX_CAPI_SCAN)
    .map((x) => controlla(normalizza(x), true, s.jev, note)));
  return { items, note_tecniche: note };
}

/** La chiamata vera a OpenAI (la chiave resta lato server). */
export function openaiScheda(chiave: string, fetchFn: typeof fetch = fetch, timeoutMs = 60000): ChiediGpt {
  return async (contenuto, opzioni) => {
    const r = await fetchFn("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${chiave}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODELLO, messages: [{ role: "user", content: contenuto }],
        max_tokens: opzioni.max_tokens, temperature: opzioni.temperature,
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (r.status >= 400) {
      const e = new Error(`${MODELLO}: ${r.status} ${(await r.text()).slice(0, 300)}`) as Error & { status?: number };
      e.status = r.status;
      throw e;
    }
    const d = await r.json();
    return d.choices[0].message.content;
  };
}
