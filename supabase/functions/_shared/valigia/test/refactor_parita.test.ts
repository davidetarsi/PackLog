// Il contratto originale resta intatto; i cambiamenti di policy revisionati sono
// delta separati, ciascuno ancorato al risultato precedente. Il prompt resta congelato.
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

const motore = JSON.parse(readFileSync(process.env.PACKING_ENGINE_CHANGES
  ?? new URL("./baseline_motore_migliorato.json", import.meta.url), "utf8"));
const mare = JSON.parse(readFileSync(process.env.PACKING_SUMMER_CHANGES
  ?? new URL("./baseline_quantita_mare.json", import.meta.url), "utf8"));

for (const modo of modiArmadio) test(`regressioni: contratto originale e delta revisionati con armadio ${modo}`, () => {
  assert.equal(baseline.base, "b9f6404b8c146963d3419225130d76b30d20335e");
  assert.equal(baseline.input, impronta(casi), "Input diversi da quelli congelati");
  assert.equal(proposte.base, "99591feb5484e3398a5f826d0d5c4ab312d1c22f");
  assert.equal(proposte.input, baseline.input, "Differenze proposte riferite ad altri input");
  assert.equal(motore.base, "8f99430a10c77c8394ae366dae60754f2ffb59e2");
  assert.equal(motore.input, baseline.input, "Differenze del motore riferite ad altri input");
  assert.equal(mare.base, "329cc4fcb6669576eb5af8bdbb701c272d0b81af");
  assert.equal(mare.input, baseline.input, "Differenze mare riferite ad altri input");
  for (const c of casi) {
    const key = chiaveCaso(c, modo), atteso = baseline.casi[key];
    assert.ok(atteso, `Caso non congelato: ${key}`);
    const delta = proposte.casi[key];
    if (delta) {
      assert.equal(delta.prima, atteso.proposte, `${key}: baseline delle proposte alterata`);
      assert.ok(delta.motivi.length > 0 && delta.motivi.every((m: string) =>
        ["ripiego_assegnato_compatibile", "formalita_senza_occasione", "ombrello_utile",
          "scarpette_da_scoglio", "nome_concreto_pioggia", "foulard_leggero"].includes(m)), `${key}: differenza non revisionata`);
      assert.notEqual(delta.dopo, delta.prima, `${key}: eccezione senza cambiamenti`);
    }
    const cambiato = motore.casi[key];
    if (cambiato) {
      assert.ok(cambiato.motivi.length > 0 && cambiato.motivi.every((m: string) =>
        ["passeggiate_non_tecniche", "scarpa_ordinaria_pioggia", "cammino_tecnico_rotazione"].includes(m)), `${key}: policy non revisionata`);
      assert.ok(Object.keys(cambiato.campi).length > 0, `${key}: delta vuoto`);
      assert.ok(!("prompt" in cambiato.campi), `${key}: il prompt deve restare invariato`);
      for (const [campo, revisione] of Object.entries(cambiato.campi) as [string, any][]) {
        assert.ok(campo in atteso, `${key}: campo estraneo ${campo}`);
        const prima = campo === "proposte" && delta ? delta.dopo : atteso[campo];
        assert.equal(revisione.prima, prima, `${key}: baseline di ${campo} alterata`);
        assert.notEqual(revisione.dopo, revisione.prima, `${key}: eccezione senza cambiamenti`);
      }
    }
    const estivo = mare.casi[key];
    if (estivo) {
      assert.ok(estivo.motivi.length > 0 && estivo.motivi.every((m: string) =>
        ["essenziali_mare_caldo", "pantaloni_da_sera_caldo"].includes(m)), `${key}: policy mare non revisionata`);
      assert.ok(Object.keys(estivo.campi).length > 0 && !("prompt" in estivo.campi), `${key}: delta mare non valido`);
      for (const [campo, revisione] of Object.entries(estivo.campi) as [string, any][]) {
        assert.ok(campo in atteso, `${key}: campo estraneo ${campo}`);
        const originale = campo === "proposte" && delta ? delta.dopo : atteso[campo];
        assert.equal(revisione.prima, cambiato?.campi[campo]?.dopo ?? originale, `${key}: baseline precedente alterata`);
        assert.notEqual(revisione.dopo, revisione.prima, `${key}: eccezione senza cambiamenti`);
      }
    }
    for (const [campo, valore] of Object.entries(riproduciCaso(c, modo))) {
      const prima = campo === "proposte" && delta ? delta.dopo : atteso[campo];
      const hash = estivo?.campi[campo]?.dopo ?? cambiato?.campi[campo]?.dopo ?? prima;
      assert.equal(impronta(valore), hash, `${key}: cambia ${campo}`);
    }
  }
});

test("tutti i delta revisionati appartengono al corpus congelato", () => {
  for (const key of [...Object.keys(proposte.casi), ...Object.keys(motore.casi), ...Object.keys(mare.casi)]) {
    assert.ok(baseline.casi[key], `Caso estraneo: ${key}`);
  }
});
