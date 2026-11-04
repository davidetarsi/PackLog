// Capi, quantita', assegnazioni e prompt restano congelati. Solo le differenze delle
// proposte esplicitamente revisionate possono superare il contratto originale.
// Per il corpus esterno: PACKING_BASELINE_CASES=... PACKING_BASELINE_FILE=... node --test ...
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { chiaveCaso, impronta, modiArmadio, riproduciCaso } from "./support/replay_valigia.ts";

const casi = JSON.parse(readFileSync(process.env.PACKING_BASELINE_CASES
  ?? new URL("./oracolo_celle_campione.json", import.meta.url), "utf8"));
const baseline = JSON.parse(readFileSync(process.env.PACKING_BASELINE_FILE
  ?? new URL("./baseline_refactor.json", import.meta.url), "utf8"));
const proposte = JSON.parse(readFileSync(process.env.PACKING_PROPOSAL_CHANGES
  ?? new URL("./baseline_proposte_migliorate.json", import.meta.url), "utf8"));

for (const modo of modiArmadio) test(`parita': valigia invariata e proposte revisionate con armadio ${modo}`, () => {
  assert.equal(baseline.base, "b9f6404b8c146963d3419225130d76b30d20335e");
  assert.equal(baseline.input, impronta(casi), "Input diversi da quelli congelati");
  assert.equal(proposte.base, "99591feb5484e3398a5f826d0d5c4ab312d1c22f");
  assert.equal(proposte.input, baseline.input, "Differenze proposte riferite ad altri input");
  for (const c of casi) {
    const key = chiaveCaso(c, modo), atteso = baseline.casi[key];
    assert.ok(atteso, `Caso non congelato: ${key}`);
    const delta = proposte.casi[key];
    if (delta) {
      assert.equal(delta.prima, atteso.proposte, `${key}: baseline delle proposte alterata`);
      assert.ok(delta.motivi.length > 0 && delta.motivi.every((m: string) =>
        ["ripiego_assegnato_compatibile", "formalita_senza_occasione"].includes(m)), `${key}: differenza non revisionata`);
      assert.notEqual(delta.dopo, delta.prima, `${key}: eccezione senza cambiamenti`);
    }
    for (const [campo, valore] of Object.entries(riproduciCaso(c, modo))) {
      const hash = campo === "proposte" && delta ? delta.dopo : atteso[campo];
      assert.equal(impronta(valore), hash, `${key}: cambia ${campo}`);
    }
  }
});

test("proposte: tutte le differenze revisionate appartengono al corpus congelato", () => {
  for (const key of Object.keys(proposte.casi)) assert.ok(baseline.casi[key], `Caso estraneo: ${key}`);
});
