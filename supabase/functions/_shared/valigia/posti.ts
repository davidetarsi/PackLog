// I posti della valigia dai mancanti del generatore: quanto e' importante un posto e come
// si chiama. Non tocca la scelta dei capi ne' gli avvisi (uscita.ts): e' un livello in piu'.
import type { Lingua } from "../lingua.ts";
import * as K from "./costanti.ts";
import { caricaArmadio, type Capo as CapoArmadio } from "./capo.ts";
import { lavanderiaPresunta } from "./dopo.ts";
import { vero } from "./py.ts";
import { essenzialiPerViaggio, quantityFor, RADICI_NOTTE } from "./quantita.ts";
import { attivitaPer, calore, capiUniti, capoDelGap, CODICE_LAVANDERIA, copyMancante, frasePochi, freddoPer, lavanderiaDelViaggio,
  meteoDelGap, perQuestoArmadio, soloElegante, tettoSalvate } from "./uscita.ts";
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
  /** `${tipo}:${indice}`, indice nell'elenco finale. */
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

/** Giorni e lavatrice delle quantita', come li usa il generatore: a tappe la somma dei giorni
 *  delle tappe; in un posto solo i giorni di GIORNI_LAVANDERIA quando conta su un bucato. */
function giorniDelViaggio(v: Record<string, any> | null | undefined, meteo: Record<string, any> | null | undefined):
  { giorni: number; lavatrice: boolean } {
  const lavatrice = vero(v?.lavatrice);
  const tappe: Record<string, any>[] = Array.isArray(v?.tappe) ? v!.tappe : [];
  if (tappe.length) return { giorni: tappe.reduce((n, t) => n + Math.trunc(Number(t.giorni || 1)), 0), lavatrice };
  const giorni = Math.trunc(Number(v?.giorni ?? meteo?.giorni)) || 1;
  return { giorni: lavanderiaPresunta(giorni, v?.lavatrice) ? K.GIORNI_LAVANDERIA : giorni, lavatrice };
}

/** Le copie di un mancante: i capi diversi che mancano per una quantita' insufficiente, uno per
 *  giacche, scarpe e accessori, altrimenti la quantita' che il generatore darebbe allo slot. */
function copieDelMancante(g: Record<string, any>, sub: string | null, frequenza: string, giorni: number,
  lavatrice: boolean): number {
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
    copie = quantityFor(sub ?? "", "", giorni, lavatrice, frequenza);
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
  const { giorni, lavatrice } = giorniDelViaggio(viaggio, meteo);
  const grezzi: Grezzo[] = [];
  const informazioni: InfoApp[] = [];

  // 1. I mancanti del generatore (gonna, vestito e cravatta solo se l'armadio ne ha).
  const sottocategorie = new Set(armadio.flatMap((g) => [g.sub_fine, g.sub_category]));
  const richiesti: Record<string, any>[] = Array.isArray(valigia.richiesti) ? valigia.richiesti : [];
  for (const originale of (valigia.mancanti_canonici ?? []) as Record<string, any>[]) {
    const g = perQuestoArmadio(originale, sottocategorie);
    if (!g) continue;
    const viaggioFreddo = freddoPer(g, meteo);
    const attivita = attivitaPer(g, viaggio);
    if (g.tipo === "volume_eccedente") {
      informazioni.push({ codice: String(g.tipo), ...copyMancante(g, viaggioFreddo, attivita, lingua) });
      continue;
    }
    if (!TIPI_DI_POSTO.has(g.tipo)) continue;
    // Lo stesso capo che nomina l'avviso (copyMancante): col freddo, il maglione e non la felpa.
    const { sub, categoria } = capoDelGap(g, viaggioFreddo || (calore(g)?.[0] ?? 0) >= 3);
    const tipo = sub ?? categoria;
    if (!tipo) continue;
    const capo = { sub, categoria };
    const frequenza = String(richiesti.find((r) => r.slot === g.slot)?.frequency ?? "daily");
    grezzi.push({
      tipo, categoria: "vestiti", livello: livelloPosto(g, capo, viaggioFreddo),
      copie: copieDelMancante(g, sub, frequenza, giorni, lavatrice),
      motivo: copyMancante(g, viaggioFreddo, attivita, lingua).perche,
      capo, qualifica: qualificaDelGap(g, capo, viaggioFreddo),
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
        capo: { sub: null, categoria: famiglia.tipo }, qualifica: null });
      continue;
    }
    const g = perId.get(id);
    if (!g) continue;
    const sub = NOMI_SOTTOCATEGORIA[g.sub_category] ? g.sub_category : null;
    if (!sub && !NOMI_CATEGORIA[g.category]) continue;
    const capo = { sub, categoria: g.category };
    // Un pezzo solo in meno non e' mai importante.
    grezzi.push({ tipo: sub ?? g.category, categoria: "vestiti", livello: manca > 1 ? livelloPosto({}, capo, freddo) : "utile",
      copie: manca, motivo, capo, qualifica: null });
  }

  // 3. Essenziali di base assenti: le copie che avrebbe un utente con quell'oggetto.
  const coperte = new Set(((valigia.essenziali ?? []) as Record<string, any>[]).map((e) => famigliaDi(e.radice)?.tipo));
  for (const f of FAMIGLIE) {
    if (coperte.has(f.tipo)) continue;
    const [e] = essenzialiPerViaggio(caricaArmadio([{ id: `posto:${f.tipo}`, name: f.nome }]), giorni, lavatrice);
    grezzi.push({ tipo: f.tipo, categoria: f.categoria, livello: "utile", copie: Math.max(1, e?.quantita ?? 1),
      motivo: null, capo: { sub: null, categoria: f.tipo }, qualifica: null });
  }

  // 4. Uniti per tipo: copie sommate, importante se lo e' almeno uno, motivo e nome di quello.
  const uniti = new Map<string, Grezzo>();
  for (const p of grezzi) {
    const gia = uniti.get(p.tipo);
    if (!gia) { uniti.set(p.tipo, { ...p }); continue; }
    gia.copie += p.copie;
    if (p.livello === "importante" && gia.livello !== "importante") {
      Object.assign(gia, { livello: p.livello, motivo: p.motivo, capo: p.capo, qualifica: p.qualifica });
    }
  }

  // 5. Prima gli importanti; dentro, l'ordine di nascita (sort e' stabile).
  const posti = [...uniti.values()]
    .sort((a, b) => Number(b.livello === "importante") - Number(a.livello === "importante"))
    .map((p, i): PostoApp => {
      const { nome, aggiungi } = nomePosto(p.capo, p.copie, p.qualifica, lingua);
      return { id: `${p.tipo}:${i}`, tipo: p.tipo, categoria: p.categoria, livello: p.livello, nome, copie: p.copie,
        motivo: p.motivo, aggiungi };
    });

  const lavanderia = lavanderiaDelViaggio(viaggio, lingua);
  if (lavanderia) informazioni.push({ codice: CODICE_LAVANDERIA, ...lavanderia });
  return { posti, informazioni };
}
