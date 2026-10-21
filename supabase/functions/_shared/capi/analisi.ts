// La scheda di un capo dal nome (aggiunta a mano) o dei capi di una foto
// (scan): il modello riempie, il codice pulisce, Jev controlla. I servizi sono
// passati da fuori (veri nella Edge Function item-metadata, finti nei test).
import { bloccoImmagine } from "../immagine.ts";
import type { ChiediJev } from "../valigia/jev.ts";
import {
  domandeJev, dubbi, type Dubbio, leggiJson, MAX_CAPI_SCAN, normalizza, promptNome, promptScan, pulisciNome,
  statoJev,
} from "./scheda.ts";

type Record_ = Record<string, any>;

// Tetti di uscita: il ragionamento di Claude Haiku 5.5 rientra in max_tokens
// (con gpt-4o-mini erano 400 per il nome e 1500 per la foto).
export const MAX_TOKENS_NOME = 2000;
export const MAX_TOKENS_FOTO = 4000;

/** Una chiamata al modello: il contenuto del messaggio utente -> il testo della risposta. */
export type ChiediModello = (contenuto: string | Record_[], maxTokens: number) => Promise<string>;

export interface ServiziScheda {
  modello: ChiediModello;
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

/** Aggiunta a mano: un capo dal nome digitato. Modello e Jev in parallelo;
 *  una risposta del modello illeggibile si richiede una volta. */
export async function schedaDaNome(nome: string, s: ServiziScheda): Promise<RisultatoScheda> {
  const n = pulisciNome(nome);
  const note: string[] = [];
  const chiediModello = async () => {
    for (let i = 1; ; i++) {
      const g = leggiJson(await s.modello(promptNome(n), MAX_TOKENS_NOME));
      if (g !== null && typeof g === "object" && !Array.isArray(g)) return g;
      if (i >= 2) throw new RispostaIlleggibile("risposta del modello non leggibile");
    }
  };
  // Jev legge solo il nome: non aspetta il modello.
  const jevNome = s.jev
    ? s.jev(statoJev({ name: n }, false), domandeJev()).then((r) => r.answers, (e) => {
      note.push(`jev: ${(e as Error).message}`);
      return null;
    })
    : Promise.resolve(null);
  const [g, risposte] = await Promise.all([chiediModello(), jevNome]);
  const z = normalizza(g, n);
  return { items: [{ metadata: z.metadata, app_category: z.app_category, dubbi: dubbi(z, risposte) }], note_tecniche: note };
}

/** Scan: i capi indossati nella foto (al massimo MAX_CAPI_SCAN). Una risposta
 *  che non e' JSON vale "nessun capo" (es. il modello dice che non vede vestiti). */
export async function schedeDaFoto(immagineBase64: string, s: ServiziScheda): Promise<RisultatoScheda> {
  // L'immagine prima del testo, come consiglia Anthropic.
  const testo = await s.modello([bloccoImmagine(immagineBase64), { type: "text", text: promptScan() }],
    MAX_TOKENS_FOTO);
  const g = leggiJson(testo);
  const grezzi = Array.isArray(g) ? g : g !== null && typeof g === "object" ? [g] : [];
  const note: string[] = [];
  const items = await Promise.all(grezzi.slice(0, MAX_CAPI_SCAN)
    .map((x) => controlla(normalizza(x), true, s.jev, note)));
  return { items, note_tecniche: note };
}
