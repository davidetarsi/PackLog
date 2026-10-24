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
    titolo: "Pochi Boxer neri per questo viaggio", perche: "Ne servirebbero 6, nell'armadio ne hai 4.", cerca: "Boxer neri" }]);
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
    { item_id: "k", item: "Pigiama", quantita: 2, motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "e" } }] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["k", 1]]));
  assert.deepEqual(r.avvisi.map((a) => [a.id, a.livello, a.cerca]), [["pochi_pezzi:0", "importante", "Pigiama"]]);
});

test("avvisi dai mancanti: importanti prima", () => {
  const r = uscitaApp({ mancanti_canonici: [
      { tipo: "assente", slot: "cappello da sole", reason: "UV alto", priorita: "consigliato" },
      { tipo: "assente", slot: "giacca impermeabile", reason: "pioggia 9 giorni su 12", priorita: "necessario" }] },
    { capi: [], essenziali: [] }, new Map());
  assert.deepEqual(r.avvisi.map((a) => [a.id, a.livello, a.titolo]),
    [["assente:0", "importante", "Giacca impermeabile"], ["assente:1", "utile", "Cappello da sole"]]);
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
