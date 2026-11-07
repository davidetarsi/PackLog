import { limitaPantaloniDaSera } from "./dopo.ts";
import { eCammino, interoCammino, limitaProposteCammino } from "./cammino.ts";
import { analizzaFabbisogni, copieResidue, copriConProposte, intersecaVincoli, vincoliCompatibili,
  type AnalisiFabbisogni } from "./fabbisogni.ts";
// I posti della valigia dai mancanti del generatore: quanto e' importante un posto e come
// si chiama. Non tocca la scelta dei capi ne' gli avvisi (uscita.ts): e' un livello in piu'.
import type { Lingua } from "../lingua.ts";
import * as K from "./costanti.ts";
import { type Capo as CapoArmadio } from "./capo.ts";
import { eTrekking, interseca, parole, viaggioDiLavoro } from "./inject.ts";
import { eAttivitaAcqua, RADICI_GIORNI_ACQUA_IN_PIU } from "./quantita.ts";
import { ha, occasioneFormale } from "./regole_capi.ts";
import { attivitaPer, calore, capoDelGap, CODICE_LAVANDERIA, copyMancante, frasePochi, freddoPer, lavanderiaDelViaggio,
  meteoDelGap, perQuestoArmadio, SOLO_SE_NELL_ARMADIO, soloElegante, tettoSalvate } from "./uscita.ts";
import { NOME_FOULARD_LEGGERO, NOMI_CATEGORIA, NOMI_FAMIGLIA, NOMI_SOTTOCATEGORIA, type NomePosto } from "./posti_nomi.ts";

export type Livello = "importante" | "utile";
export type Qualifica = "freddo" | "acqua" | "elegante";

type Capo = { sub: string | null; categoria: string; foulardLeggero?: boolean; leggero?: boolean };

/** Il nome tecnico da solo non rende necessario un capo per questo viaggio. */
function daAttivita(sub: string | null, attivita: string[]): boolean {
  if (sub === "Hiking Boots") return eTrekking(attivita);
  if (sub === "Swimwear" || sub === "Water Shoes") return eAttivitaAcqua(attivita) || ha(attivita, RADICI_GIORNI_ACQUA_IN_PIU);
  if (["Ski Jacket", "Ski Pants", "Ski Suit", "Snow Boots"].includes(sub ?? "")) return interseca(parole(attivita), K.PAROLE_NEVE);
  return false;
}
const CATEGORIE_DEL_METEO = new Set(["Outerwear", "Shoes", "Accessory"]);

/** Importante solo cio' che dipende da questo viaggio: un'attivita', un'occasione elegante, il
 *  freddo o la pioggia per giacche, scarpe e accessori. Il resto (magliette, maglioni, strato
 *  termico compresi) e' utile. */
export function livelloPosto(g: Record<string, any>, capo: Capo, viaggioFreddo: boolean, attivita: string[] = []): Livello {
  // Muta e ombrello non sono obblighi del viaggio; il solo mare non impone le scarpette.
  if (capo.sub === "Wetsuit" || capo.sub === "Umbrella") return "utile";
  if (capo.sub === "Water Shoes" && !ha(attivita, RADICI_GIORNI_ACQUA_IN_PIU)) return "utile";
  if (daAttivita(capo.sub, attivita)) return "importante";
  if (soloElegante(g) && (viaggioDiLavoro(attivita) || occasioneFormale(attivita))) return "importante";
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
  const voce: NomePosto | undefined = capo.foulardLeggero ? NOME_FOULARD_LEGGERO :
    (capo.sub && NOMI_SOTTOCATEGORIA[capo.sub]) || NOMI_CATEGORIA[capo.categoria] || NOMI_FAMIGLIA[capo.categoria];
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
  requisiti?: { minWarmth?: number; maxWarmth?: number; formality?: string[]; minWaterResistance?: number;
    activityTags?: string[]; coverage?: string[] };
}

/** Cio' che l'utente deve sapere ma non e' un oggetto da mettere: bagaglio troppo pieno, lavanderia. */
export interface InfoApp { codice: string; titolo: string; perche: string }

const TIPI_DI_POSTO = new Set(["assente", "posseduto_ma_inadatto", "quantita_insufficiente"]);

export { parametriQuantita, mancantiDelleTappe, type ParametriQuantita } from "./fabbisogni.ts";

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
  /** Gli slot accettati dal matcher o gli item di cui mancano copie. */
  fonti?: string[];
  /** Solo per i mancanti: il gap chiede un capo elegante (soloElegante). */
  elegante?: boolean;
  /** Specifico per un'attivita': resta distinto dai capi del meteo anche quando e' utile. */
  daAttivita?: boolean;
  /** Il tipo scelto prima del raggruppamento, per nominare le scarpe da pioggia. */
  capoPioggia?: Capo;
  /** Solo per i mancanti: le tappe del gap (viaggi a piu' tappe), se il generatore le indica. */
  tappe?: string[];
  /** Il posto unico del meteo (unisciIlMeteo): non si somma ad altri posti dello stesso tipo. */
  delMeteo?: boolean;
  /** Vincoli del bisogno, usati per accorpare solo proposte compatibili. */
  bisogno?: Record<string, any>;
}

function compatibili(a: Grezzo, b: Grezzo): boolean {
  return vincoliCompatibili(a.bisogno, b.bisogno);
}

function unisciBisogni(a: Grezzo, b: Grezzo, lingua: Lingua): void {
  if (a.fonti || b.fonti) a.fonti = [...new Set([...(a.fonti ?? []), ...(b.fonti ?? [])])];
  if (!a.bisogno || !b.bisogno) return;
  const bisogno = intersecaVincoli(a.bisogno, b.bisogno);
  a.bisogno = bisogno;
  a.daAttivita = a.daAttivita || b.daAttivita;
  const freddo = a.qualifica === "freddo" || b.qualifica === "freddo";
  a.qualifica = qualificaDelGap(bisogno, a.capo, freddo);
  a.motivo = copyMancante(bisogno, freddo, [], lingua).perche;
  a.elegante = soloElegante(bisogno);
}

/** Giacche e scarpe del meteo diventano posti generici per categoria, conservando
 *  tutti i vincoli dei bisogni compatibili. Attivita', eleganza e pezzi mancanti restano a parte. */
function unisciIlMeteo(grezzi: Grezzo[], lingua: Lingua): Grezzo[] {
  const delMeteo = (p: Grezzo) => p.origine === "gap" && !p.elegante && !p.daAttivita &&
    (p.capo.categoria === "Outerwear" || p.capo.categoria === "Shoes");
  // Il posto unito di ogni categoria nasce dal primo importante; il freddo di uno qualunque lo qualifica.
  const gruppi: Grezzo[] = [];
  const assegnati = new Map<Grezzo, Grezzo>();
  for (const p of grezzi) {
    if (!delMeteo(p) || p.livello !== "importante") continue;
    const gia = gruppi.find((g) => g.capo.categoria === p.capo.categoria && compatibili(g, p));
    if (!gia) {
      const nuovo = { ...p, tipo: p.capo.categoria, copie: 1, delMeteo: true,
        capoPioggia: p.capo.categoria === "Shoes" ? p.capo : undefined,
        capo: { sub: null, categoria: p.capo.categoria } };
      gruppi.push(nuovo);
      assegnati.set(p, nuovo);
    } else { unisciBisogni(gia, p, lingua); assegnati.set(p, gia); }
  }
  const messi = new Set<Grezzo>();
  const risultato: Grezzo[] = [];
  for (const p of grezzi) {
    const unito = delMeteo(p) ? assegnati.get(p) ?? gruppi.find((g) => g.capo.categoria === p.capo.categoria && compatibili(g, p)) : undefined;
    if (!unito) { risultato.push(p); continue; } // non e' del meteo, o non c'e' un posto del meteo: resta com'e'
    if (p.livello !== "importante") unisciBisogni(unito, p, lingua);
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
  contesto: { meteo?: Record<string, any> | null; viaggio?: Record<string, any> | null; armadio: CapoArmadio[]; lingua?: Lingua; fabbisogni?: AnalisiFabbisogni },
): { posti: PostoApp[]; informazioni: InfoApp[] } {
  const lingua: Lingua = contesto.lingua ?? "it";
  const { meteo, viaggio, armadio } = contesto;
  const fabbisogni = contesto.fabbisogni ?? analizzaFabbisogni(valigia, armadio, viaggio, meteo, { motivi, salvate });
  const q = fabbisogni.quantita;
  const grezzi: Grezzo[] = [];
  const informazioni: InfoApp[] = [];

  // 1. I mancanti del generatore (gonna, vestito e cravatta solo se l'armadio ne ha).
  const sottocategorie = new Set(armadio.flatMap((g) => [g.sub_fine, g.sub_category]));
  for (const f of fabbisogni.mancanti) {
    const richiesto = f.richiesto;
    const g = perQuestoArmadio(f.vincoli, sottocategorie);
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
    const tipico = richiesto?.capoTipico as { sub?: string; categoria?: string; leggero?: boolean } | undefined;
    const usaTipico = Boolean(tipico?.sub && tipico.categoria && NOMI_SOTTOCATEGORIA[tipico.sub] &&
      (!SOLO_SE_NELL_ARMADIO.has(tipico.sub) || sottocategorie.has(tipico.sub)));
    const { sub, categoria } = usaTipico
      ? { sub: tipico!.sub!, categoria: tipico!.categoria! }
      : capoDelGap(g, viaggioFreddo || (calore(g)?.[0] ?? 0) >= 3);
    const tipo = sub ?? categoria;
    if (!tipo) continue;
    const capo: Capo = { sub, categoria, ...(usaTipico && tipico?.leggero != null ? { leggero: tipico.leggero } : {}),
      foulardLeggero: sub === "Scarf" && g.slot === "foulard" && (calore(g)?.[1] ?? 5) <= 2 };
    const proposta: Grezzo = {
      tipo, categoria: "vestiti", livello: livelloPosto(g, capo, viaggioFreddo, attivita),
      daAttivita: daAttivita(capo.sub, attivita),
      copie: copieResidue(f, sub),
      motivo: copyMancante(g, viaggioFreddo, attivita, lingua).perche,
      capo, qualifica: qualificaDelGap(g, capo, viaggioFreddo), origine: "gap", elegante: soloElegante(g),
      fonti: g.slot == null ? [] : [`slot:${g.slot}`],
      tappe: Array.isArray(g.tappe) ? g.tappe.map(String) : undefined,
      bisogno: g,
    };
    if (f.supplementare) {
      const copertura = copriConProposte(proposta, grezzi, fabbisogni.aTappe);
      for (const indice of copertura.riusate) {
        const p = grezzi[indice];
        unisciBisogni(p, proposta, lingua);
        if (proposta.livello === "importante") p.livello = "importante";
      }
      if (!copertura.copie) continue;
      proposta.copie = copertura.copie;
    }
    grezzi.push(proposta);
  }

  // 2. Pezzi in meno: il capo serve in piu' copie di quelle salvate (pochi_pezzi di uscitaApp).
  const perId = new Map(armadio.map((g) => [g.id, g]));
  for (const f of fabbisogni.copieMancanti) {
    const { id, copie: manca, famiglia } = f;
    const motivo = frasePochi(f.richieste, f.presenti, lingua);
    if (famiglia) {
      grezzi.push({ tipo: famiglia.tipo, categoria: famiglia.categoria, livello: "utile", copie: manca, motivo,
        capo: { sub: null, categoria: famiglia.tipo }, qualifica: null, origine: "pezzi" });
      continue;
    }
    const g = perId.get(id);
    if (!g) continue;
    const sub = NOMI_SOTTOCATEGORIA[g.sub_category] ? g.sub_category : null;
    if (!sub && !NOMI_CATEGORIA[g.category]) continue;
    const scelto = [...(valigia.ideali ?? []), ...(valigia.ripieghi ?? [])].find((r) => String(r.item_id) === id);
    const capo = { sub, categoria: g.category, leggero: scelto?.leggero ?? (g.warmth != null && g.warmth <= 2) };
    const bisogno = { tappe: f.tappe };
    // Un pezzo solo in meno non e' mai importante.
    grezzi.push({ tipo: sub ?? g.category, categoria: "vestiti", livello: manca > 1 ? livelloPosto({}, capo, freddoPer(bisogno, meteo), attivitaPer(bisogno, viaggio)) : "utile",
      copie: manca, motivo, capo, qualifica: null, origine: "pezzi", fonti: [`item:${id}`] });
  }

  // 3. Essenziali di base assenti: le copie che avrebbe un utente con quell'oggetto.
  for (const f of fabbisogni.essenzialiMancanti) {
    grezzi.push({ tipo: f.tipo, categoria: f.categoria, livello: "utile", copie: f.copie,
      motivo: null, capo: { sub: null, categoria: f.tipo }, qualifica: null, origine: "famiglia" });
  }

  // 4. Giacche e scarpe del meteo: un posto per ogni gruppo di bisogni compatibili.
  // 5. Uniti per tipo e vincoli compatibili: importante se lo e' almeno uno. Le copie: i mancanti
  // del generatore di Upper Body, Lower Body e Shoes nella stessa tappa (slot giornaliero e occasionale coprono
  // gli stessi giorni) si uniscono col massimo; tappe diverse coprono giorni diversi e si sommano,
  // come ogni mancante di un viaggio a piu' tappe senza tappa indicata, i pezzi in meno, le famiglie
  // Giacche e accessori riusabili compatibili prendono il massimo anche tra tappe.
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

  // Un solo budget serale per tutti i gruppi, anche quelli separati per requisiti.
  if (q.tutteTappeCalde && !eCammino(attivitaPer({}, viaggio)) &&
    !viaggioDiLavoro(attivitaPer({}, viaggio))) {
    const gruppi = [...uniti.entries()].map(([chiave, p]) => ({ chiave, p, category: p.capo.categoria,
      subCategory: p.capo.sub, quantita: p.copie,
      assegnazioni: [{ slot: JSON.stringify([p.bisogno?.formality ?? [], p.bisogno?.requiredActivityTags ?? [],
        p.bisogno?.coverage ?? [], p.bisogno?.impermeabilita_richiesta ?? p.bisogno?.requiredWaterResistance ?? 0,
        p.bisogno ? calore(p.bisogno) : null]) }],
      imposto: p.livello === "importante" }));
    // La valigia e' gia' scelta: qui e' copertura fissa, mai da ridurre per far posto a una proposta.
    const posseduti = [...(valigia.ideali ?? []), ...(valigia.ripieghi ?? [])].map((g) => ({ ...g,
      assegnazioni: gruppi.filter(({ p }) => p.fonti?.includes(`item:${g.item_id}`) ||
        (g.assegnazioni ?? []).some((a: Record<string, any>) =>
          ["ideale", "ripiego", "compromesso"].includes(a.match) && p.fonti?.includes(`slot:${a.slot}`)))
        .flatMap((gruppo) => gruppo.assegnazioni) }));
    const camicie = gruppi.filter((g) => g.subCategory === "Shirt").reduce((n, g) => n + g.quantita, 0) +
      posseduti.filter((g) => g.subCategory === "Shirt")
        .reduce((n, g) => n + Number(g.quantita ?? 1), 0);
    limitaPantaloniDaSera(gruppi, camicie, (g) => g.p
      ? g.p.capo.leggero === true || g.p.bisogno?.requiredActivityTags?.includes("Hiking")
      : (g.leggero ?? (g.warmth != null && g.warmth <= 2)) || perId.get(g.item_id)?.activity_tags.includes("Hiking"), posseduti);
    for (const g of gruppi) {
      if (g.quantita > 0) g.p.copie = g.quantita;
      else uniti.delete(g.chiave);
    }
  }

  // 6. Prima gli importanti; dentro, l'ordine di nascita (sort e' stabile).
  const posti = [...uniti.values()]
    .sort((a, b) => Number(b.livello === "importante") - Number(a.livello === "importante"))
    .map((p): PostoApp => {
      const scarpePioggia = p.delMeteo && p.qualifica === "acqua" && p.capoPioggia?.sub ? p.capoPioggia : null;
      const { nome, aggiungi } = nomePosto(scarpePioggia ?? p.capo, p.copie, scarpePioggia ? null : p.qualifica, lingua);
      const motivo = scarpePioggia && !/pioggia|rain/i.test(p.motivo ?? "")
        ? [p.motivo, lingua === "en" ? "Choose a pair suited to the expected rain." :
          "Scegli un paio adatto alla pioggia prevista."].filter(Boolean).join(" ")
        : p.motivo;
      const fascia = p.bisogno ? calore(p.bisogno) : null;
      const requisiti = p.bisogno ? {
        ...(fascia ? { minWarmth: fascia[0], maxWarmth: fascia[1] } : {}),
        formality: [...(p.bisogno.formality ?? [])].sort(),
        activityTags: [...(p.bisogno.requiredActivityTags ?? [])].sort(),
        coverage: [...(p.bisogno.coverage ?? [])].sort(),
        minWaterResistance: Number(p.bisogno.impermeabilita_richiesta ?? p.bisogno.requiredWaterResistance ?? 0),
      } : undefined;
      // Identita' del bisogno: non dipende dall'ordine, dalle copie o dalla lingua del nome.
      const id = `need:v1:${JSON.stringify([p.tipo, p.delMeteo ? "meteo" : p.origine,
        fascia, requisiti?.formality ?? [], requisiti?.minWaterResistance ?? 0,
        requisiti?.activityTags ?? [], requisiti?.coverage ?? []])}`;
      return { id, tipo: p.tipo, categoria: p.categoria, livello: p.livello, nome, copie: p.copie,
        motivo, aggiungi, ...(requisiti ? { requisiti } : {}) };
    });

  const lavanderia = lavanderiaDelViaggio(viaggio, lingua);
  if (lavanderia) informazioni.push({ codice: CODICE_LAVANDERIA, ...lavanderia });
  return { posti: interoCammino(viaggio) ? limitaProposteCammino(posti, valigia, (id) => tettoSalvate(salvate, id), armadio) : posti, informazioni };
}
