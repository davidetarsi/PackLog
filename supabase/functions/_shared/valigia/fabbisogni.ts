// Analisi di dominio dei bisogni residui, condivisa dal generatore e dall'adapter dell'app.
import * as K from "./costanti.ts";
import { caricaArmadio, type Capo as CapoArmadio } from "./capo.ts";
import { canonicalizeGaps, capienzaBagaglio } from "./dopo.ts";
import { scenarioDaApp, type ViaggioApp, normalizzaQuantitaViaggio, preparaContestoTappe } from "./contesto_viaggio.ts";
import { attivitaScenario } from "./prompt.ts";
import { giorniDiMare, normIntensita, quantityFor, essenzialiPerViaggio, RADICI_NOTTE } from "./quantita.ts";
import { servePerTappa } from "./tappe.ts";
import { perIlGeneratore } from "./tassonomia.ts";
import { attivitaPer, calore, capiUniti, tettoSalvate } from "./uscita.ts";

type Record_ = Record<string, any>;

/** Le famiglie degli essenziali di base, con il nome del capo finto che ne misura le copie. */
const FAMIGLIE: { tipo: string; radici: Set<string>; nome: string; categoria: "vestiti" | "toiletries" }[] = [
  { tipo: "intimo", radici: new Set(["mutand", "slip", "boxer", "perizoma", "intim", "underwear", "brief"]),
    nome: "Mutande", categoria: "vestiti" },
  { tipo: "calzini", radici: new Set(["calz", "sock"]), nome: "Calzini", categoria: "vestiti" },
  { tipo: "notte", radici: RADICI_NOTTE, nome: "Pigiama", categoria: "vestiti" },
  { tipo: "igiene", radici: new Set(["beauty", "trousse", "necessaire", "nécessaire", "washbag", "toilette",
    "spazzolin", "dentifric", "shampoo", "deodorant"]), nome: "Necessaire", categoria: "toiletries" },
];
const famigliaDi = (radice: unknown) => FAMIGLIE.find((f) => f.radici.has(String(radice)));



/** I mancanti senza candidato omettono alcuni vincoli che richiesti conserva. */
function conVincoli(g: Record<string, any>, richiesto: Record<string, any> | undefined): Record<string, any> {
  if (!richiesto) return g;
  const completo = { ...g };
  if (completo.requiredActivityTags == null && richiesto.vincoliPosto?.activityTags) completo.requiredActivityTags = richiesto.vincoliPosto.activityTags;
  if (completo.coverage == null && richiesto.vincoliPosto?.coverage) completo.coverage = richiesto.vincoliPosto.coverage;
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
function mancantiConVincoli(valigia: Record<string, any>, richiesti: Record<string, any>[]): Record<string, any>[] {
  const completa = (g: Record<string, any>) => conVincoli(g, richiesti.find((r) => r.slot === g.slot));
  if (!Array.isArray(valigia.mancanti)) return (valigia.mancanti_canonici ?? []).map(completa);
  const gruppi = new Map<string, Record<string, any>[]>();
  for (const originale of valigia.mancanti) {
    const g = completa(originale);
    const chiave = JSON.stringify([Array.isArray(g.formality) ? [...g.formality].sort() : [], g.tappe ?? [],
      g.requiredActivityTags ?? [], g.coverage ?? []]);
    const gruppo = gruppi.get(chiave) ?? [];
    gruppo.push(g);
    gruppi.set(chiave, gruppo);
  }
  return [...gruppi.values()].flatMap(canonicalizeGaps);
}

/** Gli argomenti con cui il generatore conta le quantita' (genera.ts valigiaDa, slots.ts
 *  strategySlots, tappe.ts strategySlotsMultitappa), derivati dal contesto condiviso del viaggio e dal meteo. */
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
  const legs: Record<string, any>[] = Array.isArray(sc.legs) ? sc.legs : [];
  if (legs.length) {
    // Le tappe come le vede strategySlotsMultitappa: giorni interi, massima della tappa dal meteo.
    const perMeteo: Record<string, any>[] = Array.isArray(meteo?._per_tappa) ? meteo!._per_tappa : [];
    const perTappa = legs.map((l) => ({
      destinazione: l.destinazione, giorni: Math.trunc(Number(l.giorni || 1)), attivita: l.attivita || [],
      meteo: { temp_max_media: numeroONull(perMeteo.find((t) => t.destinazione === l.destinazione)?.temp_max_media) },
    }));
    const { giorni, base, attivitaBase: attivita, lavatriceEssenziali, lavatriceBase } =
      preparaContestoTappe(sc, perTappa, bagaglio);
    const massime = perTappa.map((t) => t.meteo.temp_max_media).filter((x): x is number => x != null);
    return {
      giorni, lavatriceEssenziali, attivita, intensita,
      lavatrice: lavatriceBase,
      tempMax: base.meteo.temp_max_media, tempMaxEssenziali: massime.length ? Math.min(...massime) : null,
    };
  }
  const attivita = attivitaScenario(sc);
  const { giorni, lavatrice, lavatriceEssenziali } = normalizzaQuantitaViaggio({ ...sc,
    giorni: sc.giorni, lavatrice: sc.lavatrice, attivita, bagaglio });
  const tempMax = numeroONull(meteo?.temp_max_media);
  return {
    giorni, lavatriceEssenziali, attivita, intensita, tempMax, tempMaxEssenziali: tempMax, lavatrice,
  };
}

/** L'equivalenza nasce da una funzione assegnata dal matcher, mai dalla sola categoria. */
function copertoDaAssegnazione(capo: Record_, bisogno: Record_, richiesti: Record_[]): boolean {
  if (capo.category !== bisogno.category) return false;
  const subs = new Set(bisogno.subCategories ?? []), forme = new Set(bisogno.formality ?? []);
  const frequenza: Record<string, number> = { once: 0, occasional: 1, daily: 2 };
  return (capo.assegnazioni ?? [capo]).some((a: Record_) =>
    ["ideale", "ripiego", "compromesso"].includes(a.match) && richiesti.some((r) =>
      r.slot === a.slot && r.category === bisogno.category && r.subCategories?.length &&
      r.subCategories.every((s: string) => subs.has(s)) &&
      (!forme.size || (r.formality?.length && r.formality.every((f: string) => forme.has(f)))) &&
      (K.REUSABLE.has(bisogno.category) ||
        (frequenza[r.frequency] ?? 2) >= (frequenza[bisogno.frequency] ?? 2))));
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
    const capi = structuredClone([...valigia.ideali, ...valigia.ripieghi])
      .map((r) => ({ ...r, tappe: r.tappe ?? [t.destinazione] }));
    servePerTappa(t, capi, armadio,
      new Set(armadio.map((g) => g.id)), capienza <= 30 ? 0.25 : capienza <= 55 ? 0.12 : 0,
      giorni <= 2 || capienza <= 8, null, false, mancanti,
      (capo, bisogno) => copertoDaAssegnazione(capo, bisogno, valigia.richiesti ?? []));
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

export interface FabbisognoResiduo {
  vincoli: Record_;
  richiesto: Record_ | undefined;
  quantita: ParametriQuantita;
  supplementare: boolean;
}

export interface AnalisiFabbisogni {
  quantita: ParametriQuantita;
  mancanti: FabbisognoResiduo[];
  aTappe: boolean;
  copieMancanti: { id: string; richieste: number; presenti: number; copie: number; tappe: string[];
    famiglia?: { tipo: string; categoria: "vestiti" | "toiletries" } }[];
  essenzialiMancanti: { tipo: string; categoria: "vestiti" | "toiletries"; copie: number }[];
}

interface CoperturaArmadio {
  motivi: { capi: Record_[]; essenziali: Record_[] };
  salvate: Map<string, number | null>;
}

/** Il generatore espone cio' che resta scoperto, con tutti i vincoli e il contesto di quantita'. */
export function analizzaFabbisogni(valigia: Record_, armadio: CapoArmadio[],
  viaggio: Record_ | null | undefined, meteo: Record_ | null | undefined, copertura?: CoperturaArmadio): AnalisiFabbisogni {
  const quantita = parametriQuantita(viaggio, meteo);
  const richiesti: Record_[] = Array.isArray(valigia.richiesti) ? valigia.richiesti : [];
  const mancanti = [...mancantiConVincoli(valigia, richiesti), ...mancantiDelleTappe(valigia, armadio, viaggio, meteo)]
    .map((originale): FabbisognoResiduo => {
      const richiesto = originale.richiesto ?? richiesti.find((r) => r.slot === originale.slot);
      const vincoli = conVincoli(originale, richiesto);
      return { vincoli, richiesto, quantita: quantitaPerTappe(vincoli, quantita, viaggio, meteo),
        supplementare: Boolean(originale.richiesto) };
    });
  const copieMancanti: AnalisiFabbisogni["copieMancanti"] = [];
  if (copertura) {
    const radici = new Map(copertura.motivi.essenziali.map((e) => [String(e.item_id), e.radice]));
    for (const [id, c] of capiUniti(copertura.motivi)) {
      const presenti = tettoSalvate(copertura.salvate, id);
      if (c.quantita <= presenti) continue;
      const famiglia = famigliaDi(radici.get(id));
      copieMancanti.push({ id, richieste: c.quantita, presenti, copie: c.quantita - presenti,
        tappe: [...(valigia.ideali ?? []), ...(valigia.ripieghi ?? [])]
          .filter((r) => String(r.item_id) === id).flatMap((r) => r.tappe ?? []),
        ...(famiglia ? { famiglia: { tipo: famiglia.tipo, categoria: famiglia.categoria } } : {}) });
    }
  }
  const coperte = new Set(((valigia.essenziali ?? []) as Record_[]).map((e) => famigliaDi(e.radice)?.tipo));
  const essenzialiMancanti = FAMIGLIE.filter((f) => !coperte.has(f.tipo)).map((f) => {
    const [e] = essenzialiPerViaggio(caricaArmadio([{ id: `posto:${f.tipo}`, name: f.nome }]), quantita.giorni,
      quantita.lavatriceEssenziali, quantita.tempMaxEssenziali);
    return { tipo: f.tipo, categoria: f.categoria, copie: Math.max(1, e?.quantita ?? 1) };
  });
  return { quantita, mancanti, copieMancanti, essenzialiMancanti,
    aTappe: [viaggio?.tappe, viaggio?.legs].some((t) => Array.isArray(t) && t.length > 1) };
}

export function copieResidue(f: FabbisognoResiduo, sub: string | null): number {
  return Math.max(Number(f.vincoli.copie_minime ?? 1),
    copieDelMancante(f.vincoli, sub, f.richiesto, f.quantita) - Number(f.vincoli.copie_coperte ?? 0));
}

export function vincoliCompatibili(a: Record_ | undefined, b: Record_ | undefined): boolean {
  if (!a || !b) return true;
  const wa = calore(a), wb = calore(b);
  if (wa && wb && Math.max(wa[0], wb[0]) > Math.min(wa[1], wb[1])) return false;
  const fa: string[] = a.formality ?? [], fb: string[] = b.formality ?? [];
  if (fa.length && fb.length && !fa.some((f) => fb.includes(f))) return false;
  for (const campo of ["requiredActivityTags", "coverage"]) {
    const ca: string[] = a[campo] ?? [], cb: string[] = b[campo] ?? [];
    if (ca.length && cb.length && !ca.some((v) => cb.includes(v))) return false;
  }
  return true;
}

export function intersecaVincoli(a: Record_, b: Record_): Record_ {
  const wa = calore(a), wb = calore(b);
  const bisogno = { ...a };
  if (wa && wb) bisogno.warmth_richiesto = [Math.max(wa[0], wb[0]), Math.min(wa[1], wb[1])];
  else if (wb) bisogno.warmth_richiesto = wb;
  const fa: string[] = bisogno.formality ?? [], fb: string[] = b.formality ?? [];
  bisogno.formality = fa.length && fb.length ? fa.filter((f) => fb.includes(f)) : fa.length ? fa : fb;
  for (const campo of ["requiredActivityTags", "coverage"]) {
    const ca: string[] = bisogno[campo] ?? [], cb: string[] = b[campo] ?? [];
    bisogno[campo] = ca.length && cb.length ? ca.filter((v) => cb.includes(v)) : ca.length ? ca : cb;
  }
  bisogno.impermeabilita_richiesta = Math.max(
    Number(a.impermeabilita_richiesta ?? a.requiredWaterResistance ?? 0),
    Number(b.impermeabilita_richiesta ?? b.requiredWaterResistance ?? 0));
  return bisogno;
}

interface CoperturaProposta {
  tipo: string;
  copie: number;
  capo: { sub: string | null; categoria: string };
  bisogno?: Record_;
  tappe?: string[];
}

/** Conta la copertura pianificata prima di aggiungere un altro capo virtuale. */
export function copriConProposte(proposta: CoperturaProposta, piano: CoperturaProposta[], aTappe: boolean):
  { copie: number; riusate: number[] } {
  const g = proposta.bisogno ?? {};
  const perTipo = new Map<string, number>(), riusate: number[] = [];
  for (const [indice, p] of piano.entries()) {
    const stessaTappa = p.tappe?.length ? p.tappe.length === 1 && p.tappe[0] === g.tappe?.[0] : !aTappe;
    if (!stessaTappa || p.capo.categoria !== proposta.capo.categoria || !p.capo.sub ||
      !g.subCategories?.includes(perIlGeneratore(p.capo.sub)) || !vincoliCompatibili(p.bisogno, g)) continue;
    perTipo.set(p.tipo, Math.max(perTipo.get(p.tipo) ?? 0, p.copie));
    riusate.push(indice);
  }
  const coperte = [...perTipo.values()].reduce((n, copie) => n + copie, 0);
  return { copie: coperte >= proposta.copie ? 0 : proposta.copie - coperte + (perTipo.get(proposta.tipo) ?? 0), riusate };
}
