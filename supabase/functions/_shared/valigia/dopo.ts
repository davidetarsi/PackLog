// Punteggio dei capi, lacune e rifinitura della valigia dopo la scelta: tetti
// per zona, doppioni, volume, scarpe in partenza, unione delle righe dello
// stesso capo. Porting di packlog_checklist_bench_48.py (stessi nomi in
// snake_case nei commenti, per ritrovarli nel bench).
import * as K from "./costanti.ts";
import * as rc from "./regole_capi.ts";
import type { Capo } from "./capo.ts";
import { massimo, ordina, senzaAccenti, vero } from "./py.ts";
import type { Record_ } from "./inject.ts";

const q = (x: Record_) => x.quantita ?? 1;
const nn = <T>(x: T | undefined) => (x === undefined ? null : x);

// ── calore_efficace ─────────────────────────────────────────────────────────
export function caloreEfficace(capi: Record_[], isolanteMinimo: number = K.CALORE_ISOLANTE): number {
  const perRuolo = new Map<string, number>();
  for (const x of capi) {
    const w = x.warmth || 0;
    if (w < 1) continue;
    const ruolo = K.RUOLO_STRATO[x.subCategory || ""] ?? "base";
    perRuolo.set(ruolo, Math.max(perRuolo.get(ruolo) ?? 0, w));
  }
  if (!perRuolo.size) return 0.0;
  const pesi = [...perRuolo.values()].sort((a, b) => a - b);
  const aggiuntivi = pesi.slice(0, -1).filter((w) => w >= 2).length;
  const eff = Math.min(5.0, pesi[pesi.length - 1] + K.BONUS_STRATO * aggiuntivi);
  const isolante = capi.some((x) => (x.warmth || 0) >= isolanteMinimo && x.category === "Outerwear");
  return isolante ? eff : Math.min(eff, K.TETTO_PILA_SENZA_ISOLANTE);
}

// ── Penalita' e punteggio ───────────────────────────────────────────────────
export function penalitaVetoCapo(voti: Record<string, number> | null | undefined, g: Capo): number {
  if (!vero(voti) || !(g.id in voti!)) return 0.0;
  return K.PESO_VOTO_CAPI * Math.max(0.0, K.SOGLIA_VOTO_CAPI - voti![g.id]) / Math.max(K.SOGLIA_VOTO_CAPI, 1e-9);
}

export function penalitaVoto(voti: Record<string, number> | null | undefined, g: Capo): number {
  if (!vero(voti) || !(g.id in voti!)) return 0.0;
  return K.PESO_VOTO_SCARPE * (Math.max(...Object.values(voti!)) - voti![g.id]);
}

export function score(g: Capo, lo: number, hi: number, forms: Set<string>, tags: Set<string>,
  minWr = 0, bulkPress = 0.0): number {
  let pen = 0.0;
  if (g.solo_neve && !(minWr >= 2 && (g.water_resistance || 0) >= 2)) pen += K.PENALITA_NEVE_FUORI;
  const w = g.warmth != null ? g.warmth : 3;
  if (w < lo) pen += (lo - w) * 1.0;
  else if (w > hi) pen += (w - hi) * 1.2;
  if (forms.size && g.formality && !forms.has(g.formality)) pen += 1.0;
  if (tags.size) {
    const overlap = new Set(g.activity_tags.filter((t) => tags.has(t)));
    if (!overlap.size) pen += 0.8;
    else pen -= 0.15 * overlap.size / Math.max(1, g.activity_tags.length);
  }
  if (minWr) {
    const wr = g.water_resistance;
    if (wr == null) pen += 0.5;
    else if (wr < minWr) pen += (minWr - wr) * 1.5;
  }
  if (bulkPress && g.bulk) pen += bulkPress * (g.bulk - 1);
  return pen;
}

// ── Lacune ──────────────────────────────────────────────────────────────────
const FONTI_GAP_NECESSARI = new Set(["sistema", "meteo", "quantita", "essenziale_deterministico"]);

export function fontePrioritaGap(gap: Record_): [string, string] {
  const tipo = gap.tipo;
  let fonte = gap.fonte;
  if (!vero(fonte)) {
    if (tipo === "promemoria_non_inventariato") fonte = "essenziale_deterministico";
    else if (tipo === "quantita_insufficiente") fonte = "quantita";
    else if (vero(gap.imposto)) fonte = "sistema";
    else if (senzaAccenti(String(gap.slot || "").toLowerCase()).startsWith("strato caldo mancante")) fonte = "meteo";
    else fonte = "llm";
  }
  const priorita = vero(gap.priorita) ? gap.priorita : (FONTI_GAP_NECESSARI.has(fonte) ? "necessario" : "consigliato");
  return [fonte, priorita];
}

export function intervalloGap(gap: Record_): [number, number] | null {
  const v = gap.warmth_richiesto;
  if (!Array.isArray(v) || v.length !== 2) return null;
  if (v[0] == null || v[1] == null) return null;
  return [Math.trunc(v[0]), Math.trunc(v[1])];
}

export function canonicalGapKey(gap: Record_): unknown[] {
  const [fonte] = fontePrioritaGap(gap);
  const tipo = gap.tipo || "assente";
  const categoria = gap.requiredCategory || gap.category || "";
  const sottocategorie = [...new Set<string>(gap.requiredSubcategories || gap.subCategories || [])].sort();
  const intervallo = intervalloGap(gap);
  const impermeabilita = gap.requiredWaterResistance != null ? gap.requiredWaterResistance : nn(gap.impermeabilita_richiesta);
  const funzione = nn(gap.funzione);
  let quantita: unknown[] = [];
  if (tipo === "quantita_insufficiente") {
    quantita = [nn(gap.usi_richiesti), nn(gap.usi_coperti), nn(gap.capi_diversi_necessari)];
  }
  return [tipo, fonte, categoria, funzione, sottocategorie, intervallo, impermeabilita, quantita];
}

/** json.dumps di Python con i separatori di default (", " e ": "). */
export function pyDumps(v: unknown): string {
  if (v == null) return "null";
  if (Array.isArray(v)) return "[" + v.map(pyDumps).join(", ") + "]";
  if (typeof v === "object") {
    return "{" + Object.entries(v as object).map(([k, x]) => JSON.stringify(k) + ": " + pyDumps(x)).join(", ") + "}";
  }
  return JSON.stringify(v);
}

export function canonicalizeGaps(gaps: Record_[]): Record_[] {
  const gruppi: [string, Record_][] = [];
  for (const originale of gaps) {
    const gap = structuredClone(originale);
    const [fonte, priorita] = fontePrioritaGap(gap);
    gap.fonte = fonte;
    gap.priorita = priorita;
    const chiave = canonicalGapKey(gap);
    const base = JSON.stringify([...chiave.slice(0, 5), ...chiave.slice(6)]);
    let corrente: Record_ | null = null;
    for (const [baseEsistente, candidato] of gruppi) {
      if (baseEsistente !== base) continue;
      const s = intervalloGap(candidato), d = intervalloGap(gap);
      if (s && d && Math.max(s[0], d[0]) > Math.min(s[1], d[1])) continue;
      corrente = candidato;
      break;
    }
    if (corrente == null) { gruppi.push([base, gap]); continue; }
    for (const campo of ["subCategories", "requiredSubcategories", "tappe"]) {
      const valori = new Set<string>([...(corrente[campo] || []), ...(gap[campo] || [])]);
      if (valori.size) corrente[campo] = [...valori].sort();
    }
    const s = intervalloGap(corrente), d = intervalloGap(gap);
    if (s && d) corrente.warmth_richiesto = [Math.max(s[0], d[0]), Math.min(s[1], d[1])];
    else if (d && !s) corrente.warmth_richiesto = [...d];
    if (gap.priorita === "necessario") corrente.priorita = "necessario";
  }
  return ordina(gruppi.map(([, g]) => g), (g) => pyDumps(canonicalGapKey(g)));
}

// ── Tetti per zona ──────────────────────────────────────────────────────────
export function slotDi(capo: Record_): Set<string> {
  return new Set((capo.assegnazioni ?? []).map((a: Record_) => a.slot));
}

export function intoccabile(capo: Record_): boolean {
  return vero(capo.imposto) || vero(capo._slot_elegante) ||
    (capo.assegnazioni ?? []).some((a: Record_) => vero(a.imposto) || K.SLOT_DEL_TREKKING.has(a.slot));
}

export function minimoCapiLeggeri(tappe: [number, number | null][], lavatrice: boolean): number | null {
  if (!K.UN_CAPO_LEGGERO_AL_GIORNO) return null;
  const caldi = tappe.reduce((s, [g, tmax]) => s + (rc.caldoUnCapoAlGiorno(tmax) ? g : 0), 0);
  return caldi ? rc.capiLeggeriColCaldo(caldi, lavatrice) : null;
}

export function applicaBudgetRotazione(capi: Record_[], giorni: number, minimoSopra: number | null = null,
  climaTappe: [number, number | null, number | null][] | null = null, lavatrice = false): number {
  let tagliati = 0;
  for (const zona of ["Upper Body", "Lower Body"]) {
    const inZona = capi.filter((x) => x.category === zona && x.subCategory !== "Swimwear" &&
      !K.SOTTO_STRATI.has(x.subCategory) && (K.RUOLO_STRATO[x.subCategory || ""] ?? "base") === "base");
    let totale = inZona.reduce((s, x) => s + q(x), 0);
    let limite = Math.min(giorni + 1, K.TETTO_ROTAZIONE_ZONA[zona] ?? 99);
    if (zona === "Lower Body" && K.PANTALONI_PER_CLIMA && vero(climaTappe)) {
      limite = Math.min(giorni + 1, rc.pantaloniPerClima(climaTappe!, lavatrice));
    }
    if (zona === "Upper Body" && minimoSopra) limite = Math.max(limite, minimoSopra);
    while (totale > limite) {
      const piuAlto = massimo(inZona, (x) => q(x))!;
      if (q(piuAlto) <= 1) break;
      piuAlto.quantita -= 1;
      totale -= 1;
      tagliati += 1;
    }
    while (K.TOGLI_CAPI_DIVERSI_ZONA && totale > limite) {
      const vivi = inZona.filter((x) => q(x) >= 1);
      const perSlot = new Map<string, number>();
      for (const x of vivi) for (const s of slotDi(x)) perSlot.set(s, (perSlot.get(s) ?? 0) + 1);
      const candidati = vivi.filter((x) => !intoccabile(x) && slotDi(x).size &&
        [...slotDi(x)].every((s) => (perSlot.get(s) ?? 0) >= 2));
      if (!candidati.length) break;
      const fuori = massimo([...candidati].reverse(), (x) => Math.max(...[...slotDi(x)].map((s) => perSlot.get(s) ?? 0)))!;
      totale -= q(fuori);
      tagliati += q(fuori);
      fuori.quantita = 0;
    }
  }
  return tagliati;
}

export function capienzaBagaglio(descrizione: string | null | undefined): number {
  const low = (descrizione || "").toLowerCase();
  for (const [chiave, cap] of K.CAPIENZA) if (low.includes(chiave)) return cap;
  return 60;
}

export function capienzaPotabile(descrizione: string): number | null {
  const c = capienzaBagaglio(descrizione);
  return c && c <= 30 ? c : null;
}

export function volumeInBagaglio(capi: Record_[]): number {
  const bulk = (x: Record_) => x.bulk || 1;
  let volume = capi.reduce((s, x) => s + bulk(x) * q(x), 0);
  for (const cat of ["Shoes", "Outerwear"]) {
    const pezzi = capi.filter((x) => x.category === cat && q(x) >= 1).map(bulk);
    if (pezzi.length) volume -= Math.max(...pezzi);
  }
  return volume;
}

export function segnaInPartenza(capi: Record_[]): Record_ | null {
  const scarpe = capi.filter((x) => x.category === "Shoes" && q(x) >= 1);
  for (const x of capi) { delete x.in_partenza; delete x.nota_partenza; }
  if (!scarpe.length) return null;
  const scelto = massimo(scarpe, (x) => x.bulk || 1)!;
  scelto.in_partenza = true;
  scelto.nota_partenza = K.NOTA_PARTENZA;
  return scelto;
}

export function estivoFuoriStagione(g: Capo, tempMax: number | null | undefined, inAcqua = false,
  profili: Record<string, any> | null = null): boolean {
  if (!K.ESTIVI_FUORI_STAGIONE) return false;
  const caldo = ((profili || {})[g.id] || {}).caldo_torrido;
  return rc.estivoVietato(g.name, g.category, g.sub_category, g.warmth, g.activity_tags, tempMax, inAcqua, caldo);
}

export function segnalaScarpeCammino(capi: Record_[], items: Capo[], attivita: (string | null)[] | null): Record_ | null {
  if (!K.SEGNALA_SCARPE_CAMMINO) return null;
  if (!(attivita ?? []).some((a) => K.RADICI_CAMMINO.some((r: string) => (a || "").toLowerCase().includes(r)))) return null;
  if (capi.some((x) => x.category === "Shoes" && K.SOTTOCAT_SCARPE_CAMMINO.includes(x.subCategory) && q(x) >= 1)) return null;
  const possedute = [...new Set(items.filter((g) => g.has_metadata && g.category === "Shoes" &&
    K.SOTTOCAT_SCARPE_CAMMINO.includes(g.sub_category)).map((g) => g.sub_category))].sort();
  return {
    slot: K.SLOT_SCARPE_CAMMINO, category: "Shoes", essential: false, imposto: true,
    tipo: possedute.length ? "posseduto_ma_inadatto" : "assente",
    subCategories: possedute.length ? possedute : ["Sneakers"],
    reason: possedute.length
      ? "si cammina molto: le tue scarpe chiuse da cammino non sono adatte a questo clima"
      : "si cammina molto: nell'armadio manca una scarpa chiusa comoda, come una sneaker",
  };
}

// ── Doppioni ────────────────────────────────────────────────────────────────
export function rangoCapo(x: Record_): number[] {
  const ass = vero(x.assegnazioni) ? x.assegnazioni : [x];
  return [ass.some((a: Record_) => a.match === "ideale") ? 0 : 1,
    ass.some((a: Record_) => vero(a.imposto)) ? 0 : 1,
    -(x.warmth || 0)];
}

export function togliDoppioni(capi: Record_[], items: Capo[], giorni: number | null = null,
  tempMin: number | null = null): number {
  if (!K.TETTO_DOPPIONI) return 0;
  let vivi = capi.filter((x) => q(x) >= 1);
  let tolti = 0;
  if (K.CAPISPALLA_PER_RUOLO) {
    const perRuoloG = new Map<string, Record_[]>();
    for (const x of vivi) {
      if (x.category !== "Outerwear") continue;
      const r = rc.ruoloCapospalla(x.subCategory, x.formality, x.warmth);
      if (r) { if (!perRuoloG.has(r)) perRuoloG.set(r, []); perRuoloG.get(r)!.push(x); }
    }
    const giaccheV = [...perRuoloG.values()].flat();
    let asciutta: Record_ | null = giaccheV.length ? massimo(giaccheV, (x) => x.waterResistance || 0)! : null;
    if (asciutta != null && (asciutta.waterResistance || 0) < 1) asciutta = null;
    for (const gruppo of perRuoloG.values()) {
      const ordinati = ordina(gruppo, (x) => [-(x.warmth || 0), ...rangoCapo(x)]);
      for (const x of ordinati.slice(1)) {
        if (x === asciutta && (ordinati[0].waterResistance || 0) < 1) continue;
        x.quantita = 0;
        tolti += 1;
      }
    }
    vivi = vivi.filter((x) => q(x) >= 1);
  }
  if (K.TETTO_STRATI_MEDI && giorni != null) {
    const tetto = rc.stratiMediMassimi(giorni, tempMin);
    const strati = vivi.filter((x) => x.category === "Upper Body" && rc.SOTTOCAT_STRATI_MEDI.has(x.subCategory));
    let totale = strati.reduce((s, x) => s + q(x), 0);
    for (const x of ordina(strati, (x) => -q(x))) {
      while (totale > tetto && q(x) > 1) { x.quantita -= 1; totale -= 1; tolti += 1; }
    }
    if (totale > tetto && strati.length) {
      const piuCaldo = massimo(strati, (x) => x.warmth || 0);
      for (const x of ordina(strati, rangoCapo, true)) {
        if (totale <= tetto) break;
        if (x === piuCaldo) continue;
        totale -= q(x);
        x.quantita = 0;
        tolti += 1;
      }
    }
    vivi = vivi.filter((x) => q(x) >= 1);
  }
  const giacche = vivi.filter((x) => rc.contaComeCapospalla(x.category, x.subCategory, x.formality));
  if (giacche.length > rc.MAX_CAPISPALLA) {
    const ordinate = ordina(giacche, rangoCapo);
    const tieni = [massimo(ordinate, (x) => x.warmth || 0)!];
    const asciutta = massimo(ordinate, (x) => x.waterResistance || 0)!;
    if ((asciutta.waterResistance || 0) >= 1 && asciutta !== tieni[0]) tieni.push(asciutta);
    for (const x of ordinate) {
      if (tieni.length >= rc.MAX_CAPISPALLA) break;
      if (!tieni.includes(x)) tieni.push(x);
    }
    for (const x of giacche) if (!tieni.includes(x)) { x.quantita = 0; tolti += 1; }
  }
  const perId = new Map(items.map((g) => [g.id, g]));
  const perRuolo = new Map<string, Record_[]>();
  for (const x of vivi) {
    if (x.category !== "Shoes") continue;
    const g = perId.get(x.item_id);
    const ruolo = rc.ruoloScarpa(x.subCategory, g ? g.activity_tags : [], x.warmth, x.formality);
    if (!perRuolo.has(ruolo)) perRuolo.set(ruolo, []);
    perRuolo.get(ruolo)!.push(x);
  }
  for (const gruppo of perRuolo.values()) {
    for (const x of ordina(gruppo, rangoCapo).slice(1)) { x.quantita = 0; tolti += 1; }
  }
  return tolti;
}

export function berrettoColFreddo(capi: Record_[], items: Capo[], tempMin: number | null | undefined): boolean {
  if (!K.BERRETTO_COL_FREDDO || tempMin == null || tempMin > K.SOGLIA_ESTREMITA) return false;
  const cappelli = capi.filter((x) => x.subCategory === "Cap/Hat" && q(x) >= 1);
  if (!cappelli.length || cappelli.some((x) => (x.warmth || 1) >= 3)) return false;
  const inValigia = new Set(capi.map((x) => x.item_id));
  const caldi = ordina(items.filter((g) => g.has_metadata && g.sub_category === "Cap/Hat" &&
    (g.warmth || 1) >= 3 && !inValigia.has(g.id)), (g) => -(g.warmth || 0));
  if (!caldi.length) return false;
  const g = caldi[0];
  Object.assign(cappelli[0], { item_id: g.id, item: g.name, warmth: g.warmth, formality: g.formality,
    bulk: g.bulk, waterResistance: g.water_resistance });
  return true;
}

export function segnalaVolume(capi: Record_[], capienza: number | null | undefined): Record_ | null {
  if (!capienza) return null;
  const bulk = (x: Record_) => x.bulk || 1;
  const volume = volumeInBagaglio(capi);
  if (volume <= capienza) return null;
  const candidati = ordina(capi.filter((x) => !(x.assegnazioni ?? []).some((a: Record_) => vero(a.imposto)) &&
    x.category !== "Shoes" && x.category !== "Outerwear"), (x) => -bulk(x));
  return {
    slot: "volume del bagaglio", tipo: "volume_eccedente", category: "", essential: false, imposto: true,
    capienza, volume, da_valutare: candidati.slice(0, 3).map((x) => nn(x.item)),
    reason: `la valigia occupa ${volume} punti, il bagaglio ne regge ${capienza}: valuta di lasciare a casa uno di questi capi`,
  };
}

export function applicaTettoVolume(capi: Record_[], capienza: number | null | undefined): number {
  if (!capienza) return 0;
  const bulk = (x: Record_) => x.bulk || 1;
  const imposto = (x: Record_) => (x.assegnazioni ?? []).some((a: Record_) => vero(a.imposto));
  let volume = volumeInBagaglio(capi);
  const potabili = capi.filter((x) => !imposto(x));
  let tagliati = 0;
  while (volume > capienza) {
    const candidati = potabili.filter((x) => q(x) > 1);
    if (!candidati.length) break;
    const scelto = massimo(candidati, (x) => [bulk(x), q(x)])!;
    scelto.quantita -= 1;
    volume -= bulk(scelto);
    tagliati += 1;
  }
  return tagliati;
}

// ── Unione delle righe dello stesso capo ────────────────────────────────────
const METADATA_FIELDS = ["category", "subCategory", "warmth", "bulk", "waterResistance", "formality", "coverage"];

export function consolidaCapiFisici(capi: Record_[]): Record_[] {
  const groups = new Map<unknown, Record_[]>();
  for (const record of capi) {
    const id = record.item_id;
    const k = vero(id) ? id : null;
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k)!.push(record);
  }
  const result: Record_[] = [];
  for (const [key, recs] of groups) {
    if (key == null) { result.push(...recs); continue; }
    const first = recs[0];
    for (const f of METADATA_FIELDS) {
      for (const r of recs.slice(1)) {
        if (JSON.stringify(nn(r[f])) !== JSON.stringify(nn(first[f]))) {
          throw new Error(`item_id ${key}: campo ${f} incompatibile fra assegnazioni`);
        }
      }
    }
    const merged: Record_ = {};
    for (const f of [...METADATA_FIELDS, "item_id", "item"]) if (f in first) merged[f] = first[f];
    const assegnazioni: Record_[] = [];
    for (const r of recs) {
      if ("assegnazioni" in r) { assegnazioni.push(...r.assegnazioni); continue; }
      const e: Record_ = {};
      for (const f of K.CAMPI_ASSEGNAZIONE) if (f in r) e[f] = r[f];
      assegnazioni.push(e);
    }
    merged.assegnazioni = assegnazioni;
    const viste = new Set<unknown>();
    const tappe: unknown[] = [];
    for (const r of recs) {
      const t = "tappe" in r ? r.tappe : [];
      if (Array.isArray(t)) for (const x of t) if (!viste.has(x)) { viste.add(x); tappe.push(x); }
    }
    if (tappe.length) merged.tappe = tappe;
    merged.quantita = Math.max(...recs.map(q));
    if (recs.some((r) => vero(r._slot_elegante))) merged._slot_elegante = true;
    const gruppi = new Set(recs.filter((r) => "_gruppo_capo" in r).map((r) => r._gruppo_capo));
    if (gruppi.size === 1) merged._gruppo_capo = [...gruppi][0];
    result.push(merged);
  }
  return result;
}

export function consolidaBloccoViaggio(ideali: Record_[], ripieghi: Record_[]): [Record_[], Record_[]] {
  const out: [Record_[], Record_[]] = [[], []];
  for (const r of consolidaCapiFisici([...ideali, ...ripieghi])) {
    const ideale = "assegnazioni" in r
      ? (r.assegnazioni ?? []).some((a: Record_) => a.match === "ideale")
      : r.match === "ideale";
    (ideale ? out[0] : out[1]).push(r);
  }
  return out;
}

// ── Vestiti (Davide, 19 ottobre, armadio femminile) ─────────────────────────
// Un vestito vale una T-shirt e un pantalone di lino, al massimo una camicia e
// un pantalone eleganti. Col caldo uno ogni 3 giorni, fino a 3; col fresco solo
// un vestito caldo, al massimo uno. Un vestito elegante vale il capo
// presentabile per la sera; l'abito da cerimonia vale il completo.

function recVestito(g: Capo, slot: string, reason: string, tappe: string[] | null): Record_ {
  const r: Record_ = {
    category: g.category, subCategory: g.sub_category, warmth: g.warmth, bulk: g.bulk,
    waterResistance: g.water_resistance, formality: g.formality, coverage: g.coverage,
    item_id: g.id, item: g.name,
    assegnazioni: [{ slot, match: "ideale", reason, imposto: true, quantita: 1, frequency: "occasional", intensita: null }],
    quantita: 1,
  };
  if (tappe != null) r.tappe = [...tappe];
  return r;
}

/** Una copia in meno al capo adatto con piu' copie, mai l'ultima della zona. */
function togliUnaCopia(capi: Record_[], adatto: (x: Record_) => boolean): Record_ | null {
  const vivi = capi.filter((x) => adatto(x) && (x.quantita ?? 1) >= 1);
  if (vivi.reduce((n, x) => n + (x.quantita ?? 1), 0) <= 1) return null;
  const candidati = vivi.filter((x) => !intoccabile(x));
  if (!candidati.length) return null;
  const x = massimo(candidati, (x) => x.quantita ?? 1)!;
  x.quantita = (x.quantita ?? 1) - 1;
  return x;
}

const contiene = (a: Set<string>, b: Set<string>) => [...a].some((x) => b.has(x));

/** I vestiti dell'armadio al posto di altri capi: restituisce i record nuovi, le
 *  copie sostituite scendono (a zero: chi chiama le toglie). */
export function applicaVestiti(capi: Record_[], items: Capo[], giorni: number, tempMax: number | null | undefined,
  attivita: string[] | null | undefined, tappe: string[] | null = null, capienza: number | null = null): Record_[] {
  const inValigia = new Set(capi.map((x) => x.item_id));
  const culto = capi.some((x) => contiene(slotDi(x), K.SLOT_CULTO_VESTITI));
  const vestiti = items.filter((g) => g.has_metadata && g.sub_fine === "Dress" && !inValigia.has(g.id)
    && !(culto && g.coverage === "Sleeveless"));
  if (!K.VESTITI || !vestiti.length || tempMax == null || (capienza != null && capienza <= 8)) return [];
  const perId = new Map(items.map((g) => [g.id, g]));
  const tecnico = (x: Record_) => {
    const g = perId.get(x.item_id);
    return !!g && g.activity_tags.includes("Hiking") && !g.activity_tags.includes("Everyday");
  };
  const caldo = tempMax > K.SOGLIA_VESTITO_CALDO;
  const climaOk = caldo ? (g: Capo) => (g.warmth || 1) <= 2 : (g: Capo) => (g.warmth || 0) >= K.CALORE_VESTITO_FRESCO;
  const presi = new Set<string>();
  const prendi = (formalita: string[], colClima = true): Capo | null => {
    for (const f of formalita) {
      for (const g of vestiti) {
        if (!presi.has(g.id) && g.formality === f && (!colClima || climaOk(g))) {
          presi.add(g.id);
          return g;
        }
      }
    }
    return null;
  };
  const nuovi: Record_[] = [];
  // l'abito da cerimonia vale il completo
  if (rc.ha(attivita ?? [], [...K.RADICI_CERIMONIA])) {
    const g = prendi(["Formal"], false);
    if (g) {
      const completo = capi.filter((x) => { const s = slotDi(x); return s.size > 0 && [...s].every((v) => K.SLOT_COMPLETO.has(v)) && (x.quantita ?? 1) >= 1; });
      if (!completo.length) {
        for (const zona of ["Upper Body", "Lower Body"]) {
          const eleganti = capi.filter((x) => x.category === zona && (x.formality === "Business" || x.formality === "Formal")
            && (x.quantita ?? 1) >= 1);
          if (eleganti.length) completo.push(massimo(eleganti, (x) => x.quantita ?? 1)!);
        }
      }
      for (const x of completo) x.quantita = (x.quantita ?? 1) - 1;
      nuovi.push(recVestito(g, K.SLOT_ABITO_CERIMONIA, "occasione formale: vale il completo", tappe));
    }
  }
  // un vestito elegante vale un capo presentabile per la sera (solo un capo della sola sera)
  const sera = capi.filter((x) => { const s = slotDi(x); return s.size === 1 && s.has(K.SLOT_SERA_PRESENTABILE)
    && (x.quantita ?? 1) >= 1 && (x.category === "Upper Body" || x.category === "Lower Body"); });
  if (sera.length) {
    const x = massimo(sera, (x) => x.quantita ?? 1)!;
    const scala: string[] = [...K.FORMALITA_VESTITO_SERA];
    const rango = scala.includes(x.formality) ? scala.indexOf(x.formality) : 0;
    const g = prendi(scala.slice(rango));
    if (g) {
      x.quantita = (x.quantita ?? 1) - 1;
      nuovi.push(recVestito(g, K.SLOT_SERA_PRESENTABILE, "per la sera: vale un capo presentabile", tappe));
    }
  }
  // di giorno: ognuno al posto di un capo sopra leggero e di uno sotto
  const quanti = Math.min(caldo ? K.MAX_VESTITI : 1, Math.floor(giorni / K.GIORNI_PER_VESTITO));
  const libero = (x: Record_) => !tecnico(x) && !contiene(slotDi(x), K.SLOT_CULTO_VESTITI);
  const sopra = (x: Record_) => x.category === "Upper Body" && K.SOPRA_DA_VESTITO.has(x.subCategory) && libero(x);
  const sotto = (x: Record_) => x.category === "Lower Body" && !K.SOTTO_STRATI.has(x.subCategory)
    && x.subCategory !== "Swimwear" && x.formality !== "Business" && x.formality !== "Formal" && libero(x);
  for (let i = 0; i < quanti; i++) {
    const g = prendi([...K.FORMALITA_VESTITO_GIORNO]);
    if (!g) break;
    const su = togliUnaCopia(capi, sopra);
    if (!su) break;
    const giu = togliUnaCopia(capi, sotto);
    if (!giu) { su.quantita += 1; break; }
    nuovi.push(recVestito(g, K.SLOT_VESTITO, "un vestito al posto di un capo sopra e uno sotto", tappe));
  }
  return nuovi;
}
