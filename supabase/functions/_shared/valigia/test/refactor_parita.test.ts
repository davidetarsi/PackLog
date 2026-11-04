// Contratto di refactor: nessun capo, quantita', assegnazione o proposta cambia rispetto a PR102.
// Per il corpus esterno: PACKING_BASELINE_CASES=... PACKING_BASELINE_FILE=... node --test ...
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { chiaveCaso, impronta, modiArmadio, riproduciCaso } from "./support/replay_valigia.ts";

const casi = JSON.parse(readFileSync(process.env.PACKING_BASELINE_CASES
  ?? new URL("./oracolo_celle_campione.json", import.meta.url), "utf8"));
const baseline = JSON.parse(readFileSync(process.env.PACKING_BASELINE_FILE
  ?? new URL("./baseline_refactor.json", import.meta.url), "utf8"));

for (const modo of modiArmadio) test(`refactor: risultati invariati con armadio ${modo}`, () => {
  assert.equal(baseline.base, "b9f6404b8c146963d3419225130d76b30d20335e");
  assert.equal(baseline.input, impronta(casi), "Input diversi da quelli congelati");
  for (const c of casi) {
    const key = chiaveCaso(c, modo), atteso = baseline.casi[key];
    assert.ok(atteso, `Caso non congelato: ${key}`);
    for (const [campo, valore] of Object.entries(riproduciCaso(c, modo))) {
      assert.equal(impronta(valore), atteso[campo], `${key}: cambia ${campo}`);
    }
  }
});
