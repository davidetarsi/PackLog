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

// Il meteo si nomina solo per i capi che lo riguardano: niente "pioggia" per un paio di
// infradito, niente "freddo" per un costume. Altrimenti la frase dice "a questo viaggio".
const CONTRO_LA_PIOGGIA = new Set(["Coat", "Rain Jacket", "Down Jacket", "Windbreaker", "Ski Jacket", "Ski Suit",
  "Casual Jacket", "Boots", "Hiking Boots", "Snow Boots", "Sneakers", "Dress Shoes", "Loafers", "Ski Pants",
  "Cap/Hat", "Umbrella"]);
const CATEGORIE_CONTRO_LA_PIOGGIA = new Set(["Outerwear"]);
const MAI_PER_IL_FREDDO = new Set(["T-Shirt", "Polo", "Tank Top", "Crop Top", "Shorts", "Swimwear", "Sandals",
  "Flip-Flops", "Water Shoes", "Sunglasses", "Umbrella", "Wetsuit", "Belt", "Tie", "Jewelry", "Watch", "Bag"]);

/** Il capo del gap: la prima sottocategoria che conosciamo, altrimenti la categoria, altrimenti "un capo". */
function capoDelGap(g: Record_): { nome: string; sub: string | null; categoria: string } {
  const categoria = String(g.category ?? "");
  const subs: unknown[] = Array.isArray(g.subCategories) ? g.subCategories : [];
  for (const s of subs) if (typeof s === "string" && NOME_SOTTOCATEGORIA[s]) return { nome: NOME_SOTTOCATEGORIA[s], sub: s, categoria };
  return { nome: NOME_CATEGORIA[categoria] ?? "un capo", sub: null, categoria };
}

/** "A", "A e B", "A, B e C" (oppure con "o"), senza nomi vuoti ne' ripetuti. */
function elenco(valori: unknown[], congiunzione: "e" | "o"): string {
  const nomi = [...new Set(valori.map((n) => String(n ?? "").trim()).filter((n) => n !== ""))];
  if (nomi.length <= 1) return nomi.join("");
  return `${nomi.slice(0, -1).join(", ")} ${congiunzione} ${nomi[nomi.length - 1]}`;
}

/** "per Reykjavik", "per Reykjavik e Akureyri"; senza tappe: il viaggio intero. */
function perTappe(g: Record_): string {
  const nomi = elenco(Array.isArray(g.tappe) ? g.tappe : [], "e");
  return nomi ? `per ${nomi}` : "per il viaggio";
}

/** A cosa non basta quello che c'e': il freddo e la pioggia solo se il capo li riguarda. */
function adattoA(g: Record_, capo: { sub: string | null; categoria: string }): string {
  const pioggiaSensata = capo.sub ? CONTRO_LA_PIOGGIA.has(capo.sub) : CATEGORIE_CONTRO_LA_PIOGGIA.has(capo.categoria);
  const freddoSensato = !(capo.sub && MAI_PER_IL_FREDDO.has(capo.sub));
  const acqua = pioggiaSensata &&
    (Number(g.impermeabilita_richiesta ?? 0) >= 1 || Number(g.requiredWaterResistance ?? 0) >= 1);
  const v = g.warmth_richiesto;
  const freddo = freddoSensato && Array.isArray(v) && v.length === 2 && Number.isFinite(Number(v[0])) && Number(v[0]) >= 3;
  if (freddo && acqua) return "al freddo e alla pioggia previsti";
  if (freddo) return "al freddo previsto";
  if (acqua) return "alla pioggia prevista";
  return "a questo viaggio";
}

/** Titolo e corpo di un avviso dai mancanti del generatore: solo copy fisso, mai il testo libero.
 *  Le frasi non accordano nulla col nome del capo dell'utente ("Il più simile che hai, X, ..."),
 *  cosi' reggono singolari e plurali. */
export function copyMancante(g: Record_): { titolo: string; perche: string } {
  if (g.tipo === "volume_eccedente") {
    const nomi = elenco(Array.isArray(g.da_valutare) ? g.da_valutare : [], "o");
    return { titolo: "Il bagaglio è troppo pieno",
      perche: nomi ? `Valuta di lasciare a casa ${nomi}.`
        : "Quello che serve per questo viaggio non ci sta nel bagaglio scelto." };
  }
  const capo = capoDelGap(g);
  const tappe = perTappe(g);
  if (g.tipo === "quantita_insufficiente") {
    return { titolo: `Ti serve più di ${capo.nome} ${tappe}`,
      perche: "Nell'armadio di questa casa ne hai meno di quante ne servono." };
  }
  const candidato = typeof g.candidato_scartato === "string" ? g.candidato_scartato.trim() : "";
  if (g.tipo === "posseduto_ma_inadatto" && candidato) {
    return { titolo: `Manca ${capo.nome} ${tappe}`,
      perche: `Il più simile che hai, ${candidato}, non è adatto ${adattoA(g, capo)}.` };
  }
  return { titolo: `Manca ${capo.nome} ${tappe}`,
    perche: `Nell'armadio di questa casa non c'è niente di adatto ${adattoA(g, capo)}.` };
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
        titolo: `Ti servono più pezzi di ${c.item.trim()}`,
        perche: `Ne servirebbero ${c.quantita}, nell'armadio ne hai ${tetto}.`,
        cerca: c.item.trim(),
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

  // Due mancanti diversi possono dare la stessa frase (due paia di stivali per la neve):
  // un avviso solo, importante se lo era almeno uno dei due.
  const unici = new Map<string, Omit<AvvisoApp, "id">>();
  for (const a of avvisi) {
    const chiave = `${a.titolo}\n${a.perche}`;
    const gia = unici.get(chiave);
    if (!gia) unici.set(chiave, a);
    else if (a.livello === "importante") gia.livello = "importante";
  }

  // Prima gli importanti; a parita' di livello l'ordine di sopra (sort e' stabile).
  const ordinati = [...unici.values()]
    .sort((a, b) => Number(b.livello === "importante") - Number(a.livello === "importante"))
    .map((a, i) => ({ id: `${a.codice}:${i}`, ...a }));
  return { capi, avvisi: ordinati };
}
