// La scelta dei capi slot per slot: porting di strategy_slots e delle sue
// funzioni di appoggio (packlog_checklist_bench_48.py). La chiamata al modello
// e' fuori: `testoModello` e' la risposta grezza di GPT, cosi' il cuore e' puro
// e si verifica sulle valigie registrate nel bench.
import * as K from "./costanti.ts";
import * as rc from "./regole_capi.ts";
import * as tx from "./tassonomia.ts";
import type { Capo } from "./capo.ts";
import { eAttivitaAcqua, essenzialiPerViaggio, giorniDiMare, normIntensita, quantityFor } from "./quantita.ts";
import {
  capoLeggero, capoRiservato, capospallaInTracolla, fixes, injectFabbisogno, injectMandatory,
  injectParteInferioreFormale, injectStratoFormale, insieme, interseca, normList, penalitaCulto, rejects,
  type Record_, segnaCapiDaNeve, type Slot, slotCapiNuovi, sottoinsieme, viaggioDiLavoro, warmthCeiling,
  warmthFloor, eTrekking,
} from "./inject.ts";
import {
  applicaBudgetRotazione, applicaTettoVolume, berrettoColFreddo, caloreEfficace, canonicalizeGaps,
  capienzaBagaglio, capienzaPotabile, consolidaBloccoViaggio, estivoFuoriStagione, minimoCapiLeggeri,
  penalitaVetoCapo, penalitaVoto, score, segnaInPartenza, segnalaScarpeCammino, segnalaVolume, togliDoppioni,
} from "./dopo.ts";
import { floorDiv, massimo, minimo, ordina, pf, ps, vero } from "./py.ts";

/** dict.get(k, d) di Python: il default solo se la chiave manca (non se vale null). */
export const get = (s: Record_, k: string, d: unknown = null) => (k in s ? s[k] : d);
const q = (x: Record_) => x.quantita ?? 1;
const ceilDiv = (a: number, b: number) => -floorDiv(-a, b);

/** round(x, n) di Python: arrotonda il valore esatto in binario e, se cade
 *  esattamente a meta' (1.625 e' esatto in binario), al pari come Python. */
export function round2(x: number, n = 2): number {
  const esatto = Math.abs(x).toFixed(30);          // espansione decimale esatta
  const [intera, dec = ""] = esatto.split(".");
  const coda = dec.slice(n);
  if (/^50*$/.test(coda)) {
    const tronco = Number(`${intera}.${dec.slice(0, n)}`);
    const ultima = Number((dec.slice(0, n) || intera).slice(-1));
    const passo = 10 ** -n;
    const r = ultima % 2 === 0 ? tronco : tronco + passo;
    return Math.sign(x) * Number(r.toFixed(n));
  }
  return Number(x.toFixed(n));
}

const SUBCATEGORIES = new Set<string>([...K.SUBCATEGORIES]);
const FORMALITIES = new Set<string>([...K.FORMALITIES]);
const ACTIVITY_TAGS = new Set<string>([...K.ACTIVITY_TAGS]);

export function parseJsonBlock(text: string): any {
  return JSON.parse(text.replaceAll("```json", "").replaceAll("```", "").trim());
}

// ── Tetti di copie ──────────────────────────────────────────────────────────
export function tettoCopie(formalita: string | null | undefined, sotto: string | null | undefined = null): number {
  if (formalita === "Business" || formalita === "Formal" || K.SOTTOCAT_GAMBE_LUNGHE.has(sotto)) return K.TETTO_COPIE_FORMALE;
  return K.TETTO_COPIE_STESSO_CAPO;
}

export function tettoCopieMorbido(formalita: string | null | undefined, sotto: string | null | undefined = null): number {
  if (formalita === "Business" || formalita === "Formal" || sotto === "Swimwear") return 1;
  if (K.SOTTOCAT_MEDIO.includes(sotto)) return 1;
  return Math.min(K.TETTO_COPIE_MORBIDO, tettoCopie(formalita, sotto));
}

export function tettoMorbidoPer(serve: number, formalita: string | null | undefined, sotto: string | null | undefined,
  capienza: number | null = null): number {
  let morbido = tettoCopieMorbido(formalita, sotto);
  if (K.COPIE_META_DEI_PEZZI && serve && !(capienza != null && capienza <= 8)) {
    morbido = Math.min(morbido, Math.max(1, ceilDiv(serve, 2)));
  }
  return morbido;
}

export function ripartisciCopie(serve: number, tetti: [number, number][]): [number[], number] {
  const out: number[] = [];
  let resto = serve;
  for (const [morbido] of tetti) { const x = Math.min(resto, morbido); out.push(x); resto -= x; }
  while (resto > 0) {
    let dato = false;
    tetti.forEach(([, duro], i) => {
      if (resto > 0 && out[i] < duro) { out[i] += 1; resto -= 1; dato = true; }
    });
    if (!dato) break;
  }
  return [out, resto];
}

// ── Tappe e copertura termica ───────────────────────────────────────────────
export function ordinaTappe(perTappa: Record_[]): Record_[] {
  perTappa.forEach((t, i) => { if (!("_ordine" in t)) t._ordine = i; });
  return ordina(perTappa, (t) => [
    -(t.meteo.temp_max_media != null ? t.meteo.temp_max_media : -99.0),
    -(t.giorni || 0),
    t._ordine,
  ]);
}

export const pavimentoDi = (meteo: Record_) => warmthFloor(meteo.temp_min_media);
export const tettoDi = (meteo: Record_) => Math.max(warmthCeiling(meteo.temp_max_media), K.TETTO_MINIMO);

export function pilaDiTappa(capi: Record_[], tappa: string): Record_[] {
  return capi.filter((x) => (x.tappe || []).includes(tappa) && K.ZONE_STRATIFICABILI.has(x.category));
}

export function pilaTermica(capi: Record_[], tappa: string | null): Record_[] {
  if (tappa != null) return pilaDiTappa(capi, tappa);
  return capi.filter((x) => K.ZONE_STRATIFICABILI.has(x.category));
}

export function coperturaTermica(capi: Record_[], meteo: Record_, tappa: string | null) {
  const floor = pavimentoDi(meteo);
  const ceiling = tettoDi(meteo);
  const isolanteMinimo = floor >= 5 ? 4 : K.CALORE_ISOLANTE;
  const pila = pilaTermica(capi, tappa).filter((x) => (x.warmth || 0) <= ceiling);
  const calore = caloreEfficace(pila, isolanteMinimo);
  return { coperta: calore >= floor, calore, floor, ceiling, isolante_minimo: isolanteMinimo };
}

export function assicuraInvolucroTermico(capi: Record_[], gaps: Record_[], items: Capo[], meteo: Record_,
  tappa: string | null, used: Set<string>, bulkPress: number): Record_[] {
  const cop = coperturaTermica(capi, meteo, tappa);
  if (cop.coperta) return capi;
  const { floor, ceiling, isolante_minimo: isoMin } = cop;
  let aggiunti = 0;
  while (!coperturaTermica(capi, meteo, tappa).coperta && aggiunti < 2) {
    const pila = pilaTermica(capi, tappa);
    if (tappa != null) {
      const gia = capi.filter((x) => !(x.tappe || []).includes(tappa) && K.ZONE_STRATIFICABILI.has(x.category) &&
        (x.warmth || 1) <= ceiling && caloreEfficace([...pila, x], isoMin) > caloreEfficace(pila, isoMin));
      if (gia.length) {
        const scelto = massimo(gia, (x) => x.warmth || 0)!;
        scelto.tappe.push(tappa);
        aggiunti += 1;
        continue;
      }
    }
    const scStr = (g: Capo) => score(g, 1, floor, new Set(), new Set(), 0, bulkPress);
    let cands = items.filter((g) => g.has_metadata && !g.sempre_in_valigia && !used.has(g.id) &&
      K.ZONE_STRATIFICABILI.has(g.category) && 2 <= (g.warmth || 0) && (g.warmth || 0) <= floor &&
      (g.warmth || 1) <= ceiling && scStr(g) <= K.MAX_PENALTY);
    const isolanti = cands.filter((g) => g.category === "Outerwear" && (g.warmth || 0) >= isoMin);
    if (isolanti.length) cands = isolanti;
    else if (!pila.some((x) => x.category === "Outerwear")) cands = cands.filter((g) => g.category === "Outerwear");
    else break;
    if (!cands.length) break;
    const g = massimo(cands, (x) => [x.warmth || 0, -(x.bulk || 1)])!;
    used.add(g.id);
    capi.push({
      slot: tappa == null ? "strato caldo" : `strato per ${tappa}`, match: "involucro_termico", imposto: true,
      category: g.category, slot_category: g.category, item_id: g.id, item: g.name, subCategory: g.sub_category,
      formality: g.formality, coverage: g.coverage, warmth: g.warmth, frequency: "once",
      penalita: round2(scStr(g)), waterResistance: g.water_resistance, bulk: g.bulk, quantita: 1,
      essential: true, ideale_mancante: [], tappe: tappa == null ? [] : [tappa],
      reason: `la pila arriva a ${caloreEfficace(pila, isoMin).toFixed(1)}, serve ${floor}`,
    });
    aggiunti += 1;
  }
  const fin = coperturaTermica(capi, meteo, tappa);
  if (!fin.coperta) {
    const posseduti = items.filter((g) => g.has_metadata && g.category === "Outerwear");
    const gap: Record_ = {
      slot: tappa == null ? "strato caldo mancante" : `strato caldo mancante a ${tappa}`,
      category: "Outerwear", essential: true, imposto: false, tappe: tappa == null ? [] : [tappa],
      subCategories: ["Coat", "Down Jacket"], warmth_richiesto: [floor, Math.max(floor, ceiling)],
      reason: `la pila arriva a ${fin.calore.toFixed(1)}, serve ${floor}`,
    };
    if (posseduti.length) {
      const m = massimo(posseduti, (g) => [g.warmth || 0, g.sub_category === "Coat" || g.sub_category === "Down Jacket"])!;
      Object.assign(gap, { tipo: "posseduto_ma_inadatto", candidato_scartato: m.name, candidato_warmth: m.warmth,
        impermeabilita_richiesta: 0, candidato_wr: m.water_resistance });
    } else gap.tipo = "assente";
    gaps.push(gap);
  }
  return capi;
}

// ── strategy_slots ──────────────────────────────────────────────────────────
export interface ArgomentiSlots {
  giorni: number;
  lavatrice: boolean;
  attivita?: string[] | null;
  temp_min?: number | null;
  temp_max?: number | null;
  bagaglio?: string;
  giorni_pioggia?: number | null;
  intensita?: string | null;
  voti_scarpe?: Record<string, number> | null;
  profili_capi?: Record<string, any> | null;
  scarti_capi?: Record<string, number> | null;
  classi_viaggio?: Record<string, any> | null;
  temp_min_assoluta?: number | null;
  attivita_viaggio?: string[] | null;
  lavatrice_essenziali?: boolean | null;
}

/** Contenitori dentro un oggetto o un array: `x in xs` di Python per i dict (uguaglianza). */
function contiene(xs: Record_[], x: Record_): boolean {
  if (xs.includes(x)) return true;
  const s = JSON.stringify(x);
  return xs.some((y) => JSON.stringify(y) === s);
}

export function strategySlots(testoModello: string, items: Capo[], a: ArgomentiSlots): Record_ {
  rejects.length = 0;
  fixes.length = 0;
  const giorni = a.giorni;
  let lavatrice = a.lavatrice;
  const attivita = a.attivita ?? null;
  const tempMin = a.temp_min ?? null, tempMax = a.temp_max ?? null;
  const bagaglio = a.bagaglio ?? "";
  const giorniPioggia = a.giorni_pioggia ?? null;
  const intensita = a.intensita ?? null;
  const votiScarpe = a.voti_scarpe ?? null, profiliCapi = a.profili_capi ?? null;
  const scartiCapi = a.scarti_capi ?? null, classiViaggio = a.classi_viaggio ?? null;

  const inAcquaTappa = eAttivitaAcqua(attivita);
  const lavatriceVera = a.lavatrice_essenziali == null ? lavatrice : a.lavatrice_essenziali;
  if (K.CAMMINO_LAVA_A_MANO && rc.camminoAPiedi(attivita, bagaglio, giorni)) lavatrice = true;
  const cultoCaldo = rc.cultoLeggero(tempMax);
  const tagDi = new Map(items.map((g) => [g.id, g.activity_tags]));
  let slots: Slot[] = parseJsonBlock(testoModello);
  const prima = slots.length;
  const attViaggio = a.attivita_viaggio != null ? a.attivita_viaggio : (attivita || []);
  segnaCapiDaNeve(items, [...attViaggio, ...(attivita || [])]);
  if (K.NIENTE_FORMALE_SENZA_OCCASIONE && vero(attViaggio) && !viaggioDiLavoro(attViaggio, classiViaggio) &&
    !rc.occasioneFormale(attViaggio)) {
    const n0 = slots.length;
    slots = slots.filter((x) => !(vero(x.formality) && sottoinsieme(x.formality, insieme(["Business", "Formal"]))));
    if (slots.length !== n0) fixes.push("slot da lavoro rimossi: nessuna occasione formale");
  }
  if (!eAttivitaAcqua(attivita)) {
    const n0 = slots.length;
    slots = slots.filter((x) => { const s = insieme(x.subCategories || []); return !(s.size === 1 && s.has("Swimwear")); });
    for (const x of slots) {
      const subs = insieme(x.subCategories || []);
      if (subs.has("Swimwear")) { subs.delete("Swimwear"); x.subCategories = [...subs].sort(); }
    }
    if (slots.length !== n0) fixes.push("costume rimosso: nessuna attivita in acqua");
  }
  const attNorm = insieme((attivita || []).map((x) => x.toLowerCase().trim()));
  if (interseca(attNorm, K.ATTIVITA_CODICE_ABBIGLIAMENTO)) {
    const presenti = insieme(slots.flatMap((s) => s.coverage || []));
    for (const [nome, cat, subs, cov] of K.DRESS_CODE_SLOTS) {
      if (interseca(presenti, cov)) continue;
      slots.push({ slot: nome, category: cat, subCategories: subs, coverage: cov, minWarmth: 1, maxWarmth: 5,
        formality: [], activityTags: [], frequency: "daily", essential: true,
        reason: "codice di abbigliamento dichiarato dalle attivita" });
    }
  }
  const capienza = capienzaBagaglio(bagaglio);
  slots = injectMandatory(slots, attivita || []);
  slots = injectStratoFormale(slots, attivita || [], giorni, capienza);
  slots = injectParteInferioreFormale(slots, giorni, capienza);
  slots = injectFabbisogno(slots, tempMin, tempMax, giorniPioggia, giorni, capienza, attivita, classiViaggio,
    a.temp_min_assoluta ?? null, attViaggio);
  slots.push(...slotCapiNuovi(items, tempMin, attivita, giorniPioggia, capienza, slots));
  const nImposti = slots.length - prima;
  let nClamp = 0;
  const floor = warmthFloor(tempMin);
  const ceilingGrezzo = warmthCeiling(tempMax);
  const ceiling = Math.max(ceilingGrezzo, K.TETTO_MINIMO);
  const nTettoAlzato = ceiling !== ceilingGrezzo ? 1 : 0;
  let nGuscioEsente = 0, nBandaAllargata = 0, nTettoCopie = 0, nLacuneQuantita = 0, nEsclusiTetto = 0;
  let gruppoCapoSeq = 0;
  const stratiCondivisi = new Set<unknown>();
  let nStratiCondivisi = 0, nCultoCondivisi = 0, nCultoCompromessi = 0;
  const lavoro = viaggioDiLavoro(attivita, classiViaggio);
  const bulkPress = capienza <= 30 ? 0.25 : (capienza <= 55 ? 0.12 : 0.0);
  const used = new Set<string>();
  let ideali: Record_[] = [], ripieghi: Record_[] = [];
  const gaps: Record_[] = [];
  const richiesti: Record_[] = [];
  const GUSCI: Set<string> = K.GUSCI;

  for (const s of slots) {
    const ideal = new Set<string>([...normList(vero(s.subCategories) ? s.subCategories : s.idealSubCategories, SUBCATEGORIES)]
      .map((x) => tx.perIlGeneratore(x) as string));
    const forms = normList(vero(s.formality) ? s.formality : s.formalityHints, FORMALITIES);
    const tags = normList(s.activityTags, ACTIVITY_TAGS);
    let lo = s.minWarmth || 1;
    let hi = s.maxWarmth || 5;
    const soloGuscio = ideal.size > 0 && sottoinsieme(ideal, GUSCI);
    if (!vero(s._imposto)) {
      if (s.category === "Outerwear" && !soloGuscio) {
        if (!interseca(forms, ["Business", "Formal"])) {
          if (floor > lo) nClamp += 1;
          lo = Math.max(lo, floor);
        }
        hi = Math.min(hi, floor);
      }
      if (soloGuscio) nGuscioEsente += 1;
      else if (ceiling < hi || ceiling < lo) nClamp += 1;
      if (!soloGuscio) {
        lo = Math.min(lo, ceiling);
        hi = Math.max(lo, Math.min(hi, ceiling));
      }
    }
    if (ideal.size && !vero(s._imposto)) {
      const possedutiSlot = items.filter((g) => g.has_metadata && ideal.has(g.sub_category));
      if (possedutiSlot.length && !possedutiSlot.some((g) => lo <= (g.warmth || 3) && (g.warmth || 3) <= hi)) {
        const versoAlto = possedutiSlot.map((g) => g.warmth || 3).filter((w) => lo <= w && w <= ceiling);
        if (versoAlto.length) { hi = Math.max(hi, Math.max(...versoAlto)); nBandaAllargata += 1; }
      }
    }
    const freq = get(s, "frequency", "daily");
    const intensitaSlot = normIntensita(s.intensita) || intensita;
    const reusable = K.REUSABLE.has(s.category);
    richiesti.push({
      slot: get(s, "slot"), category: get(s, "category", ""), subCategories: [...ideal].sort(),
      formality: [...forms].sort(), activityTags: [...tags].sort(),
      minWaterResistance: Math.trunc(Number(s.minWaterResistance || 0)), minWarmth: lo,
      frequency: get(s, "frequency", "daily"), imposto: Boolean(vero(s._fabbisogno) || vero(s._imposto)),
      reason: get(s, "reason", ""),
    });
    const condividi = (base: Record_) => {
      const c = { ...base, slot: get(s, "slot"), match: "ideale", imposto: true, condiviso: true,
        reason: `${ps(get(s, "reason", ""))} (condiviso con '${ps(get(base, "slot"))}')` };
      (contiene(ideali, base) ? ideali : ripieghi).push(c);
    };

    if (vero(s._fabbisogno) && (s.slot === K.SLOT_STRATO_SERA || s.slot === K.SLOT_SECONDO_STRATO)) {
      const sera = s.slot === K.SLOT_STRATO_SERA;
      const ordine = sera ? 1 : 2;
      const caldi = new Map<unknown, Record_>();
      for (const r of [...ideali, ...ripieghi]) {
        if (r.category === "Upper Body" && K.SOTTOCAT_MEDIO.includes(r.subCategory) &&
          (r.warmth || 0) >= K.CALORE_STRATO_CONDIVISIBILE && (sera || !capoRiservato(r, profiliCapi))) {
          const k = get(r, "item_id");
          if (!caldi.has(k)) caldi.set(k, r);
        }
      }
      if (caldi.size >= ordine) {
        const liberi = [...caldi.entries()].filter(([i]) => !stratiCondivisi.has(i)).map(([, r]) => r);
        const base = (liberi.length ? liberi : [...caldi.values()])[0];
        stratiCondivisi.add(get(base, "item_id"));
        condividi(base);
        nStratiCondivisi += 1;
        continue;
      }
    }
    if (vero(s._fabbisogno) && s.slot === K.SLOT_CAPOSPALLA_CALDO) {
      const gia = [...ideali, ...ripieghi].filter((r) => r.category === "Outerwear" && (r.warmth || 0) >= 4);
      if (gia.length) { condividi(gia[0]); continue; }
    }
    if (vero(s._fabbisogno) && s.slot === K.SLOT_SERA_PRESENTABILE) {
      let gia = [...ideali, ...ripieghi].filter((r) => r.category === "Upper Body" &&
        K.SOTTOCAT_PRESENTABILI.includes(r.subCategory) && K.FORMALITA_PRESENTABILI.includes(r.formality));
      const diversi = new Set(gia.map((r) => get(r, "item_id"))).size;
      if (diversi < (s._presentabili || 1)) { s._restano = (s._presentabili || 1) - diversi; gia = []; }
      if (gia.length) { condividi(gia[0]); continue; }
    }
    if (K.SLOT_CULTO.includes(s.slot) && vero(s.coverage)) {
      const covC = insieme(s.coverage), subsC = insieme(s.subCategories || []);
      const gia = [...ideali, ...ripieghi].filter((r) => r.category === get(s, "category") && subsC.has(r.subCategory) &&
        covC.has(r.coverage) && (!cultoCaldo || capoLeggero(r, profiliCapi)) && !capoRiservato(r, profiliCapi));
      if (gia.length) { condividi(gia[0]); nCultoCondivisi += 1; continue; }
    }

    const minWr = Math.trunc(Number(s.minWaterResistance || 0));
    const fallback = new Set<string>();
    for (const sub of ideal) for (const f of (K.SUBSTITUTIONS[sub] ?? [])) if (!ideal.has(f)) fallback.add(f);
    const wrRigido = vero(s._fabbisogno) && minWr > 0;
    const covReq = insieme(s.coverage || []);
    const nonCasual = forms.size > 0 && !forms.has("Casual");
    const votoScarpe = (vero(votiScarpe) && s.category === "Shoes" && s.slot !== "calzature di ricambio" && !nonCasual)
      ? votiScarpe : null;
    const votoCapi = vero(scartiCapi) && ["Upper Body", "Lower Body", "Outerwear"].includes(s.category) && !nonCasual;
    const giornoCasual = ["Upper Body", "Lower Body"].includes(s.category) && !K.SLOT_CULTO.includes(s.slot) && !nonCasual;
    const formaleRigido = K.FORMALE_SENZA_RIPIEGO_CASUAL && forms.size > 0 && !forms.has("Casual") &&
      K.CATEGORIE_FORMALE_RIGIDO.has(s.category);
    const ruoliGia = (K.TETTO_DOPPIONI && s.slot === "calzature di ricambio")
      ? new Set([...ideali, ...ripieghi].filter((x) => x.category === "Shoes")
        .map((x) => rc.ruoloScarpa(x.subCategory, tagDi.get(x.item_id) ?? [], x.warmth, x.formality)))
      : new Set<string>();

    const sc = (g: Capo) => score(g, lo, hi, forms, tags, minWr, bulkPress) +
      penalitaVoto(votoScarpe, g) +
      penalitaCulto(s.slot, g, profiliCapi, cultoCaldo) +
      (votoCapi ? penalitaVetoCapo(scartiCapi, g) : 0.0) +
      (giornoCasual && capoRiservato(g, profiliCapi) ? K.PESO_ELEGANTE_DI_GIORNO : 0.0) +
      (vero(s._preferisci_calore) ? K.PESO_CALORE_TESTA * Math.max(0, 4 - (g.warmth || 1)) : 0.0);

    const pick = (subs: Set<string>, compromesso = false): Capo | null => {
      const soglia = compromesso ? K.MAX_PENALTY_COMPROMESSO : K.MAX_PENALTY;
      const tettoW = compromesso ? Math.min(hi + K.MARGINE_CALORE_COMPROMESSO, ceiling) : hi;
      const cands = items.filter((g) => g.has_metadata && !g.sempre_in_valigia && (reusable || !used.has(g.id)) &&
        subs.has(g.sub_category) && (!wrRigido || (g.water_resistance || 0) >= minWr) &&
        (!covReq.size || covReq.has(g.coverage)) &&
        !estivoFuoriStagione(g, tempMax, inAcquaTappa, profiliCapi) &&
        !(formaleRigido && K.FORMALITA_CASUAL.has(g.formality)) &&
        !(ruoliGia.size && ruoliGia.has(rc.ruoloScarpa(g.sub_category, g.activity_tags, g.warmth, g.formality))) &&
        (!vero(s._tag_rigido) || g.activity_tags.some((t) => tags.has(t))) &&
        (g.warmth || 1) <= tettoW &&
        (!soloGuscio || GUSCI.has(g.sub_category) || (g.warmth || 1) <= ceiling) &&
        (!compromesso || (g.warmth || 3) >= lo) &&
        sc(g) <= soglia);
      nEsclusiTetto += items.filter((g) => g.has_metadata && !g.sempre_in_valigia && (reusable || !used.has(g.id)) &&
        subs.has(g.sub_category) && (g.warmth || 1) > hi && sc(g) <= soglia).length;
      const ord = ordina(cands, sc);
      return ord.length ? ord[0] : null;
    };
    const unione = (a1: Set<string>, b1: Set<string>) => new Set([...a1, ...b1]);

    let g = pick(ideal), kind = "ideale";
    if (g == null && K.CAPI_DIVERSI_ELEGANTI && forms.size && !forms.has("Casual") && s.category === "Lower Body") {
      g = pick(ideal, true); kind = "compromesso";
    }
    if (g == null) { g = pick(fallback); kind = "ripiego"; }
    if (g == null) { g = pick(unione(ideal, fallback), true); kind = "compromesso"; }
    if (g == null) {
      const tutte = unione(ideal, fallback);
      const posseduti = items.filter((x) => x.has_metadata && tutte.has(x.sub_category));
      if (posseduti.length) {
        const sco = (x: Capo) => score(x, lo, hi, forms, tags, minWr, bulkPress);
        const migliore = minimo(posseduti, sco)!;
        gaps.push({
          slot: get(s, "slot"), tipo: "posseduto_ma_inadatto", imposto: vero(s._imposto),
          category: get(s, "category", ""), formality: [...forms].sort(), essential: get(s, "essential", false),
          subCategories: [...ideal].sort(), reason: get(s, "reason", ""), candidato_scartato: migliore.name,
          candidato_warmth: migliore.warmth, warmth_richiesto: [lo, hi], penalita: round2(sco(migliore)),
          impermeabilita_richiesta: minWr, candidato_wr: migliore.water_resistance,
        });
      } else {
        gaps.push({
          slot: get(s, "slot"), tipo: "assente", imposto: vero(s._imposto), category: get(s, "category", ""),
          essential: get(s, "essential", false), subCategories: [...ideal].sort(), reason: get(s, "reason", ""),
        });
      }
      continue;
    }

    gruppoCapoSeq += 1;
    const gruppoCapoId = gruppoCapoSeq;
    const costruisciRec = (capo: Capo, tipoMatch: string, quanti: number) => {
      const r: Record_ = {
        slot: get(s, "slot"), match: tipoMatch, imposto: vero(s._imposto),
        category: capo.category || get(s, "category", ""), slot_category: get(s, "category", ""),
        item_id: capo.id, item: capo.name, subCategory: capo.sub_category, formality: capo.formality,
        coverage: capo.coverage, warmth: capo.warmth, frequency: freq, intensita: intensitaSlot,
        penalita: round2(score(capo, lo, hi, forms, tags, minWr, bulkPress)),
        waterResistance: capo.water_resistance, bulk: capo.bulk, quantita: quanti,
        essential: get(s, "essential", false), reason: get(s, "reason", ""), _gruppo_capo: gruppoCapoId,
        _slot_elegante: forms.size > 0 && !forms.has("Casual"),
      };
      if (tipoMatch !== "ideale") {
        r.ideale_mancante = [...ideal].sort();
        if (tipoMatch === "compromesso") {
          const manche: string[] = [];
          if (minWr && (capo.water_resistance || 0) < minWr) {
            manche.push(`impermeabilita ${ps(capo.water_resistance)} invece di ${minWr}`);
          }
          if (forms.size && capo.formality && !forms.has(capo.formality)) manche.push(`formalita ${capo.formality}`);
          if (tags.size && !capo.activity_tags.some((t) => tags.has(t))) manche.push("non pensato per questa attivita");
          r.compromesso = manche.length ? manche : ["scelta ripiegata"];
        }
      }
      (tipoMatch === "ideale" ? ideali : ripieghi).push(r);
    };
    let serve = quantityFor(g.sub_category, g.name, giorni, lavatrice, freq, intensitaSlot, tempMax,
      giorniDiMare(giorni, attivita), g.warmth);
    if (lavoro && giorni >= 2 && capienza > 8 && K.FREQ_MINIMO_LAVORO.includes(freq) && forms.size &&
      !forms.has("Casual") && ["Upper Body", "Lower Body"].includes(s.category)) {
      serve = Math.max(serve, K.MINIMO_FORMALI_LAVORO);
    }
    if (vero(s._restano)) serve = Math.max(serve, s._restano);
    let capo: Capo | null = g, tipoMatch = kind, resto = serve;
    const diversiEleganti = K.CAPI_DIVERSI_ELEGANTI && forms.size > 0 && !forms.has("Casual");
    const recsSlot: [Record_, Capo][] = [];
    while (true) {
      used.add(capo!.id);
      const quanti = Math.min(resto, diversiEleganti ? 1
        : tettoMorbidoPer(serve, capo!.formality, capo!.sub_category, capienza));
      const nI = ideali.length, nR = ripieghi.length;
      costruisciRec(capo!, tipoMatch, quanti);
      const nuovo = ideali.length > nI ? ideali[ideali.length - 1] : ripieghi.length > nR ? ripieghi[ripieghi.length - 1] : null;
      if (nuovo != null) recsSlot.push([nuovo, capo!]);
      resto -= quanti;
      if (resto <= 0) break;
      nTettoCopie += 1;
      capo = pick(ideal); tipoMatch = "ideale";
      if (capo == null && !diversiEleganti) { capo = pick(fallback); tipoMatch = "ripiego"; }
      if (capo == null && !diversiEleganti) { capo = pick(unione(ideal, fallback), true); tipoMatch = "compromesso"; }
      else if (capo == null && diversiEleganti) { capo = pick(ideal, true); tipoMatch = "compromesso"; }
      if (capo != null && giornoCasual && capoRiservato(capo, profiliCapi)) capo = null;
      if (capo == null && recsSlot.length) {
        const [qq, r2] = ripartisciCopie(resto + recsSlot.reduce((t, [r]) => t + r.quantita, 0),
          recsSlot.map(([r, c]) => [r.quantita, tettoCopie(c.formality, c.sub_category)] as [number, number]));
        resto = r2;
        recsSlot.forEach(([r], i) => { r.quantita = qq[i]; });
        if (resto <= 0) break;
      }
      if (capo == null) {
        nLacuneQuantita += 1;
        const T = K.TETTO_COPIE_STESSO_CAPO;
        gaps.push({
          slot: get(s, "slot"), tipo: "quantita_insufficiente", imposto: vero(s._imposto),
          category: get(s, "category", ""), essential: get(s, "essential", false), subCategories: [...ideal].sort(),
          usi_richiesti: serve, usi_coperti: serve - resto, capi_diversi_necessari: ceilDiv(serve, T),
          reason: `${giorni} giorni ${lavatrice ? "con" : "senza"} lavatrice: servirebbero ${ceilDiv(serve, T)} ` +
            `capi diversi per questo slot, ne hai ${floorDiv(serve - resto + T - 1, T)}`,
        });
        break;
      }
    }
    if (K.SLOT_CULTO.includes(s.slot) && recsSlot.length) {
      for (const [r, c] of recsSlot) {
        if (capoRiservato(c, profiliCapi)) {
          r.compromesso = [K.COMPROMESSO_ELEGANTE];
          r.manchevolezze = [K.COMPROMESSO_ELEGANTE];
          nCultoCompromessi += 1;
        }
      }
      if (s.category === "Upper Body") {
        const tshirt = [...ideali, ...ripieghi].filter((r) => r.subCategory === "T-Shirt" && q(r) > 1 && !vero(r.imposto));
        if (tshirt.length) massimo(tshirt, (r) => r.quantita)!.quantita -= 1;
      }
    }
  }

  // ── Rete per le zone rimaste scoperte ──
  const coperte = insieme([...ideali, ...ripieghi].map((r) => r.category));
  for (const [zona, subs] of Object.entries(K.ZONE_FALLBACK) as [string, string[]][]) {
    if (coperte.has(zona)) continue;
    const larghe = insieme(subs);
    const sc = (g: Capo) => score(g, 1, ceiling, new Set(), new Set(), 0, bulkPress) +
      penalitaVoto(zona === "Shoes" ? votiScarpe : null, g);
    const cands = items.filter((g) => g.has_metadata && !g.sempre_in_valigia && !used.has(g.id) &&
      larghe.has(g.sub_category) && !estivoFuoriStagione(g, tempMax, inAcquaTappa, profiliCapi) && sc(g) <= K.MAX_PENALTY);
    if (!cands.length) continue;
    const g = minimo(cands, sc)!;
    used.add(g.id);
    ripieghi.push({
      slot: `rete zona ${zona}`, match: "fabbisogno", imposto: true, category: g.category || zona, slot_category: zona,
      item_id: g.id, item: g.name, subCategory: g.sub_category, formality: g.formality, warmth: g.warmth,
      frequency: "daily", penalita: round2(sc(g)), waterResistance: g.water_resistance, bulk: g.bulk,
      quantita: quantityFor(g.sub_category, g.name, giorni, lavatrice, "daily", intensita, tempMax, null, g.warmth),
      essential: true, ideale_mancante: [...larghe].sort(), reason: `zona ${zona} rimasta scoperta dopo il matching`,
    });
  }

  // ── Rete termica: strati aggiunti finche' la pila non scalda abbastanza ──
  const pila = [...ideali, ...ripieghi].filter((x) => K.ZONE_STRATIFICABILI.has(x.category));
  const isoMin = floor >= 5 ? 4 : K.CALORE_ISOLANTE;
  let aggiuntiStrati = 0;
  const reteAttiva = tempMin == null || tempMin < K.SOGLIA_RETE_TERMICA || !pila.some((x) => x.category === "Outerwear");
  while (reteAttiva && caloreEfficace(pila, isoMin) < floor && aggiuntiStrati < 2) {
    const scStr = (g: Capo) => score(g, 1, floor, new Set(), new Set(), 0, bulkPress);
    const serveIsolante = !pila.some((x) => (x.warmth || 0) >= isoMin && x.category === "Outerwear");
    const nienteSopra = !pila.some((x) => x.category === "Outerwear");
    let soloProtezione = false;
    let cands = items.filter((g) => g.has_metadata && !g.sempre_in_valigia && !used.has(g.id) &&
      K.ZONE_STRATIFICABILI.has(g.category) && 2 <= (g.warmth || 0) && (g.warmth || 0) <= floor &&
      !(K.ESCLUDI_BLAZER_RETE && g.sub_category === "Blazer") && scStr(g) <= K.MAX_PENALTY);
    if (serveIsolante) {
      const isolanti = cands.filter((g) => g.category === "Outerwear" && (g.warmth || 0) >= isoMin);
      if (isolanti.length) cands = isolanti;
      else {
        const pesi = pila.filter((x) => x.category === "Outerwear").map((x) => x.warmth || 0);
        const meglioDi = Math.max(...(pesi.length ? pesi : [0]));
        cands = cands.filter((g) => g.category === "Outerwear" && (g.warmth || 0) > meglioDi);
        if (!cands.length) break;
        soloProtezione = true;
      }
    }
    if (!cands.length) break;
    const escursione = tempMax != null && tempMin != null ? tempMax - tempMin : 0;
    const ruoliPila = insieme(pila.map((x) => K.RUOLO_STRATO[x.subCategory || ""] ?? "base"));
    const guadagno = (g: Capo) => {
      const finta = [...pila, { warmth: g.warmth, category: g.category, subCategory: g.sub_category }];
      const delta = caloreEfficace(finta) - caloreEfficace(pila);
      const ruolo = K.RUOLO_STRATO[g.sub_category || ""] ?? "base";
      const nuovoRuolo = ruoliPila.has(ruolo) ? 0 : 1;
      if (escursione >= K.ESCURSIONE_A_STRATI) {
        return [nuovoRuolo, delta > 0 ? 1 : 0, -(g.warmth || 5), -(g.bulk || 1), -scStr(g)];
      }
      return [nuovoRuolo, delta, -(g.bulk || 1), -scStr(g)];
    };
    const g = soloProtezione ? massimo(cands, (x) => [x.warmth || 0, -(x.bulk || 1)])! : massimo(cands, guadagno)!;
    const migliora = caloreEfficace([...pila, { warmth: g.warmth, category: g.category, subCategory: g.sub_category }], isoMin) >
      caloreEfficace(pila, isoMin);
    if (!migliora && !nienteSopra) break;
    used.add(g.id);
    const ruoloG = K.RUOLO_STRATO[g.sub_category || ""] ?? "base";
    const rec = {
      slot: "strato aggiuntivo", match: "stratificazione", imposto: true, category: g.category,
      slot_category: g.category, item_id: g.id, item: g.name, subCategory: g.sub_category, formality: g.formality,
      coverage: g.coverage, warmth: g.warmth, frequency: ruoloG === "base" ? "daily" : "once",
      penalita: round2(scStr(g)), waterResistance: g.water_resistance, bulk: g.bulk,
      quantita: ruoloG === "base"
        ? quantityFor(g.sub_category, g.name, giorni, lavatrice, "daily", intensita, tempMax, null, g.warmth) : 1,
      essential: true, ideale_mancante: [],
      reason: `stratificazione: la pila arriva a ${caloreEfficace(pila, isoMin).toFixed(1)}, serve ${floor}`,
    };
    ripieghi.push(rec);
    pila.push(rec);
    aggiuntiStrati += 1;
  }

  if (K.BASE_LEGGERA_COL_FREDDO && tempMin != null && tempMin < K.SOGLIA_BASE_LEGGERA && capienza > 8) {
    const leggero = (g: Capo) => g.category === "Upper Body" && K.SOTTOCAT_BASE.includes(g.sub_category) &&
      (g.warmth || 3) <= rc.CALORE_SOPRA_LEGGERO;
    const perId = new Map(items.map((g) => [g.id, g]));
    const gia = new Set([...ideali, ...ripieghi].filter((x) => perId.get(x.item_id) && leggero(perId.get(x.item_id)!))
      .map((x) => get(x, "item_id")));
    const candidati = ordina(items.filter((g) => g.has_metadata && !g.sempre_in_valigia && !used.has(g.id) && leggero(g)),
      (g) => [g.sub_category !== "T-Shirt", g.bulk || 1]);
    for (const g of candidati.slice(0, Math.max(0, K.MINIMO_BASE_LEGGERA - gia.size))) {
      used.add(g.id);
      ripieghi.push({
        slot: "strato base sulla pelle", match: "fabbisogno", imposto: true, category: g.category,
        slot_category: "Upper Body", item_id: g.id, item: g.name, subCategory: g.sub_category, formality: g.formality,
        coverage: g.coverage, warmth: g.warmth, frequency: "daily", penalita: 0.0,
        waterResistance: g.water_resistance, bulk: g.bulk, quantita: 1, essential: true, ideale_mancante: [],
        reason: `minima ${pf(tempMin)}: sotto i maglioni servono capi leggeri`,
      });
    }
  }

  if (K.SLOT_TREKKING && eTrekking(attivita)) {
    const ruoloDi = (g: Capo) => rc.ruoloScarpa(g.sub_category, g.activity_tags, g.warmth, g.formality);
    const perId = new Map(items.map((g) => [g.id, g]));
    const scarpe = [...ideali, ...ripieghi].filter((x) => x.category === "Shoes");
    if (!scarpe.some((x) => perId.get(x.item_id) && ruoloDi(perId.get(x.item_id)!) === "trekking")) {
      const daTrek = ordina(items.filter((g) => g.has_metadata && g.category === "Shoes" && !used.has(g.id) &&
        ruoloDi(g) === "trekking" && (g.warmth || 3) <= warmthCeiling(tempMax) + K.MARGINE_CALORE_COMPROMESSO),
        (g) => [g.warmth || 3, g.bulk || 1]);
      const slotTrek = insieme(slots.filter((x) => x.category === "Shoes" && (x.subCategories || []).includes("Hiking Boots"))
        .map((x) => get(x, "slot")));
      const delloSlot = scarpe.filter((x) => slotTrek.has(get(x, "slot")));
      if (daTrek.length && delloSlot.length) {
        const g = daTrek[0];
        used.add(g.id);
        Object.assign(delloSlot[0], { item_id: g.id, item: g.name, subCategory: g.sub_category, formality: g.formality,
          warmth: g.warmth, waterResistance: g.water_resistance, bulk: g.bulk, coverage: g.coverage,
          match: "compromesso", compromesso: ["scarpa da trekking anche se calda per il clima"] });
      }
    }
  }

  const meteoTappa = { temp_min_media: tempMin, temp_max_media: tempMax };
  let capiLeg = [...ideali, ...ripieghi];
  const gapsPrima = gaps.length;
  if (!gaps.some((gp) => gp.category === "Outerwear")) {
    const n0 = capiLeg.length;
    capiLeg = assicuraInvolucroTermico(capiLeg, gaps, items, meteoTappa, null, used, bulkPress);
    ripieghi.push(...capiLeg.slice(n0));
  }
  const nStratiInsufficienti = gaps.length - gapsPrima;
  [ideali, ripieghi] = consolidaBloccoViaggio(ideali, ripieghi);
  const tengo = capospallaInTracolla([...ideali, ...ripieghi], capienza);
  ideali = ideali.filter((x) => tengo.includes(x));
  ripieghi = ripieghi.filter((x) => tengo.includes(x));
  const nDoppioni = togliDoppioni([...ideali, ...ripieghi], items, giorni, tempMin);
  const nRotazione = applicaBudgetRotazione([...ideali, ...ripieghi], giorni,
    minimoCapiLeggeri([[giorni, tempMax]], lavatrice), [[giorni, tempMax, tempMin]], lavatrice);
  ideali = ideali.filter((x) => q(x) >= 1);
  ripieghi = ripieghi.filter((x) => q(x) >= 1);
  const nVolume = applicaTettoVolume([...ideali, ...ripieghi], capienzaPotabile(bagaglio));
  const avvisoVolume = segnalaVolume([...ideali, ...ripieghi], capienzaPotabile(bagaglio));
  if (avvisoVolume) gaps.push(avvisoVolume);
  const avvisoScarpe = segnalaScarpeCammino([...ideali, ...ripieghi], items, attivita);
  if (avvisoScarpe) gaps.push(avvisoScarpe);
  berrettoColFreddo([...ideali, ...ripieghi], items, tempMin);
  segnaInPartenza([...ideali, ...ripieghi]);
  const setFix = new Set(fixes.map(String)), setRej = new Set(rejects.map(String));
  return {
    essenziali: essenzialiPerViaggio(items, giorni, lavatriceVera),
    slots_richiesti: slots.length,
    ideali, ripieghi, mancanti: gaps,
    mancanti_canonici: canonicalizeGaps(gaps),
    richiesti,
    valori_scartati: [...setRej].sort(),
    valori_corretti: [...setFix].sort(),
    interventi: {
      enum_corretti: setFix.size, enum_scartati: setRej.size, slot_imposti: nImposti, clamp_calore: nClamp,
      tetto_alzato_a_2: nTettoAlzato, gusci_esentati: nGuscioEsente, esclusi_dal_tetto_rigido: nEsclusiTetto,
      rotazione_tagliata: nRotazione, doppioni_tolti: nDoppioni, volume_tagliato: nVolume,
      strati_insufficienti: nStratiInsufficienti, tetto_copie_scattato: nTettoCopie,
      strati_condivisi: nStratiCondivisi, culto_condivisi: nCultoCondivisi, culto_compromessi: nCultoCompromessi,
      banda_allargata: nBandaAllargata, lacune_quantita: nLacuneQuantita, strati_aggiunti: aggiuntiStrati,
      ripieghi: ripieghi.length, mancanti_essenziali: gaps.filter((x) => vero(x.essential)).length,
    },
  };
}
