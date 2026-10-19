// La regia del generatore: dal viaggio e dall'armadio alla valigia con i suoi
// motivi. Come riesegui_cella e la run dal vivo del bench: una sola chiamata
// al modello per viaggio (anche a tappe), Jev in parallelo, poi il codice.
// TypeScript puro: modello, Jev e meteo arrivano da fuori.
import { caricaArmadio, type RigaArmadio } from "./capo.ts";
import { type ChiediJev, datiJev, type DatiJev, type ProfiloNoto } from "./jev.ts";
import { motiviValigia, percheValigia, tagArmadio } from "./motivi.ts";
import { attivitaScenario, promptValigia } from "./prompt.ts";
import { parseJsonBlock, strategySlots } from "./slots.ts";
import { strategySlotsMultitappa } from "./tappe.ts";
import type { Luogo, Tappa } from "../clima/meteo.ts";

type Record_ = Record<string, any>;

/** Il viaggio come lo manda l'app. */
export interface ViaggioApp {
  /** "AAAA-MM-GG" */
  data_inizio: string;
  giorni: number;
  /** Una sola destinazione... */
  destinazione?: Luogo | null;
  /** ...oppure piu' tappe in fila, ognuna con i suoi giorni e le sue attivita'. */
  tappe?: Tappa[] | null;
  attivita?: string[] | null;
  /** Testo libero come nel bench: "trolley medio", "zaino da 40 litri", "borsa a tracolla". */
  bagaglio?: string | null;
  alloggio?: string | null;
  lavatrice?: boolean | null;
}

/** Lo scenario nella forma del bench, da cui partono prompt, Jev e matcher. */
export function scenarioDaApp(v: ViaggioApp): Record_ {
  const sc: Record_ = {
    data_inizio: v.data_inizio,
    giorni: v.giorni,
    attivita: [...(v.attivita ?? [])],
    bagaglio: v.bagaglio ?? "",
    alloggio: v.alloggio ?? "",
    lavatrice: !!v.lavatrice,
  };
  if (v.tappe?.length) {
    sc.legs = v.tappe.map((t) => ({ destinazione: t.nome, giorni: t.giorni, attivita: [...(t.attivita ?? [])] }));
  } else if (v.destinazione) {
    sc.destinazione = v.destinazione.nome;
    sc.paese = v.destinazione.paese ?? "";
  }
  return sc;
}

export interface Uso { prompt_tokens?: number; completion_tokens?: number; [k: string]: unknown }
export type ChiediModello = (prompt: string) => Promise<{ testo: string; uso?: Uso }>;

export interface Servizi {
  /** Geo e meteo del viaggio (clima/meteo.ts climaViaggio). */
  clima(sc: Record_): Promise<{ geo: Record_; meteo: Record_ }>;
  modello: ChiediModello;
  /** null: si va avanti senza Jev. */
  jev: ChiediJev | null;
  profiliNoti?: Record<string, ProfiloNoto>;
}

export interface Risultato {
  valigia: Record_;
  motivi: Record_;
  perche: Record_[];
  geo: Record_;
  meteo: Record_;
  jev: { profili_nuovi: Record<string, ProfiloNoto>; errori: string[] };
  uso?: Uso;
}

/** Il cuore: dato il testo del modello e i dati di Jev, la valigia (come riesegui_cella). */
export function valigiaDa(testo: string, sc: Record_, geo: Record_, meteo: Record_, righe: RigaArmadio[],
  jev: Partial<DatiJev>): Record_ {
  const items = caricaArmadio(righe);
  const extra: Record_ = {};
  for (const k of ["voti_scarpe", "profili_capi", "scarti_capi", "classi_viaggio"] as const) {
    if (jev[k]) extra[k] = jev[k];
  }
  if (geo.per_tappa?.length) {
    return strategySlotsMultitappa(testo, items, { sc, geo, bagaglio: sc.bagaglio ?? "", ...extra });
  }
  if (meteo.temp_min_assoluta != null) extra.temp_min_assoluta = meteo.temp_min_assoluta;
  return strategySlots(testo, items, {
    giorni: sc.giorni, lavatrice: sc.lavatrice, attivita: attivitaScenario(sc),
    temp_min: meteo.temp_min_media ?? null, temp_max: meteo.temp_max_media ?? null,
    bagaglio: sc.bagaglio ?? "", giorni_pioggia: meteo.giorni_di_pioggia ?? null,
    intensita: sc.intensita ?? null, ...extra,
  });
}

/** Tutto il giro: meteo, poi modello e Jev insieme, poi valigia e motivi. */
export async function generaValigia(sc: Record_, righe: RigaArmadio[], s: Servizi): Promise<Risultato> {
  const { geo, meteo } = await s.clima(sc);
  const prompt = promptValigia(sc, geo, meteo);
  const nessunJev: DatiJev = { profili_nuovi: {}, errori: ["Jev non configurato"] };
  const [risposta, jev] = await Promise.all([
    s.modello(prompt),
    s.jev ? datiJev(sc, geo, meteo, caricaArmadio(righe), s.jev, s.profiliNoti ?? {}) : nessunJev,
  ]);
  const valigia = valigiaDa(risposta.testo, sc, geo, meteo, righe, jev);
  const v = { scenario: sc, meteo, slots: valigia };
  const tag = tagArmadio(righe);
  const motivi = motiviValigia(v, tag);
  return {
    valigia, motivi, perche: percheValigia(v, tag, motivi), geo, meteo,
    jev: { profili_nuovi: jev.profili_nuovi, errori: jev.errori }, uso: risposta.uso,
  };
}

// ── Il modello: chiamata vera a OpenAI (chiave lato server) ─────────────────

export const MODELLO_OPENAI = "gpt-4o-mini";
export const MAX_TOKENS = 2500;
export const TEMPERATURA = 0.2;

export function openaiHttp(chiave: string, fetchFn: typeof fetch = fetch, timeoutMs = 120000): ChiediModello {
  return async (prompt) => {
    const r = await fetchFn("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${chiave}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODELLO_OPENAI, messages: [{ role: "user", content: prompt }],
        max_tokens: MAX_TOKENS, temperature: TEMPERATURA,
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (r.status >= 400) throw new Error(`${MODELLO_OPENAI}: ${r.status} ${(await r.text()).slice(0, 300)}`);
    const d = await r.json();
    return { testo: d.choices[0].message.content, uso: { ...(d.usage ?? {}), model: MODELLO_OPENAI } };
  };
}

/** Una risposta del modello che non e' un JSON leggibile si richiede una volta. */
export function conRiprova(chiedi: ChiediModello, tentativi = 2): ChiediModello {
  return async (prompt) => {
    for (let i = 1; ; i++) {
      const r = await chiedi(prompt);
      try {
        parseJsonBlock(r.testo);
        return r;
      } catch (e) {
        if (i >= tentativi) throw new Error(`risposta del modello non leggibile: ${(e as Error).message}`);
      }
    }
  };
}
