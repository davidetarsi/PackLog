// "Le cene informali non sono un'occasione formale" (Davide, 7 novembre): come test_cene_informali.py del bench.
import { test } from "node:test";
import assert from "node:assert/strict";
import { occasioneFormale } from "../regole_capi.ts";

test("occasione formale: informale non e' formale", () => {
  for (const att of [["cene informali"], ["Cene informali al ristorante"], ["serate informali", "musei"], ["abbigliamento informale"]]) {
    assert.equal(occasioneFormale(att), false, att.join());
  }
});

test("occasione formale: formale, elegante, matrimonio e lavoro restano formali", () => {
  for (const att of [["cene formali"], ["serata formale"], ["Cena elegante"], ["matrimonio"], ["riunioni di lavoro"],
    ["cene informali", "cena formale di gala"], ["formale"]]) {
    assert.equal(occasioneFormale(att), true, att.join());
  }
  assert.equal(occasioneFormale(null), false);
});
