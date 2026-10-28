// Regole sui capi condivise (Davide, 18-19 ottobre 2026). Porting di
// regole_capi.py del bench: i commenti con il PERCHE' di ogni soglia stanno la',
// qui c'e' solo il necessario per leggere il codice. Una differenza di
// comportamento fra le due versioni e' un errore: la verifica e' l'oracolo
// (test/oracolo_regole.json, scritto dal bench).

type Num = number | null | undefined;
const lower = (s: string | null | undefined) => (s ?? "").toLowerCase();

// ── Capi estivi ─────────────────────────────────────────────────────────────
export const SOGLIA_ESTIVI = 21.0;
export const SOGLIA_CALDO_TORRIDO_ESTIVO = 0.8;
export const SOTTOCAT_ESTIVE = new Set(["Shorts", "Sandals", "Flip-Flops", "Swimwear"]);
export const CATEGORIE_ESTIVE_VIETATE = new Set(["Lower Body", "Shoes"]);
export const SOTTOCAT_ACQUA = new Set(["Swimwear", "Flip-Flops"]);
const NOME_ESTIVO = /\blino\b|estiv/;

export function capoEstivo(nome: string, sottocat: string, calore: Num, tags: string[] | null | undefined,
  caldoTorrido: Num = null): boolean {
  if (NOME_ESTIVO.test(lower(nome))) return true;
  if (caldoTorrido != null) return caldoTorrido >= SOGLIA_CALDO_TORRIDO_ESTIVO;
  return (calore || 3) <= 1 && (SOTTOCAT_ESTIVE.has(sottocat) || (tags ?? []).includes("Beach"));
}

export function estivoVietato(nome: string, categoria: string, sottocat: string, calore: Num,
  tags: string[] | null | undefined, tempMax: Num, inAcqua: boolean, caldoTorrido: Num = null): boolean {
  if (tempMax == null || tempMax > SOGLIA_ESTIVI) return false;
  if (!CATEGORIE_ESTIVE_VIETATE.has(categoria)) return false;
  if (inAcqua && SOTTOCAT_ACQUA.has(sottocat)) return false;
  return capoEstivo(nome, sottocat, calore, tags, caldoTorrido);
}

// ── Luoghi di culto: "coprente ma leggero" solo col caldo ───────────────────
export function cultoLeggero(tempMax: Num): boolean {
  return tempMax == null || tempMax > SOGLIA_ESTIVI;
}

// ── Col caldo un capo sopra leggero al giorno ───────────────────────────────
export const SOGLIA_UN_CAPO_AL_GIORNO = 24.0;
export const GIORNI_AUTONOMIA_LAVATRICE = 4;
export const SOTTOCAT_SOPRA_LEGGERE = new Set(["T-Shirt", "Shirt", "Polo", "Tank Top", "Crop Top"]);
export const CALORE_SOPRA_LEGGERO = 2;

export function caldoUnCapoAlGiorno(tempMax: Num): boolean {
  return tempMax != null && tempMax > SOGLIA_UN_CAPO_AL_GIORNO;
}

export function capoSopraLeggero(categoria: string, sottocat: string, calore: Num): boolean {
  return categoria === "Upper Body" && SOTTOCAT_SOPRA_LEGGERE.has(sottocat) &&
    (calore || 3) <= CALORE_SOPRA_LEGGERO;
}

export function capiLeggeriColCaldo(giorniCaldi: number, lavatrice: boolean): number {
  return lavatrice ? Math.min(giorniCaldi, GIORNI_AUTONOMIA_LAVATRICE + 1) : giorniCaldi;
}

// ── Costumi e giorni di mare ────────────────────────────────────────────────
export const SOGLIA_SECONDO_COSTUME = 2;
export const SOGLIA_TERZO_COSTUME = 5;
export const MAX_COSTUMI = 3;

export function costumiPerGiorniDiMare(giorniMare: number): number {
  if (giorniMare <= SOGLIA_SECONDO_COSTUME) return 1;
  if (giorniMare <= SOGLIA_TERZO_COSTUME) return Math.min(2, MAX_COSTUMI);
  return MAX_COSTUMI;
}

export function minimoGiorniDiMare(giorni: number): number {
  return Math.ceil(giorni / 2);
}

// ── Pigiama ─────────────────────────────────────────────────────────────────
export const GIORNI_SECONDO_PIGIAMA = 25;
export function pigiamiPerViaggio(giorni: number): number {
  return giorni > GIORNI_SECONDO_PIGIAMA ? 2 : 1;
}

// ── Capispalla ──────────────────────────────────────────────────────────────
export const MAX_CAPISPALLA = 2;
export const FORMALITA_ELEGANTI = new Set(["Smart Casual", "Business", "Formal"]);

export function contaComeCapospalla(categoria: string, sottocat: string, formalita: string | null | undefined): boolean {
  if (categoria !== "Outerwear") return false;
  return !(sottocat === "Blazer" && FORMALITA_ELEGANTI.has(formalita ?? ""));
}

// ── Scarpe con lo stesso ruolo ──────────────────────────────────────────────
export function ruoloScarpa(sottocat: string, tags: string[] | null | undefined, calore: Num,
  formalita: string | null | undefined): string {
  const t = new Set(tags ?? []);
  if (sottocat === "Hiking Boots" || ((sottocat === "Sneakers" || sottocat === "Boots") && t.has("Hiking"))) {
    return "trekking";
  }
  if (sottocat === "Boots") return (calore || 3) >= 5 ? "neve" : "stivaletti";
  if (sottocat === "Dress Shoes" || (sottocat === "Loafers" && FORMALITA_ELEGANTI.has(formalita ?? ""))) {
    return "eleganti";
  }
  if (sottocat === "Sandals" || sottocat === "Loafers") return "sandali";
  if (sottocat === "Flip-Flops") return "ciabatte";
  return sottocat || "altro";
}

// ── Capi presentabili ───────────────────────────────────────────────────────
export const GIORNI_PER_PRESENTABILE = 3;
export const MAX_PRESENTABILI = 3;
export const RADICI_NATURA = ["trekking", "escursion", "campeggio"];
export const RADICI_MARE = ["mare", "spiaggia", "immersion", "snorkel"];
export const RADICI_CITTA = ["citta", "muse", "mercat"];
export const RADICI_SERA = ["cena", "cene", "ristorante", "vita notturna", "concert", "teatro", "serata"];
export const RADICI_OCCASIONE_FORMALE = ["matrimon", "cerimon", "gala", "battesim", "laurea",
  "riunion", "congress", "lavoro", "elegant", "formal", "opera"];
export const CAPIENZA_SENZA_PRESENTABILI = 8;

export function ha(attivita: (string | null)[] | null | undefined, radici: string[]): boolean {
  return (attivita ?? []).some((a) => radici.some((r) => lower(a).includes(r)));
}

export function presentabiliRichiesti(giorni: number, attivita: string[] | null | undefined,
  cene: boolean | null = null, tracolla = false): number {
  if (tracolla) return 0;
  const perTre = Math.max(1, Math.min(MAX_PRESENTABILI, Math.floor((giorni || 1) / GIORNI_PER_PRESENTABILE)));
  if (cene == null) cene = ha(attivita, RADICI_SERA);
  if (cene) return perTre;
  if (ha(attivita, RADICI_NATURA)) return 0;
  if (ha(attivita, RADICI_MARE)) return perTre;
  if (ha(attivita, RADICI_CITTA)) return 1;
  return 0;
}

export function occasioneFormale(attivita: string[] | null | undefined): boolean {
  return ha(attivita, RADICI_OCCASIONE_FORMALE);
}

// ── Una felpa per la sera anche d'estate ────────────────────────────────────
export const RADICI_SERA_FRESCA = ["mare", "spiaggia", "lago", "immersion", "snorkel", "campeggio", "tenda"];
export const CALORE_FELPA_ESTIVA = 3;
export function felpaSeraEstiva(attivita: string[] | null | undefined): boolean {
  return ha(attivita, RADICI_SERA_FRESCA);
}

// ── Terza revisione alla cieca ──────────────────────────────────────────────
export const MAX_STRATI_MEDI = 2;
export const MAX_STRATI_MEDI_LUNGHI = 3;
export const GIORNI_VIAGGIO_LUNGO = 10;
export const FREDDO_VERO = 0.0;
export const SOTTOCAT_STRATI_MEDI = new Set(["Sweater", "Sweatshirt", "Hoodie"]);

export function stratiMediMassimi(giorni: number, tempMin: Num): number {
  if ((giorni || 0) > GIORNI_VIAGGIO_LUNGO || (tempMin != null && tempMin <= FREDDO_VERO)) {
    return MAX_STRATI_MEDI_LUNGHI;
  }
  return MAX_STRATI_MEDI;
}

// Pantaloni da giorno e da sera secondo il caldo.
export const SOGLIA_PANTALONI_CALDO = 24.0;
export const SOGLIA_PANTALONI_TORRIDO = 30.0;
export const SOGLIA_NOTTI_TORRIDE = 24.0;
export const GIORNI_PER_PANTALONE_GIORNO: Record<string, number> = { fresco: 4.0, caldo: 3.0, torrido: 2.5 };
export const PANTALONI_SERA: Record<string, number> = { fresco: 1, caldo: 1, torrido: 2 };
export const GIORNI_PANTALONE_SERA = 3;
export const MAX_PANTALONI = 6;

export function fasciaCaldo(tempMax: Num, tempMin: Num): "fresco" | "caldo" | "torrido" {
  if ((tempMax != null && tempMax >= SOGLIA_PANTALONI_TORRIDO) || (tempMin != null && tempMin > SOGLIA_NOTTI_TORRIDE)) {
    return "torrido";
  }
  if (tempMax != null && tempMax > SOGLIA_PANTALONI_CALDO) return "caldo";
  return "fresco";
}

/** tappe: [giorni, massima media, minima media] per tappa. */
export function pantaloniPerClima(tappe: [number, Num, Num][], lavatrice = false): number {
  const giorniTot = tappe.reduce((s, [g]) => s + g, 0) || 1;
  const scala = lavatrice ? Math.min(giorniTot, GIORNI_AUTONOMIA_LAVATRICE + 1) / giorniTot : 1.0;
  const daGiorno = tappe.reduce((s, [g, tx, tn]) => s + g * scala / GIORNI_PER_PANTALONE_GIORNO[fasciaCaldo(tx, tn)], 0);
  const daSera = giorniTot >= GIORNI_PANTALONE_SERA
    ? Math.max(...tappe.map(([, tx, tn]) => PANTALONI_SERA[fasciaCaldo(tx, tn)]))
    : 0;
  return Math.max(1, Math.min(MAX_PANTALONI, Math.ceil(daGiorno - 1e-9) + daSera));
}

export function ruoloCapospalla(sottocat: string, formalita: string | null | undefined, calore: Num): string | null {
  if (sottocat === "Blazer") return FORMALITA_ELEGANTI.has(formalita ?? "") ? null : "giacca";
  if (sottocat === "Rain Jacket" || sottocat === "Windbreaker") return (calore || 2) <= 2 ? "guscio" : "guscio caldo";
  return "caldo";
}

// Cammini a piedi con zaino piccolo.
export const RADICI_CAMMINO_A_PIEDI = ["cammino"];
export const LITRI_ZAINO_PICCOLO = 40;
export const GIORNI_CAMMINO = 10;
const LITRI = /(\d+)\s*litri/;

export function camminoAPiedi(attivita: string[] | null | undefined, bagaglio: string | null | undefined,
  giorni: number): boolean {
  const b = lower(bagaglio);
  const m = LITRI.exec(b);
  const zainoPiccolo = b.includes("zaino") && (m == null || parseInt(m[1], 10) <= LITRI_ZAINO_PICCOLO);
  return zainoPiccolo && (giorni || 0) >= GIORNI_CAMMINO && ha(attivita, RADICI_CAMMINO_A_PIEDI);
}
