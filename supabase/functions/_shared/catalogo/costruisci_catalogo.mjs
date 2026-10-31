// Costruisce catalogo.json dai valori di oggi: tassonomia.ts e scheda.ts per i
// valori e il loro significato, i dizionari dell'app per le etichette, la
// tabella delle attivita' decisa con Davide il 31 ottobre (spec del catalogo,
// § 5). Si usa una volta, e di nuovo solo per ripartire da zero: da qui in poi
// il catalogo vero e' la tabella catalog_entries, e catalogo.json la sua copia.
// Uso: node costruisci_catalogo.mjs
import { readFileSync, writeFileSync } from "node:fs";
import * as tassonomia from "../valigia/tassonomia.ts";
import * as scheda from "../capi/scheda.ts";

const qui = new URL(".", import.meta.url);
const dizionario = (lingua) =>
  JSON.parse(readFileSync(new URL(`../../../../assets/translations/${lingua}.json`, qui), "utf8"));
const it = dizionario("it-IT"), en = dizionario("en-US");
const chiave = (v) => v.toLowerCase().replace(/[^a-z0-9]+/g, "_");
function etichetta(percorso) {
  const leggi = (d) => percorso.split(".").reduce((o, k) => o?.[k], d);
  const l = { it: leggi(it), en: leggi(en) };
  if (typeof l.it !== "string" || typeof l.en !== "string") throw new Error(`etichetta mancante: ${percorso}`);
  return l;
}

/** Le righe `"<id>" = testo` del blocco di RIGHE_CAMPI che comincia con `- "<campo>"`.
 *  [chiusa]: il blocco finisce con la ")" del "(ONE OF:" che lo apre, attaccata
 *  all'ultima riga, e non fa parte del testo. */
function descrizioni(campo, chiusa) {
  const testo = scheda.promptScan();
  const inizio = testo.indexOf(`- "${campo}"`);
  const fine = testo.indexOf("\n- ", inizio + 1);
  const blocco = testo.slice(inizio, fine < 0 ? undefined : fine);
  const righe = [...blocco.matchAll(/^  "([^"]+)" = (.*)$/gm)].map((m, i) => ({ id: m[1], testo: m[2], ordine: i }));
  if (chiusa) {
    const ultima = righe[righe.length - 1];
    if (!ultima.testo.endsWith(")")) throw new Error(`blocco ${campo} senza la parentesi di chiusura`);
    ultima.testo = ultima.testo.slice(0, -1);
  }
  return righe;
}

const voci = [];
const metti = (domain, id, sort, label, data = {}, active = true) =>
  voci.push({ domain, id, sort, active, label, data });

tassonomia.CATEGORIE.forEach((c, i) => metti("clothing_group", c, (i + 1) * 10, etichetta(`clothing.group.${chiave(c)}`)));

let n = 0;
const visti = new Set();
for (const c of tassonomia.CATEGORIE) {
  for (const s of tassonomia.SOTTOCATEGORIE[c]) {
    if (s === tassonomia.ALTRO || visti.has(s)) continue;
    visti.add(s);
    const nuova = Object.hasOwn(tassonomia.NUOVE, s);
    metti("clothing_type", s, (n += 10), etichetta(`clothing.type.${chiave(s)}`), {
      group: c,
      parent: nuova ? tassonomia.NUOVE[s][1] : null,
      isNew: nuova,
      hint: (nuova ? tassonomia.NUOVE[s][2] : tassonomia.SPIEGA_VECCHIE[s]) || null,
    });
  }
}
metti("clothing_type", tassonomia.ALTRO, (n += 10), etichetta("clothing.type.other"),
  { group: null, parent: null, isNew: false, hint: null, everyGroup: true });

const usi = Object.fromEntries(descrizioni("activityTags", false).map((d) => [d.id, d]));
scheda.TAG.forEach((t, i) => metti("use", t, (i + 1) * 10, etichetta(`clothing.activity.${chiave(t)}`),
  { prompt: usi[t].testo, promptOrder: usi[t].ordine }));

const stili = Object.fromEntries(descrizioni("formality", true).map((d) => [d.id, d]));
scheda.FORMALITA.forEach((f, i) => metti("formality", f, (i + 1) * 10, etichetta(`clothing.formality.${chiave(f)}`),
  { prompt: stili[f].testo }));

scheda.COLORI.forEach((c, i) => metti("color", c, (i + 1) * 10, etichetta(`clothing.color.${chiave(c)}`), {
  synonyms: Object.entries(scheda.SINONIMI_COLORE).filter(([, v]) => v === c).map(([k]) => k),
}));

for (const l of [1, 2, 3, 4, 5]) metti("warmth", String(l), l * 10, etichetta(`clothing.warmth.${l}`));
for (const l of [0, 1, 2]) metti("water", String(l), (l + 1) * 10, etichetta(`clothing.water.${l}`));

// Attivita' (Davide, 31 ottobre): una voce non cambia mai significato; le voci
// tolte restano disattivate, per i viaggi vecchi.
const ATTIVITA = [
  ["city", true, "Città e musei", "Cities and museums", ["visite in citta"]],
  ["walks", true, "Passeggiate nella natura", "Nature walks", ["escursioni leggere"]],
  ["trekking", true, "Trekking", "Trekking", ["trekking"]],
  ["cammino", true, "Cammino di più giorni", "Multi-day walk", ["cammino"]],
  ["sea", true, "Mare", "Sea", ["mare"]],
  ["diving", true, "Immersioni e snorkeling", "Diving and snorkeling", ["immersioni", "mare"]],
  ["ski", true, "Sci e neve", "Skiing and snow", ["sci"]],
  ["camping", true, "Campeggio", "Camping", ["campeggio"]],
  ["work", true, "Lavoro", "Work", ["riunioni di lavoro", "cene di lavoro"]],
  ["evenings", true, "Cene e serate", "Dinners and evenings out", ["cene al ristorante", "vita notturna"]],
  ["wedding", true, "Matrimoni e cerimonie", "Weddings and ceremonies", ["matrimonio", "cerimonia"]],
  ["worship", true, "Luoghi di culto", "Places of worship", ["visite a siti religiosi"]],
  ["spa", true, "Terme", "Spa", ["terme"]],
  ["high_mountain", false, "Alta montagna", "High mountains", ["escursioni in quota"]],
  ["formal_dinner", false, "Cena elegante", "Elegant dinner", ["cena formale"]],
  ["nightlife", false, "Serate e locali", "Nightlife", ["vita notturna"]],
  ["cycling", false, "Bicicletta", "Cycling", ["bicicletta"]],
];
ATTIVITA.forEach(([id, attiva, i, e, testi], k) =>
  metti("activity", id, (k + 1) * 10, { it: i, en: e }, { generator: testi }, attiva));

const ALLOGGI = [["hotel", "hotel"], ["apartment", "appartamento"], ["hostel", "ostello"],
  ["camping", "campeggio"], ["friends", "da amici o parenti"]];
ALLOGGI.forEach(([id, testo], k) =>
  metti("stay", id, (k + 1) * 10, etichetta(`trips.ai.stay.${id}`), { generator: testo }));

writeFileSync(new URL("catalogo.json", qui), JSON.stringify({ entries: voci }, null, 2) + "\n");
console.log(`${voci.length} voci`);
