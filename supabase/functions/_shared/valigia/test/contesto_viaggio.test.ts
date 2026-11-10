import { test } from "node:test";
import assert from "node:assert/strict";
import { normalizzaQuantitaViaggio, preparaContestoTappe } from "../contesto_viaggio.ts";

test("contesto: il viaggio lungo conserva i quattordici giorni di autonomia", () => {
  assert.deepEqual(normalizzaQuantitaViaggio({ giorni: 60, lavatrice: false }),
    { giorni: 14, lavatrice: false, lavatriceEssenziali: false });
});

test("contesto: il bucato a mano del cammino vale anche per gli essenziali", () => {
  assert.deepEqual(normalizzaQuantitaViaggio({ giorni: 12, lavatrice: false,
    bagaglio: "zaino da 30 litri", attivita: ["cammino"] }),
    { giorni: 12, lavatrice: true, lavatriceEssenziali: true });
});

test("contesto: le tappe non subiscono il tetto dei viaggi lunghi in una sola meta", () => {
  assert.deepEqual(normalizzaQuantitaViaggio({ giorni: 60, lavatrice: false, lavatrice_essenziali: false }),
    { giorni: 60, lavatrice: false, lavatriceEssenziali: false });
});

const tappe = () => [
  { destinazione: "Fredda", giorni: 5, attivita: ["sci"], meteo: { temp_max_media: -2 } },
  { destinazione: "Calda", giorni: 7, attivita: ["trekking"], meteo: { temp_max_media: 25 } },
];
test("contesto tappe: la base calda conserva il trekking solo per la sua tappa", () => {
  const r = preparaContestoTappe({ attivita: [], lavatrice: false }, tappe(), "valigia grande");
  assert.equal(r.giorni, 12);
  assert.equal(r.base.destinazione, "Calda");
  assert.deepEqual(r.attivitaBase, []);
  assert.equal(r.trekkingDiTappa, true);
  assert.deepEqual(r.ordinate.map((t) => t.destinazione), ["Calda", "Fredda"]);
});

test("contesto tappe: stesso clima e durata conservano l'ordine originale", () => {
  const ts = tappe().map((t) => ({ ...t, giorni: 5, meteo: { temp_max_media: 15 } }));
  assert.deepEqual(preparaContestoTappe({ attivita: [] }, ts).ordinate.map((t) => t.destinazione), ["Fredda", "Calda"]);
});

test("contesto tappe: il cammino della base non viene esteso al bucato delle altre tappe", () => {
  const ts = tappe(); ts[1].attivita = ["cammino"];
  const r = preparaContestoTappe({ attivita: [], lavatrice: false }, ts, "zaino da 30 litri");
  assert.equal(r.lavatriceTappe, false);
  assert.equal(r.lavatriceBase, true);
  assert.equal(r.lavatriceEssenziali, false);
});
