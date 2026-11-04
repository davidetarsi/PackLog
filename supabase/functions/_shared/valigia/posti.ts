// I posti della valigia dai mancanti del generatore: quanto e' importante un posto e come
// si chiama. Non tocca la scelta dei capi ne' gli avvisi (uscita.ts): e' un livello in piu'.
import type { Lingua } from "../lingua.ts";
import * as K from "./costanti.ts";
import { caricaArmadio, type Capo as CapoArmadio } from "./capo.ts";
import { canonicalizeGaps, capienzaBagaglio, lavanderiaPresunta } from "./dopo.ts";
import { scenarioDaApp, type ViaggioApp } from "./genera.ts";
import { eTrekking } from "./inject.ts";
import { attivitaScenario } from "./prompt.ts";
import { essenzialiPerViaggio, giorniDiMare, normIntensita, quantityFor, RADICI_NOTTE } from "./quantita.ts";
import { caldoUnCapoAlGiorno, camminoAPiedi } from "./regole_capi.ts";
import { ordinaTappe } from "./slots.ts";
import { servePerTappa } from "./tappe.ts";
import { attivitaPer, calore, capiUniti, capoDelGap, CODICE_LAVANDERIA, copyMancante, frasePochi, freddoPer, lavanderiaDelViaggio,
  meteoDelGap, perQuestoArmadio, SOLO_SE_NELL_ARMADIO, soloElegante, tettoSalvate } from "./uscita.ts";
import { NOMI_CATEGORIA, NOMI_FAMIGLIA, NOMI_SOTTOCATEGORIA, type NomePosto } from "./posti_nomi.ts";

export type Livello = "importante" | "utile";
export type Qualifica = "freddo" | "acqua" | "elegante";

type Capo = { sub: string | null; categoria: string };

// Sottocategorie d'attivita': senza, l'attivita' non si fa (Davide, 1 novembre).
const DA_ATTIVITA = new Set(["Hiking Boots", "Water Shoes", "Swimwear", "Wetsuit", "Ski Jacket", "Ski Pants",
  "Ski Suit", "Snow Boots"]);
const CATEGORIE_DEL_METEO = new Set(["Outerwear", "Shoes", "Accessory"]);

/** Importante solo cio' che dipende da questo viaggio: un'attivita', un'occasione elegante, il
 *  freddo o la pioggia per giacche, scarpe e accessori. Il resto (magliette, maglioni, strato
 *  termico compresi) e' utile. */
export function livelloPosto(g: Record<string, any>, capo: Capo, viaggioFreddo: boolean): Livello {
  // La muta si noleggia quasi sempre sul posto: al massimo utile (il costume resta importante).
  if (capo.sub === "Wetsuit") return "utile";
  if (capo.sub && DA_ATTIVITA.has(capo.sub)) return "importante";
  if (soloElegante(g)) return "importante";
  if (CATEGORIE_DEL_METEO.has(capo.categoria)) {
    const { freddo, acqua } = meteoDelGap(g, capo, viaggioFreddo);
    if (freddo || acqua) return "importante";
  }
  return "utile";
}

/** Cosa qualifica il nome del posto: il freddo, poi la pioggia, poi l'eleganza. */
export function qualificaDelGap(g: Record<string, any>, capo: Capo, viaggioFreddo: boolean): Qualifica | null {
  const { freddo, acqua } = meteoDelGap(g, capo, viaggioFreddo);
  if (freddo) return "freddo";
  if (acqua) return "acqua";
  return soloElegante(g) ? "elegante" : null;
}

// Qualificatori italiani: [singolare, plurale], o per genere e numero quando cambiano.
const IT_INVERNALE: [string, string] = ["invernale", "invernali"];
const IT_ACQUA: [string, string] = ["impermeabile", "impermeabili"];
const IT_ELEGANTE: [string, string] = ["elegante", "eleganti"];
const IT_CALDO = { m: ["caldo", "caldi"], f: ["calda", "calde"] } as const;
const EN_QUALIFICATORE: Record<Qualifica, (invernale: boolean) => string> = {
  freddo: (invernale) => (invernale ? "winter" : "warm"), acqua: () => "waterproof", elegante: () => "smart",
};
const IT_AGGIUNGI = { m: ["Aggiungi il tuo", "Aggiungi i tuoi"], f: ["Aggiungi la tua", "Aggiungi le tue"] } as const;

const maiuscola = (t: string) => t.charAt(0).toUpperCase() + t.slice(1);

/** Il nome del posto e la frase del bottone "aggiungi". Plurale quando le copie sono piu' di
 *  una o il nome e' solo plurale (soloPlurale in tabella). I nomi invariabili restano singolari.
 *  Per gli essenziali di base la categoria e' la famiglia ("intimo", "calzini", "notte", "igiene"). */
export function nomePosto(capo: Capo, copie: number, qualifica: Qualifica | null, lingua: Lingua):
  { nome: string; aggiungi: string } {
  const voce: NomePosto | undefined = (capo.sub && NOMI_SOTTOCATEGORIA[capo.sub]) || NOMI_CATEGORIA[capo.categoria] ||
    NOMI_FAMIGLIA[capo.categoria];
  if (!voce) return lingua === "en" ? { nome: "Item", aggiungi: "Add yours" } : { nome: "Capo", aggiungi: "Aggiungi il tuo" };
  const q = voce.qualificabile ? qualifica : null;
  const plurale = copie > 1 || voce.soloPlurale ? 1 : 0;
  if (lingua === "en") {
    const invernale = capo.categoria === "Outerwear" || capo.categoria === "Shoes";
    const nome = voce.en[plurale];
    return { nome: maiuscola(q ? `${EN_QUALIFICATORE[q](invernale)} ${nome}` : nome), aggiungi: "Add yours" };
  }
  let nome = voce.it[plurale];
  if (q === "freddo") {
    const invernale = capo.categoria === "Outerwear" || capo.categoria === "Shoes";
    nome += " " + (invernale ? IT_INVERNALE : IT_CALDO[voce.genere])[plurale];
  } else if (q === "acqua") {
    nome += " " + IT_ACQUA[plurale];
  } else if (q === "elegante") {
    nome += " " + IT_ELEGANTE[plurale];
  }
  return { nome: maiuscola(nome), aggiungi: IT_AGGIUNGI[voce.genere][plurale] };
}

// ── I posti della valigia per l'app ─────────────────────────────────────────

export interface PostoApp {
  /** Identita' stabile del bisogno, distinta anche fra due posti dello stesso tipo. */
  id: string;
  /** Sottocategoria del generatore, o categoria se generica, o famiglia: "intimo" | "calzini" | "notte" | "igiene". */
  tipo: string;
  categoria: "vestiti" | "toiletries";
  livello: Livello;
  nome: string;
  /** Sempre almeno 1. */
  copie: number;
  motivo: string | null;
  aggiungi: string;
  /** Additivi: impediscono che un kit chiuda un bisogno con un capo inadatto. */
  requisiti?: { minWarmth?: number; maxWarmth?: number; formality?: string[]; minWaterResistance?: number };
}

/** Cio' che l'utente deve sapere ma non e' un oggetto da mettere: bagaglio troppo pieno, lavanderia. */
export interface InfoApp { codice: string; titolo: string; perche: string }

/** Le famiglie degli essenziali di base, con il nome del capo finto che ne misura le copie. */
const FAMIGLIE: { tipo: string; radici: Set<string>; nome: string; categoria: PostoApp["categoria"] }[] = [
  { tipo: "intimo", radici: new Set(["mutand", "slip", "boxer", "perizoma", "intim", "underwear", "brief"]),
    nome: "Mutande", categoria: "vestiti" },
  { tipo: "calzini", radici: new Set(["calz", "sock"]), nome: "Calzini", categoria: "vestiti" },
  { tipo: "notte", radici: RADICI_NOTTE, nome: "Pigiama", categoria: "vestiti" },
  { tipo: "igiene", radici: new Set(["beauty", "trousse", "necessaire", "nécessaire", "washbag", "toilette",
    "spazzolin", "dentifric", "shampoo", "deodorant"]), nome: "Necessaire", categoria: "toiletries" },
];
const famigliaDi = (radice: unknown) => FAMIGLIE.find((f) => f.radici.has(String(radice)));

const TIPI_DI_POSTO = new Set(["assente", "posseduto_ma_inadatto", "quantita_insufficiente"]);

/** I mancanti senza candidato omettono alcuni vincoli che richiesti conserva. */
function conVincoli(g: Record<string, any>, richiesto: Record<string, any> | undefined): Record<string, any> {
  if (!richiesto) return g;
  const completo = { ...g };
  if (completo.formality == null && Array.isArray(richiesto.formality)) completo.formality = richiesto.formality;
  if (!calore(completo) && richiesto.minWarmth != null && richiesto.maxWarmth != null &&
    (richiesto.minWarmth > 1 || richiesto.maxWarmth < 5)) {
    completo.warmth_richiesto = [richiesto.minWarmth, richiesto.maxWarmth];
  }
  if (completo.impermeabilita_richiesta == null && completo.requiredWaterResistance == null && richiesto.minWaterResistance != null) {
    completo.impermeabilita_richiesta = richiesto.minWaterResistance;
  }
  return completo;
}

/** Recupera i vincoli prima che la deduplicazione dei gap perda bisogni con formalita' diverse. */
function mancantiPerPosti(valigia: Record<string, any>, richiesti: Record<string, any>[]): Record<string, any>[] {
  const completa = (g: Record<string, any>) => conVincoli(g, richiesti.find((r) => r.slot === g.slot));
  if (!Array.isArray(valigia.mancanti)) return (valigia.mancanti_canonici ?? []).map(completa);
  const gruppi = new Map<string, Record<string, any>[]>();
  for (const originale of valigia.mancanti) {
    const g = completa(originale);
    const chiave = JSON.stringify([Array.isArray(g.formality) ? [...g.formality].sort() : [], g.tappe ?? []]);
    const gruppo = gruppi.get(chiave) ?? [];
    gruppo.push(g);
    gruppi.set(chiave, gruppo);
  }
  return [...gruppi.values()].flatMap(canonicalizeGaps);
}

/** Gli argomenti con cui il generatore conta le quantita' (genera.ts valigiaDa, slots.ts
 *  strategySlots, tappe.ts strategySlotsMultitappa), ricostruiti dal viaggio e dal meteo. */
export interface ParametriQuantita {
  giorni: number;
  /** Per i capi: col cammino a piedi e lo zaino piccolo si lava a mano (slots.ts). */
  lavatrice: boolean;
  /** Per gli essenziali: la lavatrice del viaggio, senza il cammino. */
  lavatriceEssenziali: boolean;
  /** Le attivita' dello slot (per i giorni di mare). */
  attivita: string[];
  intensita: string | null;
  /** In un posto solo la massima del viaggio; a tappe quella della tappa base. */
  tempMax: number | null;
  /** I collant: a tappe la massima della tappa piu' fresca. */
  tempMaxEssenziali: number | null;
}

const numeroONull = (x: unknown) => (x == null || !Number.isFinite(Number(x)) ? null : Number(x));

export function parametriQuantita(v: Record<string, any> | null | undefined, meteo: Record<string, any> | null | undefined):
  ParametriQuantita {
  const sc = scenarioDaApp({ data_inizio: "", ...(v ?? {}),
    giorni: Math.trunc(Number(v?.giorni ?? meteo?.giorni)) || 1 } as ViaggioApp);
  const bagaglio = sc.bagaglio ?? "";
  const intensita = sc.intensita ?? null;
  const cammino = (attivita: string[], giorni: number) => Boolean(K.CAMMINO_LAVA_A_MANO) && camminoAPiedi(attivita, bagaglio, giorni);
  const legs: Record<string, any>[] = Array.isArray(sc.legs) ? sc.legs : [];
  if (legs.length) {
    // Le tappe come le vede strategySlotsMultitappa: giorni interi, massima della tappa dal meteo.
    const perMeteo: Record<string, any>[] = Array.isArray(meteo?._per_tappa) ? meteo!._per_tappa : [];
    const perTappa = legs.map((l) => ({
      destinazione: l.destinazione, giorni: Math.trunc(Number(l.giorni || 1)), attivita: l.attivita || [],
      meteo: { temp_max_media: numeroONull(perMeteo.find((t) => t.destinazione === l.destinazione)?.temp_max_media) },
    }));
    const giorni = perTappa.reduce((n, t) => n + t.giorni, 0);
    const base = ordinaTappe(perTappa)[0];
    let attivita: string[] = [...(sc.attivita || []), ...(base.attivita || [])];
    if (K.SLOT_TREKKING && perTappa.length > 1 && !eTrekking(sc.attivita) && eTrekking(base.attivita)) {
      attivita = attivita.filter((x) => !eTrekking([x]));
    }
    const lavatriceEssenziali = Boolean(sc.lavatrice);
    const massime = perTappa.map((t) => t.meteo.temp_max_media).filter((x): x is number => x != null);
    return {
      giorni, lavatriceEssenziali, attivita, intensita,
      lavatrice: lavatriceEssenziali || cammino(sc.attivita, giorni) || cammino(attivita, giorni),
      tempMax: base.meteo.temp_max_media, tempMaxEssenziali: massime.length ? Math.min(...massime) : null,
    };
  }
  const giorni = lavanderiaPresunta(sc.giorni, sc.lavatrice) ? K.GIORNI_LAVANDERIA : sc.giorni;
  const attivita = attivitaScenario(sc);
  const tempMax = numeroONull(meteo?.temp_max_media);
  return {
    giorni, lavatriceEssenziali: sc.lavatrice, attivita, intensita, tempMax, tempMaxEssenziali: tempMax,
    lavatrice: sc.lavatrice || cammino(attivita, giorni),
  };
}

/** Gli stessi fabbisogni delle tappe, controllati sulla valigia finale senza modificarla.
 *  Il controllo vale anche per una destinazione singola: i capi tecnici assenti vanno proposti. */
export function mancantiDelleTappe(valigia: Record<string, any>, armadio: CapoArmadio[],
  viaggio: Record<string, any> | null | undefined, meteo: Record<string, any> | null | undefined): Record<string, any>[] {
  if (!Array.isArray(valigia.ideali) || !Array.isArray(valigia.ripieghi) || !meteo) return [];
  const sc = scenarioDaApp({ data_inizio: "", ...(viaggio ?? {}) } as ViaggioApp);
  const perMeteo: Record<string, any>[] = meteo._per_tappa ?? [];
  const tappe = sc.legs?.length ? sc.legs.flatMap((l: any) => {
    const clima = perMeteo.find((t) => t.destinazione === l.destinazione);
    return clima ? [{ ...l, attivita: [...(sc.attivita ?? []), ...(l.attivita ?? [])], meteo: clima }] : [];
  }) : [{ destinazione: sc.destinazione ?? "", giorni: sc.giorni,
    attivita: sc.attivita ?? [], meteo }];
  const mancanti: Record<string, any>[] = [];
  const capienza = capienzaBagaglio(sc.bagaglio ?? "");
  const giorni = tappe.reduce((n: number, t: any) => n + Number(t.giorni || 1), 0);
  for (const t of tappe) {
    servePerTappa(t, structuredClone([...valigia.ideali, ...valigia.ripieghi]), armadio,
      new Set(armadio.map((g) => g.id)), capienza <= 30 ? 0.25 : capienza <= 55 ? 0.12 : 0,
      giorni <= 2 || capienza <= 8, null, false, mancanti);
  }
  return mancanti;
}

/** Un bisogno della tappa usa i suoi giorni e il suo clima, non l'intera durata. */
function quantitaPerTappe(g: Record<string, any>, q: ParametriQuantita,
  viaggio: Record<string, any> | null | undefined, meteo: Record<string, any> | null | undefined): ParametriQuantita {
  const nomi = new Set(g.tappe ?? []);
  const tappe = (viaggio?.tappe ?? viaggio?.legs ?? []).filter((t: any) => nomi.has(t.nome ?? t.destinazione));
  if (!tappe.length) return q;
  const massime = (meteo?._per_tappa ?? []).filter((t: any) => nomi.has(t.destinazione))
    .map((t: any) => numeroONull(t.temp_max_media)).filter((n: number | null): n is number => n != null);
  return { ...q, giorni: tappe.reduce((n: number, t: any) => n + Math.max(1, Number(t.giorni) || 1), 0),
    attivita: attivitaPer(g, viaggio), tempMax: massime.length ? Math.max(...massime) : q.tempMax };
}

/** Le copie di un mancante: i capi diversi che mancano per una quantita' insufficiente, uno per
 *  giacche, scarpe e accessori, altrimenti la quantita' che il generatore darebbe allo slot
 *  (slots.ts, quantityFor) con il calore minimo dello slot al posto di quello del capo. */
function copieDelMancante(g: Record<string, any>, sub: string | null, richiesto: Record<string, any> | undefined,
  q: ParametriQuantita): number {
  let copie: number;
  if (g.tipo === "quantita_insufficiente") {
    const necessari = g.capi_diversi_necessari == null ? NaN : Number(g.capi_diversi_necessari);
    // Senza capi_diversi_necessari (copie possedute, dopo.ts) gli usi sono pezzi: mancano i pezzi.
    copie = Number.isFinite(necessari)
      ? necessari - Math.ceil(Number(g.usi_coperti || 0) / K.TETTO_COPIE_STESSO_CAPO)
      : Number(g.usi_richiesti) - Number(g.usi_coperti);
  } else if (K.REUSABLE.has(g.category)) {
    copie = 1;
  } else {
    const frequenza = String(richiesto?.frequency ?? "daily");
    const calore = numeroONull(richiesto?.minWarmth) ?? numeroONull(Array.isArray(g.warmth_richiesto) ? g.warmth_richiesto[0] : null);
    copie = quantityFor(sub ?? "", "", q.giorni, q.lavatrice, frequenza, normIntensita(richiesto?.intensita) || q.intensita,
      q.tempMax, giorniDiMare(q.giorni, q.attivita), calore);
  }
  return Number.isFinite(copie) ? Math.max(1, copie) : 1;
}

interface Grezzo {
  tipo: string;
  categoria: PostoApp["categoria"];
  livello: Livello;
  copie: number;
  motivo: string | null;
  /** Il capo e la qualifica da cui nasce il nome. */
  capo: Capo;
  qualifica: Qualifica | null;
  /** Da dove nasce: un mancante del generatore, un capo con meno copie, un essenziale di base. */
  origine: "gap" | "pezzi" | "famiglia";
  /** Solo per i mancanti: il gap chiede un capo elegante (soloElegante). */
  elegante?: boolean;
  /** Solo per i mancanti: le tappe del gap (viaggi a piu' tappe), se il generatore le indica. */
  tappe?: string[];
  /** Il posto unico del meteo (unisciIlMeteo): non si somma ad altri posti dello stesso tipo. */
  delMeteo?: boolean;
  /** Vincoli del bisogno, usati per accorpare solo proposte compatibili. */
  bisogno?: Record<string, any>;
}

function compatibili(a: Grezzo, b: Grezzo): boolean {
  if (!a.bisogno || !b.bisogno) return true;
  const wa = calore(a.bisogno), wb = calore(b.bisogno);
  if (wa && wb && Math.max(wa[0], wb[0]) > Math.min(wa[1], wb[1])) return false;
  const fa: string[] = a.bisogno.formality ?? [], fb: string[] = b.bisogno.formality ?? [];
  return !fa.length || !fb.length || fa.some((f) => fb.includes(f));
}

function unisciBisogni(a: Grezzo, b: Grezzo, lingua: Lingua): void {
  if (!a.bisogno || !b.bisogno) return;
  const wa = calore(a.bisogno), wb = calore(b.bisogno);
  const bisogno = { ...a.bisogno };
  if (wa && wb) bisogno.warmth_richiesto = [Math.max(wa[0], wb[0]), Math.min(wa[1], wb[1])];
  else if (wb) bisogno.warmth_richiesto = wb;
  const fa: string[] = bisogno.formality ?? [], fb: string[] = b.bisogno.formality ?? [];
  bisogno.formality = fa.length && fb.length ? fa.filter((f) => fb.includes(f)) : fa.length ? fa : fb;
  bisogno.impermeabilita_richiesta = Math.max(
    Number(a.bisogno.impermeabilita_richiesta ?? a.bisogno.requiredWaterResistance ?? 0),
    Number(b.bisogno.impermeabilita_richiesta ?? b.bisogno.requiredWaterResistance ?? 0));
  a.bisogno = bisogno;
  const freddo = a.qualifica === "freddo" || b.qualifica === "freddo";
  a.qualifica = qualificaDelGap(bisogno, a.capo, freddo);
  a.motivo = copyMancante(bisogno, freddo, [], lingua).perche;
  a.elegante = soloElegante(bisogno);
}

/** Un posto solo per le giacche e per le scarpe del meteo (Outerwear, Shoes): "Sneakers invernali",
 *  "Scarpe invernali" e "Stivali invernali" sono lo stesso bisogno, avere scarpe per il freddo.
 *  Sono del meteo i mancanti importanti che non sono d'attivita' ne' eleganti; per ogni categoria
 *  diventano uno solo (tipo = la categoria, nome qualificato dal freddo o, senno', dall'acqua),
 *  e i mancanti utili della stessa categoria spariscono. I pezzi in meno non si toccano. */
function unisciIlMeteo(grezzi: Grezzo[], lingua: Lingua): Grezzo[] {
  const delMeteo = (p: Grezzo) => p.origine === "gap" && !p.elegante && !(p.capo.sub && DA_ATTIVITA.has(p.capo.sub)) &&
    (p.capo.categoria === "Outerwear" || p.capo.categoria === "Shoes");
  // Il posto unito di ogni categoria nasce dal primo importante; il freddo di uno qualunque lo qualifica.
  const gruppi: Grezzo[] = [];
  const assegnati = new Map<Grezzo, Grezzo>();
  for (const p of grezzi) {
    if (!delMeteo(p) || p.livello !== "importante") continue;
    const gia = gruppi.find((g) => g.capo.categoria === p.capo.categoria && compatibili(g, p));
    if (!gia) {
      const nuovo = { ...p, tipo: p.capo.categoria, copie: 1, delMeteo: true, capo: { sub: null, categoria: p.capo.categoria } };
      gruppi.push(nuovo);
      assegnati.set(p, nuovo);
    } else { unisciBisogni(gia, p, lingua); assegnati.set(p, gia); }
  }
  const messi = new Set<Grezzo>();
  const risultato: Grezzo[] = [];
  for (const p of grezzi) {
    const unito = delMeteo(p) ? assegnati.get(p) ?? gruppi.find((g) => g.capo.categoria === p.capo.categoria && compatibili(g, p)) : undefined;
    if (!unito) { risultato.push(p); continue; } // non e' del meteo, o non c'e' un posto del meteo: resta com'e'
    if (p.livello === "importante" && !messi.has(unito)) {
      messi.add(unito);
      risultato.push(unito); // al posto del primo; gli altri (importanti e utili) spariscono
    }
  }
  return risultato;
}

/** I posti della valigia: i mancanti, i pezzi che l'armadio non ha in numero, gli essenziali
 *  di base assenti; uniti per tipo, prima gli importanti. Volume e lavanderia sono informazioni.
 *  Lavora sul risultato del generatore e non tocca uscitaApp. */
export function postiApp(valigia: Record<string, any>, motivi: { capi: Record<string, any>[]; essenziali: Record<string, any>[] },
  salvate: Map<string, number | null>,
  contesto: { meteo?: Record<string, any> | null; viaggio?: Record<string, any> | null; armadio: CapoArmadio[]; lingua?: Lingua },
): { posti: PostoApp[]; informazioni: InfoApp[] } {
  const lingua: Lingua = contesto.lingua ?? "it";
  const { meteo, viaggio, armadio } = contesto;
  const q = parametriQuantita(viaggio, meteo);
  const grezzi: Grezzo[] = [];
  const informazioni: InfoApp[] = [];

  // 1. I mancanti del generatore (gonna, vestito e cravatta solo se l'armadio ne ha).
  const sottocategorie = new Set(armadio.flatMap((g) => [g.sub_fine, g.sub_category]));
  const richiesti: Record<string, any>[] = Array.isArray(valigia.richiesti) ? valigia.richiesti : [];
  for (const originale of [...mancantiPerPosti(valigia, richiesti), ...mancantiDelleTappe(valigia, armadio, viaggio, meteo)]) {
    const richiesto = originale.richiesto ?? richiesti.find((r) => r.slot === originale.slot);
    const g = perQuestoArmadio(conVincoli(originale, richiesto), sottocategorie);
    if (!g) continue;
    const viaggioFreddo = freddoPer(g, meteo);
    const attivita = attivitaPer(g, viaggio);
    if (g.tipo === "volume_eccedente") {
      informazioni.push({ codice: String(g.tipo), ...copyMancante(g, viaggioFreddo, attivita, lingua) });
      continue;
    }
    if (!TIPI_DI_POSTO.has(g.tipo)) continue;
    // Il capo del posto lo sceglie il generatore: il suo abbinamento (slots.ts) rifatto su un armadio tipico
    // (armadio_tipico.ts), col calore, la formalita', le attivita' e l'impermeabilita' del bisogno. Lo porta
    // richiesti (capoTipico). Se nessun capo tipico va, o e' un capo che si nomina solo se l'armadio lo ha
    // e l'armadio no, resta quello di capoDelGap (lo stesso che nomina l'avviso: col freddo, il maglione).
    const tipico = richiesto?.capoTipico as { sub?: string; categoria?: string } | undefined;
    const usaTipico = Boolean(tipico?.sub && tipico.categoria && NOMI_SOTTOCATEGORIA[tipico.sub] &&
      (!SOLO_SE_NELL_ARMADIO.has(tipico.sub) || sottocategorie.has(tipico.sub)));
    const { sub, categoria } = usaTipico
      ? { sub: tipico!.sub!, categoria: tipico!.categoria! }
      : capoDelGap(g, viaggioFreddo || (calore(g)?.[0] ?? 0) >= 3);
    const tipo = sub ?? categoria;
    if (!tipo) continue;
    const capo = { sub, categoria };
    grezzi.push({
      tipo, categoria: "vestiti", livello: livelloPosto(g, capo, viaggioFreddo),
      copie: Math.max(Number(g.copie_minime ?? 1), copieDelMancante(g, sub, richiesto, quantitaPerTappe(g, q, viaggio, meteo))),
      motivo: copyMancante(g, viaggioFreddo, attivita, lingua).perche,
      capo, qualifica: qualificaDelGap(g, capo, viaggioFreddo), origine: "gap", elegante: soloElegante(g),
      tappe: Array.isArray(g.tappe) ? g.tappe.map(String) : undefined,
      bisogno: g,
    });
  }

  // 2. Pezzi in meno: il capo serve in piu' copie di quelle salvate (pochi_pezzi di uscitaApp).
  const radici = new Map(motivi.essenziali.map((e) => [String(e.item_id), e.radice]));
  const perId = new Map(armadio.map((g) => [g.id, g]));
  const freddo = freddoPer({}, meteo);
  for (const [id, c] of capiUniti(motivi)) {
    const tetto = tettoSalvate(salvate, id);
    if (c.quantita <= tetto) continue;
    const manca = c.quantita - tetto;
    const motivo = frasePochi(c.quantita, tetto, lingua);
    const famiglia = famigliaDi(radici.get(id));
    if (famiglia) {
      grezzi.push({ tipo: famiglia.tipo, categoria: famiglia.categoria, livello: "utile", copie: manca, motivo,
        capo: { sub: null, categoria: famiglia.tipo }, qualifica: null, origine: "pezzi" });
      continue;
    }
    const g = perId.get(id);
    if (!g) continue;
    const sub = NOMI_SOTTOCATEGORIA[g.sub_category] ? g.sub_category : null;
    if (!sub && !NOMI_CATEGORIA[g.category]) continue;
    const capo = { sub, categoria: g.category };
    // Un pezzo solo in meno non e' mai importante.
    grezzi.push({ tipo: sub ?? g.category, categoria: "vestiti", livello: manca > 1 ? livelloPosto({}, capo, freddo) : "utile",
      copie: manca, motivo, capo, qualifica: null, origine: "pezzi" });
  }

  // 3. Essenziali di base assenti: le copie che avrebbe un utente con quell'oggetto.
  const coperte = new Set(((valigia.essenziali ?? []) as Record<string, any>[]).map((e) => famigliaDi(e.radice)?.tipo));
  for (const f of FAMIGLIE) {
    if (coperte.has(f.tipo)) continue;
    const [e] = essenzialiPerViaggio(caricaArmadio([{ id: `posto:${f.tipo}`, name: f.nome }]), q.giorni,
      q.lavatriceEssenziali, q.tempMaxEssenziali);
    grezzi.push({ tipo: f.tipo, categoria: f.categoria, livello: "utile", copie: Math.max(1, e?.quantita ?? 1),
      motivo: null, capo: { sub: null, categoria: f.tipo }, qualifica: null, origine: "famiglia" });
  }

  // 4. Giacche e scarpe del meteo: un posto per ogni gruppo di bisogni compatibili.
  // 5. Uniti per tipo e vincoli compatibili: importante se lo e' almeno uno. Le copie: i mancanti
  // del generatore di Upper Body, Lower Body e Shoes nella stessa tappa (slot giornaliero e occasionale coprono
  // gli stessi giorni) si uniscono col massimo; tappe diverse coprono giorni diversi e si sommano,
  // come ogni mancante di un viaggio a piu' tappe senza tappa indicata, i pezzi in meno, le famiglie
  // e le famiglie. Giacche e accessori riusabili compatibili prendono il massimo anche tra tappe.
  const aTappe = [viaggio?.tappe, viaggio?.legs].some((t) => Array.isArray(t) && t.length > 1);
  const uniti = new Map<string, Grezzo>();
  const copieGap = new Map<string, Map<string, number>>(); // chiave del posto -> tappa -> massimo
  const copieAltre = new Map<string, number>();
  let senzaTappa = 0;
  for (const p of unisciIlMeteo(grezzi, lingua)) {
    // Il posto unico del meteo ha una chiave sua: i pezzi in meno dello stesso tipo (sottocategoria sconosciuta) restano a parte.
    const base = p.delMeteo ? `meteo:${p.tipo}` : p.tipo;
    let chiave = base;
    let indice = 1;
    while (uniti.has(chiave) && !compatibili(uniti.get(chiave)!, p)) chiave = `${base}:${indice++}`;
    const riusabile = K.REUSABLE.has(p.capo.categoria) && p.capo.categoria !== "Shoes";
    const aMassimo = p.origine === "gap" && !p.delMeteo &&
      (riusabile || ["Upper Body", "Lower Body", "Shoes"].includes(p.capo.categoria));
    if (aMassimo) {
      // Senza tappa nota in un viaggio a piu' tappe la chiave e' unica: si somma.
      const tappa = riusabile || !aTappe ? "" : p.tappe?.length ? [...p.tappe].sort().join("|") : aTappe ? `?${senzaTappa++}` : "";
      const perTappa = copieGap.get(chiave) ?? new Map<string, number>();
      perTappa.set(tappa, Math.max(perTappa.get(tappa) ?? 0, p.copie));
      copieGap.set(chiave, perTappa);
    } else copieAltre.set(chiave, (copieAltre.get(chiave) ?? 0) + p.copie);
    const gia = uniti.get(chiave);
    if (!gia) { uniti.set(chiave, { ...p }); continue; }
    if (p.livello === "importante" && gia.livello !== "importante") {
      Object.assign(gia, { livello: p.livello, motivo: p.motivo, capo: p.capo, qualifica: p.qualifica });
    }
    unisciBisogni(gia, p, lingua);
  }
  for (const [chiave, p] of uniti) {
    const dei = [...(copieGap.get(chiave)?.values() ?? [])].reduce((a, b) => a + b, 0);
    p.copie = dei + (copieAltre.get(chiave) ?? 0);
  }

  // Col caldo in tutte le tappe (la massima piu' bassa sopra la soglia del generatore, un capo sopra
  // leggero al giorno) i pantaloni lunghi sono da sera, come le camicie: senza sapere se sono leggeri
  // non superano le copie delle camicie (una se non ci sono). Con una tappa fresca restano da giorno.
  if (caldoUnCapoAlGiorno(q.tempMaxEssenziali)) {
    const camicie = uniti.get("Shirt")?.copie ?? 1;
    for (const tipo of ["Trousers", "Jeans"]) {
      const lunghi = uniti.get(tipo);
      if (lunghi) lunghi.copie = Math.min(lunghi.copie, camicie);
    }
  }

  // 6. Prima gli importanti; dentro, l'ordine di nascita (sort e' stabile).
  const posti = [...uniti.values()]
    .sort((a, b) => Number(b.livello === "importante") - Number(a.livello === "importante"))
    .map((p): PostoApp => {
      const { nome, aggiungi } = nomePosto(p.capo, p.copie, p.qualifica, lingua);
      const fascia = p.bisogno ? calore(p.bisogno) : null;
      const requisiti = p.bisogno ? {
        ...(fascia ? { minWarmth: fascia[0], maxWarmth: fascia[1] } : {}),
        formality: [...(p.bisogno.formality ?? [])].sort(),
        minWaterResistance: Number(p.bisogno.impermeabilita_richiesta ?? p.bisogno.requiredWaterResistance ?? 0),
      } : undefined;
      // Identita' del bisogno: non dipende dall'ordine, dalle copie o dalla lingua del nome.
      const id = `need:v1:${JSON.stringify([p.tipo, p.delMeteo ? "meteo" : p.origine,
        fascia, requisiti?.formality ?? [], requisiti?.minWaterResistance ?? 0])}`;
      return { id, tipo: p.tipo, categoria: p.categoria, livello: p.livello, nome, copie: p.copie,
        motivo: p.motivo, aggiungi, ...(requisiti ? { requisiti } : {}) };
    });

  const lavanderia = lavanderiaDelViaggio(viaggio, lingua);
  if (lavanderia) informazioni.push({ codice: CODICE_LAVANDERIA, ...lavanderia });
  return { posti, informazioni };
}
