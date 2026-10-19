// Viaggi a piu' tappe: porting di serve_per_tappa, diversifica_copie,
// conta_pezzi e strategy_slots_multitappa (packlog_checklist_bench_48.py).
// La tappa piu' calda costruisce la valigia base con una sola chiamata al
// modello; ogni altra tappa aggiunge solo cio' che le manca, con regole fisse.
import * as K from "./costanti.ts";
import * as rc from "./regole_capi.ts";
import type { Capo } from "./capo.ts";
import { eAttivitaAcqua, giorniDiMare, normIntensita, quantityFor, usiSottoSoglia } from "./quantita.ts";
import {
  capoLeggero, capoRiservato, eTrekking, insieme, interseca, penalitaCulto, quantiStratiMedi, type Record_,
  segnaCapiDaNeve, slotCapiNuovi, sottoinsieme, stratiInTracolla, caloreMaxStrato, viaggioDiLavoro,
} from "./inject.ts";
import {
  applicaBudgetRotazione, applicaTettoVolume, berrettoColFreddo, caloreEfficace, canonicalizeGaps, capienzaBagaglio,
  capienzaPotabile, consolidaBloccoViaggio, estivoFuoriStagione, minimoCapiLeggeri, score, segnaInPartenza,
  segnalaScarpeCammino, segnalaVolume, togliDoppioni,
} from "./dopo.ts";
import {
  get, ordinaTappe, pavimentoDi, pilaDiTappa, ripartisciCopie, round2, strategySlots, tettoCopie, tettoCopieMorbido,
  tettoDi, tettoMorbidoPer,
} from "./slots.ts";
import { massimo, minimo, pf, vero } from "./py.ts";

const q = (x: Record_) => x.quantita ?? 1;
const lws = (a: string) => a.toLowerCase().trim();
function contiene(xs: Record_[], x: Record_): boolean {
  if (xs.includes(x)) return true;
  const s = JSON.stringify(x);
  return xs.some((y) => JSON.stringify(y) === s);
}
const eRecord = (x: any) => "item_id" in x || !("sub_category" in x);

export function servePerTappa(t: Record_, capi: Record_[], items: Capo[], used: Set<string>, bulkPress: number,
  minimoT = false, profiliCapi: Record<string, any> | null = null, soloTrekking = false): Record_[] {
  const nome = t.destinazione, meteo = t.meteo;
  const ceiling = tettoDi(meteo);
  const tmaxTappa = meteo.temp_max_media;
  const acquaTappa = eAttivitaAcqua(t.attivita || []);
  const perId = new Map(items.map((g) => [g.id, g]));
  const capoDi = (x: any): Capo | undefined => (eRecord(x) ? perId.get(x.item_id) : x);
  const estivoQui = (x: any) => { const g = capoDi(x); return g != null && estivoFuoriStagione(g, tmaxTappa, acquaTappa, profiliCapi); };

  let richieste: Record_[] = [];
  for (const att of (t.attivita || [])) {
    for (const [slot, cat, subs, , freq] of (K.MANDATORY_SLOTS[lws(att)] ?? [])) {
      const req: Record_ = { slot, category: cat, subCategories: [...subs], minWaterResistance: 0, frequency: freq,
        reason: `${nome}: attivita '${att}'` };
      if (cat === "Shoes" && subs.includes("Hiking Boots")) {
        Object.assign(req, { senza_tetto: true, ruolo: "trekking", maxWarmth: Math.min(5, ceiling + K.MARGINE_CALORE_COMPROMESSO) });
      }
      richieste.push(req);
    }
  }
  const giaRichiesto = insieme(richieste.flatMap((r) => r.subCategories));
  if (eAttivitaAcqua(t.attivita || []) && !giaRichiesto.has("Swimwear")) {
    const [slot, cat, subs, , freq] = K.MANDATORY_SLOTS["mare/sauna"][0];
    richieste.push({ slot, category: cat, subCategories: [...subs], minWaterResistance: 0, frequency: freq,
      reason: `${nome}: attivita in acqua non catalogata per frase esatta, riconosciuta per radice` });
  }
  if ((meteo.giorni_di_pioggia || 0) >= 1) {
    richieste.push({ slot: "protezione dalla pioggia", category: "Outerwear", subCategories: ["Rain Jacket", "Windbreaker"],
      minWaterResistance: 1, reason: `${nome}: giorni di pioggia previsti` });
  }
  const attNorm = insieme((t.attivita || []).map(lws));
  if (interseca(attNorm, K.ATTIVITA_CODICE_ABBIGLIAMENTO)) {
    for (const [slot, cat, subs, cov] of K.DRESS_CODE_SLOTS) {
      richieste.push({ slot, category: cat, subCategories: [...subs], coverage: [...cov], minWaterResistance: 0,
        reason: `${nome}: codice di abbigliamento` });
    }
  }
  if (K.SLOT_TREKKING && eTrekking(t.attivita)) {
    const lista: [string, string, string[], string[], Record_][] = [
      [K.SLOT_PANTALONI_TREKKING, "Lower Body", ["Trousers"], ["Hiking"], {}],
      [K.SLOT_MAGLIETTA_TECNICA, "Upper Body", ["T-Shirt"], ["Hiking", "Sport"], {}],
      [K.SLOT_ANTIVENTO_TREKKING, "Outerwear", ["Rain Jacket", "Windbreaker"], ["Hiking"], { maxWarmth: 2, senza_tetto: true }],
    ];
    for (const [slot, cat, subs, tags, extra] of lista) {
      richieste.push({ slot, category: cat, subCategories: subs, activityTags: tags, minWaterResistance: 0,
        frequency: "occasional", reason: `${nome}: trekking, serve un capo pensato per camminare in montagna`, ...extra });
    }
    if (!richieste.some((r) => r.ruolo === "trekking")) {
      richieste.push({ slot: K.SLOT_SCARPE_TREKKING, category: "Shoes", subCategories: ["Hiking Boots"], minWaterResistance: 0,
        frequency: "once", senza_tetto: true, ruolo: "trekking", maxWarmth: Math.min(5, ceiling + K.MARGINE_CALORE_COMPROMESSO),
        reason: `${nome}: trekking, scarpe da trekking` });
    }
  }
  const tminAss = meteo.temp_min_assoluta;
  if (tminAss != null && tminAss <= K.SOGLIA_CAPOSPALLA_CALDO) {
    richieste.push({ slot: K.SLOT_CAPOSPALLA_CALDO, category: "Outerwear", subCategories: [...K.SOTTOCAT_CAPOSPALLA_CALDO],
      minWaterResistance: 0, minWarmth: 4, senza_tetto: true, frequency: "once",
      reason: `${nome}: minima assoluta ${pf(tminAss)}, serve un cappotto o un piumino` });
  }
  const tmin = meteo.temp_min_media;
  let nStrati = quantiStratiMedi(tmin, meteo.temp_max_media);
  if (minimoT) nStrati = K.STRATI_NEI_VIAGGI_MINIMI ? stratiInTracolla(tmin, nStrati) : 0;
  if (!nStrati && K.FELPA_SERA_ESTIVA && tmin != null && tmin > K.SOGLIA_STRATO_MEDIO && rc.felpaSeraEstiva(t.attivita)) nStrati = 1;
  if (nStrati) {
    const fresco = tmin == null || tmin <= K.SOGLIA_STRATO_MEDIO;
    richieste.push({ slot: "strato medio per la sera", category: "Upper Body", subCategories: [...K.SOTTOCAT_MEDIO],
      minWaterResistance: 0, frequency: "occasional", n: nStrati, senza_tetto: true,
      minWarmth: fresco ? K.CALORE_MIN_STRATO : 2,
      maxWarmth: fresco ? caloreMaxStrato(tmin) : rc.CALORE_FELPA_ESTIVA,
      reason: `${nome}: minima ${pf(tmin)}, la sera serve un maglione o una felpa` });
  }
  if (!minimoT && interseca(attNorm, K.ATTIVITA_FORMALI)) {
    richieste.push({ slot: "strato formale", category: "Outerwear", subCategories: ["Blazer"], formality: ["Business", "Formal"],
      minWaterResistance: 0, reason: `${nome}: attivita' di lavoro formale, serve un blazer` });
    richieste.push({ slot: "parte inferiore formale", category: "Lower Body", subCategories: ["Trousers", "Skirt"],
      formality: ["Smart Casual", "Business", "Formal"], minWaterResistance: 0, frequency: "occasional",
      reason: `${nome}: attivita' di lavoro formale, servono pantaloni o gonna formali` });
  }
  const tminT = meteo.temp_min_media, tmaxT = meteo.temp_max_media;
  if (tminT != null && tminT <= K.SOGLIA_ESTREMITA) {
    richieste.push({ slot: "testa coperta", category: "Accessory", subCategories: ["Cap/Hat"], minWaterResistance: 0,
      _preferisci_calore: true, reason: `${nome}: minima ${pf(tminT)}, la testa disperde` });
    richieste.push({ slot: "collo e mani", category: "Accessory", subCategories: ["Scarf"], minWaterResistance: 0,
      _preferisci_calore: true, reason: `${nome}: minima ${pf(tminT)}, collo e mani coperti` });
  } else if (tminT != null && pavimentoDi(meteo) >= 4) {
    richieste.push({ slot: "estremita al freddo", category: "Accessory", subCategories: ["Cap/Hat", "Scarf"], minWaterResistance: 0,
      reason: `${nome}: minima ${pf(tminT)}, testa e collo coperti` });
  }
  if (!richieste.some((r) => (get(r, "subCategories", []) as string[]).includes("Cap/Hat")) &&
    ((tmaxT != null && tmaxT >= K.SOGLIA_SOLE) || interseca(attNorm, K.ATTIVITA_ALL_APERTO))) {
    richieste.push({ slot: "protezione dal sole", category: "Accessory", subCategories: ["Cap/Hat", "Sunglasses"],
      minWaterResistance: 0, reason: `${nome}: sole forte o attivita' all'aperto` });
  }
  const tmaxC = meteo.temp_max_media;
  const ciab = insieme(K.SOTTOCAT_CIABATTE);
  if (K.CIABATTE_IN_ACQUA && eAttivitaAcqua(t.attivita || []) && !minimoT && (tmaxC == null || tmaxC >= K.SOGLIA_CALZATURE) &&
    !richieste.some((r) => sottoinsieme(r.subCategories, ciab))) {
    richieste.push({ slot: K.SLOT_CIABATTE, category: "Shoes", subCategories: [...K.SOTTOCAT_CIABATTE], minWaterResistance: 0,
      frequency: "once", reason: `${nome}: attivita' in acqua, ciabatte o sandali` });
  }
  if (interseca(attNorm, K.ATTIVITA_RIVERBERO)) {
    richieste.push({ slot: "occhiali da sole", category: "Accessory", subCategories: ["Sunglasses"], minWaterResistance: 0,
      reason: `${nome}: neve, ghiacciaio o quota, riverbero` });
  }
  if (!minimoT) {
    richieste.push(...slotCapiNuovi(items, meteo.temp_min_media, t.attivita, meteo.giorni_di_pioggia, null,
      [...richieste, ...capi.map((c) => ({ subCategories: [get(c, "subCategory")] }))], nome));
  }
  if (soloTrekking) richieste = richieste.filter((r) => K.SLOT_DEL_TREKKING.has(r.slot));

  const aggiunti: Record_[] = [];
  for (const req of richieste) {
    const subs = insieme(req.subCategories);
    const cov = insieme(req.coverage || []);
    const fm = insieme(req.formality || []);
    const minWr = Math.trunc(Number(req.minWaterResistance || 0));
    const culto = K.SLOT_CULTO.includes(req.slot);
    const tettoReq = vero(req.senza_tetto) ? Math.min(5, Math.trunc(Number(req.maxWarmth || 5))) : ceiling;
    const minW = Math.trunc(Number(req.minWarmth || 0));
    const tagReq = insieme(req.activityTags || []);
    const haTag = (x: any) => {
      if (!tagReq.size) return true;
      const g = capoDi(x);
      return g != null && g.activity_tags.some((tt) => tagReq.has(tt));
    };
    const diRuolo = (x: any) => {
      const g = capoDi(x);
      return g != null && rc.ruoloScarpa(g.sub_category, g.activity_tags, g.warmth, g.formality) === req.ruolo;
    };
    const ok = (x: Record_) => {
      if (vero(req.ruolo) && x.category === "Shoes" && diRuolo(x)) return true;
      return (x.warmth || 0) >= minW && subs.has(x.subCategory) && haTag(x) && (!cov.size || cov.has(x.coverage)) &&
        (!fm.size || fm.has(x.formality)) && (x.waterResistance || 0) >= minWr && !(culto && capoRiservato(x, profiliCapi)) &&
        !(culto && K.CULTO_LEGGERO_IN_TAPPA && rc.cultoLeggero(tmaxTappa) && !capoLeggero(x, profiliCapi));
    };
    const n = Math.trunc(Number(req.n || 1));
    for (let k = 0; k < n; k++) {
      const pool = [...capi, ...aggiunti];
      const giaInTappa = pool.filter((x) => (x.tappe || []).includes(nome) && ok(x));
      if (giaInTappa.length > k) continue;
      const prestabile = pool.filter((x) => ok(x) && !contiene(giaInTappa, x) && (x.warmth || 1) <= tettoReq && !estivoQui(x));
      if (prestabile.length) { prestabile[0].tappe.push(nome); continue; }
      const larghe = new Set([...subs, ...[...subs].flatMap((s) => K.SUBSTITUTIONS[s] ?? [])]);
      const scR = (g: Capo) => score(g, 1, ceiling, new Set(), new Set(), minWr, bulkPress) +
        penalitaCulto(req.slot, g, profiliCapi, rc.cultoLeggero(tmaxTappa));
      const candidati = (p: Set<string>) => items.filter((g) => g.has_metadata && !g.sempre_in_valigia && !used.has(g.id) &&
        p.has(g.sub_category) && (!cov.size || cov.has(g.coverage)) && (!fm.size || fm.has(g.formality)) &&
        (g.water_resistance || 0) >= minWr && (g.warmth || 1) >= minW && (g.warmth || 1) <= tettoReq && !estivoQui(g) &&
        haTag(g) && (!vero(req.ruolo) || diRuolo(g)) && scR(g) <= K.MAX_PENALTY_COMPROMESSO);
      let cands = candidati(subs);
      if (!cands.length) cands = candidati(larghe);
      if (!cands.length) break;
      const g = minimo(cands, scR)!;
      used.add(g.id);
      aggiunti.push({
        slot: req.slot, match: "fabbisogno", imposto: true, category: g.category || req.category,
        slot_category: req.category, item_id: g.id, item: g.name, subCategory: g.sub_category, formality: g.formality,
        coverage: g.coverage, warmth: g.warmth, frequency: get(req, "frequency", "daily"), penalita: round2(scR(g)),
        waterResistance: g.water_resistance, bulk: g.bulk, quantita: 1, essential: true, ideale_mancante: [],
        tappe: [nome], reason: req.reason,
      });
    }
  }
  return aggiunti;
}

export const delTrekking = (r: Record_) =>
  (vero(r.assegnazioni) ? r.assegnazioni : [r]).some((a: Record_) => K.SLOT_DEL_TREKKING.has(a.slot));

export function diversificaCopie(liste: Record_[][], items: Capo[], capienza: number | null = null,
  vietato: ((g: Capo, tappe: string[]) => boolean) | null = null): number {
  if (!K.DIVERSIFICA_COPIE_TAPPE) return 0;
  const inValigia = new Set(liste.flatMap((l) => l.map((x) => get(x, "item_id"))));
  let spostate = 0;
  for (const lista of liste) {
    for (const r of [...lista]) {
      const sub = get(r, "subCategory"), form = get(r, "formality");
      const elegante = vero(r._slot_elegante) || form === "Business" || form === "Formal";
      const morbido = sub === "Swimwear" || (elegante && K.CAPI_DIVERSI_ELEGANTI) ? 1 : tettoMorbidoPer(q(r), form, sub, capienza);
      while (q(r) > morbido) {
        const simili = elegante && (sub === "Trousers" || sub === "Skirt") ? new Set(["Trousers", "Skirt"]) : new Set([sub]);
        const wr = r.warmth || 2;
        const cands = items.filter((g) => g.has_metadata && !g.sempre_in_valigia && !inValigia.has(g.id) &&
          simili.has(g.sub_category) && (!elegante || (g.formality || "Casual") !== "Casual") &&
          Math.abs((g.warmth || 2) - wr) <= 1 && !(vietato && vietato(g, r.tappe || [])) &&
          !(delTrekking(r) && (!(g.activity_tags || []).includes("Hiking") || (g.warmth || 2) > wr)));
        if (!cands.length) break;
        const g = minimo(cands, (x) => Math.abs((x.warmth || 2) - wr))!;
        const nuovo: Record_ = { ...r, item_id: g.id, item: g.name, subCategory: g.sub_category, formality: g.formality,
          coverage: g.coverage, warmth: g.warmth, waterResistance: g.water_resistance, bulk: g.bulk, quantita: 1,
          tappe: [...(r.tappe || [])] };
        delete nuovo.in_partenza;
        delete nuovo.nota_partenza;
        lista.push(nuovo);
        inValigia.add(g.id);
        r.quantita -= 1;
        spostate += 1;
      }
    }
  }
  return spostate;
}

export function contaPezzi(capi: Record_[], giorniPerTappa: Record<string, number>, lavatrice: boolean,
  intensita: string | null = null, tempMaxPerTappa: Record<string, number | null> | null = null,
  giorniMare: number | null = null, minimoEleganti: number | null = null): void {
  const gruppi = new Map<unknown, Record_[]>();
  for (const x of capi) {
    const k = x._gruppo_capo != null ? x._gruppo_capo : x;
    if (!gruppi.has(k)) gruppi.set(k, []);
    gruppi.get(k)!.push(x);
  }
  for (const membri of gruppi.values()) {
    const primo = membri[0];
    const tappeCapo: string[] = primo.tappe || [];
    let gg = Math.max(1, tappeCapo.reduce((s, t) => s + (giorniPerTappa[t] ?? 0), 0));
    let freq = get(primo, "frequency");
    if (freq == null && vero(primo.assegnazioni)) freq = get(primo.assegnazioni[0], "frequency");
    let intens = get(primo, "intensita");
    if (intens == null && vero(primo.assegnazioni)) intens = get(primo.assegnazioni[0], "intensita");
    const intensEff = normIntensita(intens) || intensita;
    const sotto = primo.subCategory || "";
    if (vero(tempMaxPerTappa) && K.SOTTOCAT_DUE_GIORNI_SOTTO_SOGLIA.has(sotto)) {
      gg = Math.max(1, Math.ceil(tappeCapo.reduce((s, t) =>
        s + (giorniPerTappa[t] ?? 0) / (usiSottoSoglia(sotto, tempMaxPerTappa![t], intensEff) ? 2 : 1), 0)));
    }
    const caldi = tappeCapo.filter((t) => vero(tempMaxPerTappa) && tempMaxPerTappa![t] != null).map((t) => tempMaxPerTappa![t]!);
    const caldoCapo = caldi.length ? Math.max(...caldi) : null;
    let serve = quantityFor(sotto, primo.item || "", gg, lavatrice, freq || "daily", intensEff,
      !K.SOTTOCAT_DUE_GIORNI_SOTTO_SOGLIA.has(sotto) ? caldoCapo : null, giorniMare, primo.warmth ?? null);
    if (minimoEleganti && vero(primo._slot_elegante) && ["Upper Body", "Lower Body"].includes(primo.category) &&
      K.FREQ_MINIMO_LAVORO.includes(freq || "daily")) serve = Math.max(serve, minimoEleganti);
    if (membri.some((x) => (vero(x.assegnazioni) ? x.assegnazioni : [x]).some((a: Record_) => a.slot === K.SLOT_SERA_PRESENTABILE))) {
      serve = Math.max(serve, membri.length);
    }
    if (membri.length === 1) { primo.quantita = serve; continue; }
    const [qq] = ripartisciCopie(serve, membri.map((x) =>
      [tettoCopieMorbido(x.formality, x.subCategory), tettoCopie(x.formality, x.subCategory)] as [number, number]));
    membri.forEach((x, i) => { x.quantita = Math.max(qq[i], 0); });
  }
}

export interface ArgomentiTappe {
  sc: Record_;
  geo: Record_;
  bagaglio?: string;
  voti_scarpe?: Record<string, number> | null;
  profili_capi?: Record<string, any> | null;
  scarti_capi?: Record<string, number> | null;
  classi_viaggio?: Record<string, any> | null;
}

export function strategySlotsMultitappa(testoModello: string, items: Capo[], a: ArgomentiTappe): Record_ {
  const sc = a.sc, perTappa: Record_[] = a.geo.per_tappa, bagaglio = a.bagaglio ?? "";
  const profiliCapi = a.profili_capi ?? null;
  segnaCapiDaNeve(items, [...(sc.attivita || []), ...perTappa.flatMap((t) => t.attivita || []),
    ...(sc.legs || []).flatMap((l: Record_) => l.attivita || [])]);
  const nomi: string[] = perTappa.map((t) => t.destinazione);
  const giorniTot = perTappa.reduce((s, t) => s + Math.trunc(Number(t.giorni || 1)), 0);
  const ordinate = ordinaTappe(perTappa);
  const base = ordinate[0];
  let attBase: string[] = [...(sc.attivita || []), ...(base.attivita || [])];
  const trekkingDiTappa = K.SLOT_TREKKING && perTappa.length > 1 && !eTrekking(sc.attivita) && eTrekking(base.attivita);
  if (trekkingDiTappa) attBase = attBase.filter((x) => !eTrekking([x]));
  const attContesto: string[] = [];
  const visti = new Set<string>();
  for (const att of [...(sc.attivita || []), ...perTappa.flatMap((t) => t.attivita || [])]) {
    const n = lws(att);
    if (visti.has(n)) continue;
    visti.add(n);
    attContesto.push(att);
  }
  const capienza = capienzaBagaglio(bagaglio);
  const lavMt = Boolean(get(sc, "lavatrice", false)) ||
    (K.CAMMINO_LAVA_A_MANO && rc.camminoAPiedi(sc.attivita, bagaglio, giorniTot));
  const r = strategySlots(testoModello, items, {
    giorni: giorniTot, lavatrice: lavMt, attivita: attBase, attivita_viaggio: attContesto,
    lavatrice_essenziali: Boolean(get(sc, "lavatrice", false)),
    temp_min: base.meteo.temp_min_media ?? null, temp_max: base.meteo.temp_max_media ?? null, bagaglio,
    giorni_pioggia: base.meteo.giorni_di_pioggia ?? null, intensita: sc.intensita ?? null, voti_scarpe: a.voti_scarpe ?? null,
    temp_min_assoluta: base.meteo.temp_min_assoluta ?? null, profili_capi: profiliCapi, scarti_capi: a.scarti_capi ?? null,
    classi_viaggio: a.classi_viaggio ?? null,
  });
  for (const rec of [...r.ideali, ...r.ripieghi, ...(r.essenziali || [])]) rec.tappe = [...nomi];
  const perId = new Map(items.map((g) => [g.id, g]));
  for (const rec of [...r.ideali, ...r.ripieghi]) {
    const g = perId.get(rec.item_id);
    if (g == null) continue;
    const restano = perTappa.filter((t) => !estivoFuoriStagione(g, t.meteo.temp_max_media, eAttivitaAcqua(t.attivita || []),
      profiliCapi)).map((t) => t.destinazione);
    if (restano.length) rec.tappe = restano;
  }
  for (const gp of r.mancanti || []) gp.tappe = [base.destinazione];
  r.tappa_base = base.destinazione;
  r.tappe = nomi;
  r.giorni_per_tappa = Object.fromEntries(perTappa.map((t) => [t.destinazione, Math.trunc(Number(t.giorni || 1))]));
  const capi: Record_[] = [...r.ideali, ...r.ripieghi];
  const used = new Set<string>(capi.map((x) => x.item_id));
  const bulkPress = capienza <= 30 ? 0.25 : (capienza <= 55 ? 0.12 : 0.0);
  if (trekkingDiTappa) {
    const nuovi = servePerTappa(base, capi, items, used, bulkPress, false, profiliCapi, true);
    r.ripieghi.push(...nuovi);
    capi.push(...nuovi);
  }
  for (const t of ordinate.slice(1)) {
    const nome = t.destinazione, meteo = t.meteo;
    const nuovi = servePerTappa(t, capi, items, used, bulkPress, giorniTot <= 2 || capienza <= 8, profiliCapi);
    r.ripieghi.push(...nuovi);
    capi.push(...nuovi);
    const floor = pavimentoDi(meteo), ceiling = tettoDi(meteo);
    const isoMin = floor >= 5 ? 4 : K.CALORE_ISOLANTE;
    let aggiunti = 0;
    while (caloreEfficace(pilaDiTappa(capi, nome), isoMin) < floor && aggiunti < 2) {
      const pila = pilaDiTappa(capi, nome);
      const gia = capi.filter((x) => !(x.tappe || []).includes(nome) && K.ZONE_STRATIFICABILI.has(x.category) &&
        (x.warmth || 1) <= ceiling && caloreEfficace([...pila, x], isoMin) > caloreEfficace(pila, isoMin));
      if (gia.length) { massimo(gia, (x) => x.warmth || 0)!.tappe.push(nome); aggiunti += 1; continue; }
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
      const rec = {
        slot: `strato per ${nome}`, match: "stratificazione", imposto: true, category: g.category, slot_category: g.category,
        item_id: g.id, item: g.name, subCategory: g.sub_category, formality: g.formality, coverage: g.coverage,
        warmth: g.warmth, frequency: "once", penalita: round2(scStr(g)), waterResistance: g.water_resistance,
        bulk: g.bulk, quantita: 1, essential: true, ideale_mancante: [], tappe: [nome],
        reason: `${nome}: la pila arriva a ${caloreEfficace(pila, isoMin).toFixed(1)}, serve ${floor}`,
      };
      r.ripieghi.push(rec);
      capi.push(rec);
      aggiunti += 1;
    }
    if (caloreEfficace(pilaDiTappa(capi, nome), isoMin) < floor) {
      const posseduti = items.filter((g) => g.has_metadata && g.category === "Outerwear");
      const gap: Record_ = {
        slot: `strato caldo mancante a ${nome}`, category: "Outerwear", essential: true, imposto: false, tappe: [nome],
        subCategories: ["Coat", "Down Jacket"], warmth_richiesto: [isoMin, Math.max(isoMin, ceiling)],
        reason: `${nome}: la pila arriva a ${caloreEfficace(pilaDiTappa(capi, nome), isoMin).toFixed(1)}, serve ${floor}`,
      };
      if (posseduti.length) {
        const m = massimo(posseduti, (g) => [g.warmth || 0, g.sub_category === "Coat" || g.sub_category === "Down Jacket"])!;
        Object.assign(gap, { tipo: "posseduto_ma_inadatto", candidato_scartato: m.name, candidato_warmth: m.warmth,
          impermeabilita_richiesta: 0, candidato_wr: m.water_resistance });
      } else gap.tipo = "assente";
      r.mancanti.push(gap);
    }
  }
  [r.ideali, r.ripieghi] = consolidaBloccoViaggio(r.ideali, r.ripieghi);
  contaPezzi([...r.ideali, ...r.ripieghi], r.giorni_per_tappa, lavMt, sc.intensita ?? null,
    Object.fromEntries(perTappa.map((t) => [t.destinazione, t.meteo.temp_max_media ?? null])),
    perTappa.reduce((s, t) => s + giorniDiMare(t.giorni || 0, t.attivita), 0),
    (giorniTot >= 2 && capienza > 8 && viaggioDiLavoro(perTappa.flatMap((t) => t.attivita || []), a.classi_viaggio ?? null))
      ? K.MINIMO_FORMALI_LAVORO : null);
  const climaTappe = new Map<string, [number | null, boolean]>(perTappa.map((t) =>
    [t.destinazione, [t.meteo.temp_max_media ?? null, eAttivitaAcqua(t.attivita || [])]]));
  diversificaCopie([r.ideali, r.ripieghi], items, capienza, (g, tappe) =>
    tappe.some((t) => climaTappe.has(t) && estivoFuoriStagione(g, climaTappe.get(t)![0], climaTappe.get(t)![1], profiliCapi)));
  const minime = perTappa.map((t) => t.meteo.temp_min_media).filter((x) => x != null);
  const tempMinMin = minime.length ? Math.min(...minime) : null;
  togliDoppioni([...r.ideali, ...r.ripieghi], items, giorniTot, tempMinMin);
  r.ideali = r.ideali.filter((x: Record_) => q(x) >= 1);
  r.ripieghi = r.ripieghi.filter((x: Record_) => q(x) >= 1);
  applicaBudgetRotazione([...r.ideali, ...r.ripieghi], giorniTot,
    minimoCapiLeggeri(perTappa.map((t) => [Math.trunc(Number(t.giorni || 1)), t.meteo.temp_max_media ?? null]), lavMt),
    perTappa.map((t) => [Math.trunc(Number(t.giorni || 1)), t.meteo.temp_max_media ?? null, t.meteo.temp_min_media ?? null]),
    lavMt);
  r.ideali = r.ideali.filter((x: Record_) => q(x) >= 1);
  r.ripieghi = r.ripieghi.filter((x: Record_) => q(x) >= 1);
  applicaTettoVolume([...r.ideali, ...r.ripieghi], capienzaPotabile(get(sc, "bagaglio", "")));
  r.mancanti = r.mancanti.filter((g: Record_) => g.tipo !== "volume_eccedente");
  const avvisoVolume = segnalaVolume([...r.ideali, ...r.ripieghi], capienzaPotabile(get(sc, "bagaglio", "")));
  if (avvisoVolume) r.mancanti.push(avvisoVolume);
  r.mancanti = r.mancanti.filter((g: Record_) => g.slot !== K.SLOT_SCARPE_CAMMINO);
  const avvisoScarpe = segnalaScarpeCammino([...r.ideali, ...r.ripieghi], items, perTappa.flatMap((t) => t.attivita || []));
  if (avvisoScarpe) r.mancanti.push(avvisoScarpe);
  berrettoColFreddo([...r.ideali, ...r.ripieghi], items, tempMinMin);
  segnaInPartenza([...r.ideali, ...r.ripieghi]);
  r.mancanti_canonici = canonicalizeGaps(r.mancanti);
  return r;
}
