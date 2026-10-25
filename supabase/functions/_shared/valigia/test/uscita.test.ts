// L'uscita per l'app: capi uniti per capo, tetto sulle quantita' salvate, avvisi.
// Uso: node --test test/uscita.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { uscitaApp } from "../uscita.ts";

test("stesso capo in due punti: una riga, quantità sommata, tetto", () => {
  const motivi = { capi: [
      { item_id: "a", item: "Boxer neri", quantita: 3, in_partenza: false, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "x" } },
      { item_id: "a", item: "Boxer neri", quantita: 3, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "y" } },
      { item_id: "s", item: "Sneakers", quantita: 1, in_partenza: true, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "z" } }],
    essenziali: [{ item_id: "b", item: "Calzini", quantita: 6, motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "w" } }] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["a", 4], ["s", null], ["b", 8]]));
  assert.deepEqual(r.capi.map((c) => [c.item_id, c.quantita, c.in_partenza]), [["a", 4, false], ["s", 1, true], ["b", 6, false]]);
  assert.equal(r.capi[0].motivo.frase, "x");
  assert.deepEqual(r.avvisi, [{ id: "pochi_pezzi:0", codice: "pochi_pezzi", livello: "utile",
    titolo: "Ti servono più pezzi di Boxer neri", perche: "Ne servirebbero 6, nell'armadio ne hai 4.", cerca: "Boxer neri" }]);
});

test("stesso capo in ideali, ripieghi ed essenziali: una riga con la somma di tutti", () => {
  // Il caso del Review Focus: due tappe, ideale + ripiego, e lo stesso capo anche essenziale.
  const motivi = { capi: [
      { item_id: "c", item: "Maglietta bianca", quantita: 2, in_partenza: false, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "t1" } },
      { item_id: "c", item: "Maglietta bianca", quantita: 2, in_partenza: false, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "t2" } }],
    essenziali: [{ item_id: "c", item: "Maglietta bianca", quantita: 3, motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "e" } }] };
  // 2+2+3 = 7 pezzi servono in tutto: con 7 in armadio non c'e' tetto da applicare.
  const pieno = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["c", 7]]));
  assert.equal(pieno.capi.length, 1);
  assert.deepEqual([pieno.capi[0].item_id, pieno.capi[0].quantita], ["c", 7]);
  assert.equal(pieno.avvisi.length, 0);
  // Sommata prima del tetto: con 5 salvate il capo esce a 5 e l'avviso dice 7, non 2+2 o 3.
  const tagliato = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["c", 5]]));
  assert.equal(tagliato.capi[0].quantita, 5);
  assert.equal(tagliato.avvisi.length, 1);
  assert.equal(tagliato.avvisi[0].perche, "Ne servirebbero 7, nell'armadio ne hai 5.");
  assert.equal(tagliato.avvisi[0].livello, "importante"); // e' anche tra gli essenziali
});

test("capo essenziale tagliato dal tetto: avviso importante", () => {
  const motivi = { capi: [], essenziali: [
    { item_id: "k", item: "Pigiama", quantita: 3, motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "e" } }] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["k", 1]]));
  assert.deepEqual(r.avvisi.map((a) => [a.id, a.livello, a.cerca]), [["pochi_pezzi:0", "importante", "Pigiama"]]);
});

test("essenziale con un solo pezzo in meno: avviso utile, non importante", () => {
  // Il caso di DEV: 10 calzini salvati, 11 per dieci giorni.
  const motivi = { capi: [], essenziali: [
    { item_id: "k", item: "Calzini corti grigi", quantita: 11, motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "e" } }] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["k", 10]]));
  assert.deepEqual(r.avvisi.map((a) => [a.livello, a.titolo, a.perche]),
    [["utile", "Ti servono più pezzi di Calzini corti grigi", "Ne servirebbero 11, nell'armadio ne hai 10."]]);
});

test("mancante segnato essenziale dal generatore: importante anche se consigliato", () => {
  // Rovaniemi a dicembre senza piumino: il generatore lo dice essenziale ma solo consigliato.
  const r = uscitaApp({ mancanti_canonici: [
      { tipo: "posseduto_ma_inadatto", slot: "Giacca per la neve", priorita: "consigliato", essential: true,
        category: "Outerwear", subCategories: ["Down Jacket", "Rain Jacket"], warmth_richiesto: [5, 5],
        impermeabilita_richiesta: 2, candidato_scartato: "Giacca antipioggia leggera", tappe: [] },
      { tipo: "posseduto_ma_inadatto", slot: "Pantaloni per la sera", priorita: "consigliato", essential: false,
        category: "Lower Body", subCategories: ["Jeans"], warmth_richiesto: [2, 3], candidato_scartato: "Jeans chiari estivi" }] },
    { capi: [], essenziali: [] }, new Map());
  assert.deepEqual(r.avvisi.map((a) => [a.livello, a.titolo, a.perche]), [
    ["importante", "Manca un piumino per il viaggio", "Il più simile che hai, Giacca antipioggia leggera, non è adatto al freddo e alla pioggia previsti."],
    ["utile", "Manca un paio di jeans per il viaggio", "Il più simile che hai, Jeans chiari estivi, non è adatto a questo viaggio."]]);
});

test("bagaglio troppo pieno: frase sua, i capi da valutare, niente numeri", () => {
  const gap = { slot: "volume del bagaglio", tipo: "volume_eccedente", category: "", essential: false, imposto: true,
    priorita: "necessario", capienza: 30, volume: 41,
    reason: "la valigia occupa 41 punti, il bagaglio ne regge 30: valuta di lasciare a casa uno di questi capi" };
  const avviso = (extra: Record<string, unknown>) =>
    uscitaApp({ mancanti_canonici: [{ ...gap, ...extra }] }, { capi: [], essenziali: [] }, new Map()).avvisi[0];
  const tre = avviso({ da_valutare: ["Felpa grigia", "Maglione blu", "Jeans scuri"] });
  assert.deepEqual([tre.codice, tre.livello, tre.titolo, tre.perche, tre.cerca], ["volume_eccedente", "importante",
    "Il bagaglio è troppo pieno", "Valuta di lasciare a casa Felpa grigia, Maglione blu o Jeans scuri.", null]);
  assert.equal(avviso({ da_valutare: ["Felpa grigia"] }).perche, "Valuta di lasciare a casa Felpa grigia.");
  const nessuno = avviso({ da_valutare: [] });
  assert.equal(nessuno.perche, "Quello che serve per questo viaggio non ci sta nel bagaglio scelto.");
  assert.doesNotMatch(`${nessuno.titolo} ${nessuno.perche}`, /\d|manca/i);
});

test("quantita insufficiente: 'Ti serve più di'", () => {
  const r = uscitaApp({ mancanti_canonici: [{ tipo: "quantita_insufficiente", priorita: "necessario",
    category: "Lower Body", subCategories: ["Sweatpants"], tappe: ["Rovaniemi"] }] }, { capi: [], essenziali: [] }, new Map());
  assert.equal(r.avvisi[0].titolo, "Ti serve più di un paio di pantaloni della tuta per Rovaniemi");
});

test("avvisi dai mancanti: importanti prima", () => {
  const r = uscitaApp({ mancanti_canonici: [
      { tipo: "assente", slot: "cappello da sole", reason: "UV alto", priorita: "consigliato",
        category: "Accessory", subCategories: ["Cap/Hat"], tappe: ["Lisbona"] },
      { tipo: "assente", slot: "giacca impermeabile", reason: "pioggia 9 giorni su 12", priorita: "necessario",
        category: "Outerwear", subCategories: ["Rain Jacket"], impermeabilita_richiesta: 2, tappe: ["Lisbona", "Porto"] }] },
    { capi: [], essenziali: [] }, new Map());
  assert.deepEqual(r.avvisi.map((a) => [a.id, a.livello, a.titolo]),
    [["assente:0", "importante", "Manca una giacca impermeabile per Lisbona e Porto"],
     ["assente:1", "utile", "Manca un cappello per Lisbona"]]);
});

const gapCapospalla = (extra: Record<string, unknown>) => ({
  slot: "capospalla per il freddo", reason: "la pila arriva a 3.2, serve 4", category: "Outerwear",
  subCategories: ["Coat", "Down Jacket"], priorita: "necessario", tappe: ["Reykjavik"],
  warmth_richiesto: [4, 5], fonte: "meteo", ...extra,
});

test("copy dei mancanti: nessuna parola del generatore, niente numeri, tappa nel titolo", () => {
  const r = uscitaApp({ mancanti_canonici: [gapCapospalla({ tipo: "assente" })] },
    { capi: [], essenziali: [] }, new Map());
  const [a] = r.avvisi;
  assert.equal(a.titolo, "Manca un cappotto per Reykjavik");
  assert.equal(a.perche, "Nell'armadio di questa casa non c'è niente di adatto al freddo previsto.");
  assert.equal(a.cerca, null);
  assert.equal(a.codice, "assente");
  for (const testo of [a.titolo, a.perche]) {
    assert.doesNotMatch(testo, /capospalla/i);
    assert.doesNotMatch(testo, /pila/i);
    assert.doesNotMatch(testo, /\d/);
  }
});

test("posseduto_ma_inadatto: il candidato scartato spiega perche' non basta", () => {
  const r = uscitaApp({ mancanti_canonici: [gapCapospalla({ tipo: "posseduto_ma_inadatto",
    candidato_scartato: "Giacca in pelle", candidato_warmth: 2 })] }, { capi: [], essenziali: [] }, new Map());
  assert.equal(r.avvisi[0].codice, "posseduto_ma_inadatto");
  assert.equal(r.avvisi[0].titolo, "Manca un cappotto per Reykjavik");
  assert.equal(r.avvisi[0].perche, "Il più simile che hai, Giacca in pelle, non è adatto al freddo previsto.");
  assert.doesNotMatch(r.avvisi[0].perche, /capospalla|pila|\d/i);
});

test("tappe nel titolo: nessuna tappa, una, piu' di due", () => {
  const titolo = (tappe: string[]) => uscitaApp({ mancanti_canonici: [gapCapospalla({ tipo: "assente", tappe })] },
    { capi: [], essenziali: [] }, new Map()).avvisi[0].titolo;
  assert.equal(titolo([]), "Manca un cappotto per il viaggio");
  assert.equal(titolo(["Reykjavik"]), "Manca un cappotto per Reykjavik");
  assert.equal(titolo(["Reykjavik", "Akureyri", "Seyðisfjörður"]), "Manca un cappotto per Reykjavik, Akureyri e Seyðisfjörður");
});

test("copy con una sola categoria o senza nulla di noto: frase generica, mai vuota", () => {
  const titolo = (g: Record<string, unknown>) => uscitaApp({ mancanti_canonici: [g] },
    { capi: [], essenziali: [] }, new Map()).avvisi[0].titolo;
  assert.equal(titolo({ tipo: "assente", category: "Shoes", subCategories: ["Other"], tappe: ["Roma"] }),
    "Manca un paio di scarpe per Roma");
  assert.equal(titolo({ tipo: "assente", tappe: ["Roma"] }), "Manca un capo per Roma");
});

test("quantita non numerica conta come un pezzo", () => {
  const motivi = { capi: [
      { item_id: "n", item: "Calzini", quantita: "abc", in_partenza: false, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "f" } },
      { item_id: "m", item: "Canotte", quantita: null, in_partenza: false, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "g" } }],
    essenziali: [] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["n", 5], ["m", 5]]));
  assert.deepEqual(r.capi.map((c) => [c.item_id, c.quantita]), [["n", 1], ["m", 1]]);
  assert.equal(r.avvisi.length, 0);
});

test("salvate a 0 o negativo: contano come una copia", () => {
  const motivi = { capi: [
      { item_id: "z", item: "Costume", quantita: 2, in_partenza: false, motivo: { codice: "mare", etichetta: "Mare", frase: "m" } }],
    essenziali: [] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["z", 0]]));
  assert.deepEqual([r.capi[0].item_id, r.capi[0].quantita], ["z", 1]);
  assert.equal(r.avvisi[0].perche, "Ne servirebbero 2, nell'armadio ne hai 1.");
  const neg = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["z", -3]]));
  assert.equal(neg.capi[0].quantita, 1);
});

test("capo nei capi e tra gli essenziali, tagliato: avviso importante, motivo del primo", () => {
  const motivi = { capi: [
      { item_id: "d", item: "Boxer neri", quantita: 4, in_partenza: false, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "g" } }],
    essenziali: [{ item_id: "d", item: "Boxer neri", quantita: 2, motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "e" } }] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["d", 3]]));
  assert.deepEqual([r.capi[0].quantita, r.capi[0].motivo.codice], [3, "giorno"]);
  assert.deepEqual(r.avvisi.map((a) => [a.codice, a.livello, a.perche]),
    [["pochi_pezzi", "importante", "Ne servirebbero 6, nell'armadio ne hai 3."]]);
});
