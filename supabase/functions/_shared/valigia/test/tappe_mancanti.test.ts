// I mancanti della fase 1 vanno alle tappe di cui parlano, come tappe_del_mancante del bench.
// Uso: node --test test/tappe_mancanti.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { tappeDelMancante } from "../tappe.ts";

const TAPPE = [{ destinazione: "Reykjavik", attivita: ["escursioni leggere", "terme"] },
  { destinazione: "Amsterdam", attivita: ["visite in citta", "vita notturna"] },
  { destinazione: "Lisbona", attivita: ["visite in citta"] }];

test("le terme di Reykjavik non finiscono su Lisbona", () => {
  assert.deepEqual(tappeDelMancante({ slot: "Calzature per le terme", reason: "Per le terme servono calzature che si bagnano." }, TAPPE), ["Reykjavik"]);
  assert.deepEqual(tappeDelMancante({ slot: "Strato caldo", reason: "Per le serate fresche a Lisbona." }, TAPPE), ["Lisbona"]);
  assert.deepEqual(tappeDelMancante({ slot: "Giacca leggera", reason: "Per le visite." }, TAPPE), []);
  assert.deepEqual(tappeDelMancante({ slot: "spalle coperte" }, TAPPE), []);
});
