// L'uscita per l'app: i capi come li vede l'utente (uno per capo, con la quantita'
// da portare), il tetto sulle quantita' che ha davvero nell'armadio, e gli avvisi
// su cio' che manca. Non tocca la scelta dei capi: lavora sul risultato del generatore.
import { vero } from "./py.ts";

type Record_ = Record<string, any>;

export const CODICE_POCHI = "pochi_pezzi";

export interface CapoApp {
  item_id: string;
  quantita: number;
  in_partenza: boolean;
  motivo: { codice: string; etichetta: string; frase: string };
}

export interface AvvisoApp {
  id: string;
  codice: string;
  livello: "importante" | "utile";
  titolo: string;
  perche: string;
  cerca: string | null;
}

// Copy fisso (italiano, niente testo libero dal generatore): ogni frase nasce solo
// dai campi strutturati del gap (category, subCategories, tipo, tappe, warmth_richiesto,
// impermeabilita_richiesta, candidato_scartato, da_valutare). Mai la parola "capospalla", mai numeri.
const NOME_SOTTOCATEGORIA: Record<string, string> = {
  "T-Shirt": "una maglietta", "Shirt": "una camicia", "Polo": "una polo", "Hoodie": "una felpa con cappuccio",
  "Sweatshirt": "una felpa", "Sweater": "un maglione", "Tank Top": "una canottiera", "Crop Top": "un top",
  "Thermal Top": "una maglia termica", "Fleece": "un pile", "Jeans": "un paio di jeans",
  "Shorts": "un paio di pantaloncini", "Trousers": "un paio di pantaloni", "Leggings": "un paio di leggings",
  "Skirt": "una gonna", "Sweatpants": "un paio di pantaloni della tuta", "Swimwear": "un costume da bagno",
  "Thermal Bottoms": "un paio di pantaloni termici", "Ski Pants": "un paio di pantaloni da sci",
  "Wetsuit": "una muta", "Dress": "un vestito", "Sneakers": "un paio di sneakers", "Sandals": "un paio di sandali",
  "Boots": "un paio di stivali", "Flip-Flops": "un paio di infradito", "Loafers": "un paio di mocassini",
  "Dress Shoes": "un paio di scarpe eleganti", "Hiking Boots": "un paio di scarponi da trekking",
  "Water Shoes": "un paio di scarpe da acqua", "Snow Boots": "un paio di doposci", "Coat": "un cappotto",
  "Rain Jacket": "una giacca impermeabile", "Down Jacket": "un piumino", "Windbreaker": "una giacca a vento",
  "Blazer": "un blazer", "Ski Jacket": "una giacca da sci", "Ski Suit": "una tuta da sci",
  "Casual Jacket": "una giacca casual", "Vest": "un gilet", "Cap/Hat": "un cappello", "Belt": "una cintura",
  "Bag": "una borsa", "Scarf": "una sciarpa", "Sunglasses": "un paio di occhiali da sole",
  "Jewelry": "un gioiello", "Watch": "un orologio", "Gloves": "un paio di guanti", "Tie": "una cravatta",
  "Umbrella": "un ombrello",
};
const NOME_CATEGORIA: Record<string, string> = {
  "Upper Body": "una maglia", "Lower Body": "un paio di pantaloni", "Full Body": "un vestito",
  "Shoes": "un paio di scarpe", "Outerwear": "una giacca", "Accessory": "un accessorio",
};

/** Il capo come frase: la prima sottocategoria che conosciamo, altrimenti la categoria, altrimenti "un capo". */
function nomeCapo(g: Record_): string {
  const subs: unknown[] = Array.isArray(g.subCategories) ? g.subCategories : [];
  for (const s of subs) if (typeof s === "string" && NOME_SOTTOCATEGORIA[s]) return NOME_SOTTOCATEGORIA[s];
  return NOME_CATEGORIA[String(g.category ?? "")] ?? "un capo";
}

/** "Reykjavik", "Reykjavik e Akureyri", "A, B e C"; senza tappe: il viaggio intero. */
function perTappe(g: Record_): string {
  const nomi = (Array.isArray(g.tappe) ? g.tappe : []).map(String).filter((n) => n.trim() !== "");
  if (!nomi.length) return "per il viaggio";
  if (nomi.length === 1) return `per ${nomi[0]}`;
  return `per ${nomi.slice(0, -1).join(", ")} e ${nomi[nomi.length - 1]}`;
}

/** Il motivo del capo che manca, dai soli campi strutturati: il freddo e la pioggia, se servono entrambi. */
function perMeteo(g: Record_): string {
  const acqua = Number(g.impermeabilita_richiesta ?? 0) >= 1 || Number(g.requiredWaterResistance ?? 0) >= 1;
  const v = g.warmth_richiesto;
  const freddo = Array.isArray(v) && v.length === 2 && Number.isFinite(Number(v[0])) && Number(v[0]) >= 3;
  if (freddo && acqua) return "per il freddo e la pioggia previsti";
  if (freddo) return "per il freddo previsto";
  if (acqua) return "per la pioggia prevista";
  return "per il meteo previsto";
}

/** "A", "A o B", "A, B o C". */
function inAlternativa(nomi: string[]): string {
  if (nomi.length <= 1) return nomi.join("");
  return `${nomi.slice(0, -1).join(", ")} o ${nomi[nomi.length - 1]}`;
}

/** Titolo e corpo di un avviso dai mancanti del generatore: solo copy fisso, mai il testo libero. */
export function copyMancante(g: Record_): { titolo: string; perche: string } {
  if (g.tipo === "volume_eccedente") {
    const nomi = (Array.isArray(g.da_valutare) ? g.da_valutare : []).map(String).filter((n) => n.trim() !== "");
    return { titolo: "Il bagaglio è troppo pieno",
      perche: nomi.length ? `Valuta di lasciare a casa ${inAlternativa(nomi)}.`
        : "Quello che serve per questo viaggio non ci sta nel bagaglio scelto." };
  }
  const capo = nomeCapo(g);
  const tappe = perTappe(g);
  if (g.tipo === "quantita_insufficiente") {
    return { titolo: `Ti serve più di ${capo} ${tappe}`,
      perche: "Nell'armadio di questa casa ne hai meno di quante ne servono." };
  }
  const candidato = typeof g.candidato_scartato === "string" ? g.candidato_scartato.trim() : "";
  if (g.tipo === "posseduto_ma_inadatto" && candidato) {
    return { titolo: `Manca ${capo} ${tappe}`, perche: `${candidato} non è abbastanza ${perMeteo(g)}.` };
  }
  return { titolo: `Manca ${capo} ${tappe}`,
    perche: "Nell'armadio di questa casa non c'è niente di adatto al meteo previsto." };
}

/** Capi (uniti per item_id, quantita' sommata, tetto dell'armadio) e avvisi della valigia. */
export function uscitaApp(valigia: Record_, motivi: { capi: Record_[]; essenziali: Record_[] },
  salvate: Map<string, number | null>): { capi: CapoApp[]; avvisi: AvvisoApp[] } {
  // Lo stesso capo puo' stare in piu' tappe, come ideale e ripiego, o tra gli essenziali:
  // una riga sola, con la quantita' di tutti i posti in cui serve.
  const uniti = new Map<string, { item: string; quantita: number; in_partenza: boolean; motivo: Record_ }>();
  for (const x of [...motivi.capi, ...motivi.essenziali]) {
    const id = String(x.item_id);
    // Quantita' non numerica (o assente) conta come un pezzo.
    const n = x.quantita == null ? 1 : Number(x.quantita);
    const quantita = Number.isFinite(n) ? n : 1;
    const corrente = uniti.get(id);
    if (corrente) {
      corrente.quantita += quantita;
      corrente.in_partenza = corrente.in_partenza || vero(x.in_partenza);
    } else {
      uniti.set(id, { item: String(x.item ?? ""), quantita, in_partenza: vero(x.in_partenza), motivo: x.motivo });
    }
  }

  // Un capo tra gli essenziali e' importante anche se il suo motivo principale viene dai capi.
  const essenziali = new Set(motivi.essenziali.map((x) => String(x.item_id)));
  const capi: CapoApp[] = [];
  const avvisi: Omit<AvvisoApp, "id">[] = [];
  for (const [id, c] of uniti) {
    // Zero o negativo nell'armadio conta come una copia: il capo non sparisce.
    const tetto = Math.max(1, salvate.get(id) ?? 1);
    const quantita = Math.min(c.quantita, tetto);
    capi.push({
      item_id: id, quantita, in_partenza: c.in_partenza,
      motivo: { codice: c.motivo.codice, etichetta: c.motivo.etichetta, frase: c.motivo.frase },
    });
    if (quantita < c.quantita) {
      // Un pezzo solo in meno non e' mai importante, nemmeno per un essenziale.
      const essenziale = c.motivo.codice === "essenziale" || essenziali.has(id);
      avvisi.push({
        codice: CODICE_POCHI,
        livello: essenziale && c.quantita - tetto > 1 ? "importante" : "utile",
        titolo: `Ti servono più pezzi di ${c.item}`,
        perche: `Ne servirebbero ${c.quantita}, nell'armadio ne hai ${tetto}.`,
        cerca: c.item,
      });
    }
  }

  for (const g of (valigia.mancanti_canonici ?? []) as Record_[]) {
    const { titolo, perche } = copyMancante(g);
    avvisi.push({
      codice: String(g.tipo),
      // Importante se il generatore lo dice necessario o lo segna come essenziale (Rovaniemi senza piumino).
      livello: g.priorita === "necessario" || vero(g.essential) ? "importante" : "utile",
      titolo,
      perche,
      cerca: null,
    });
  }

  // Prima gli importanti; a parita' di livello l'ordine di sopra (sort e' stabile).
  const ordinati = avvisi
    .sort((a, b) => Number(b.livello === "importante") - Number(a.livello === "importante"))
    .map((a, i) => ({ id: `${a.codice}:${i}`, ...a }));
  return { capi, avvisi: ordinati };
}
