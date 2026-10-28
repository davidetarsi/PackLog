// scheda.ts contro scheda_capo.py del bench: prompt, domande e stato di Jev,
// pulizia delle risposte di GPT e dubbi, su casi scritti a mano e su risposte
// vere di GPT e Jev. Uso: node --test test/oracolo_scheda.test.ts
// (ORACOLO_SCHEDA=file per l'oracolo intero: esporta_oracolo.py scheda FILE)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { domandeJev, dubbi, leggiJson, normalizza, promptNome, promptScan, pulisciNome, statoJev } from "../scheda.ts";

const file = process.env.ORACOLO_SCHEDA ?? new URL("./oracolo_scheda_campione.json", import.meta.url).pathname;
const o = JSON.parse(readFileSync(file, "utf8"));
// JSON di Python e di JavaScript scrivono 1.0 e 1 in modo diverso: si confronta il valore.
const json = (x: unknown) => JSON.parse(JSON.stringify(x));

test("prompt e domande di Jev", () => {
  assert.equal(promptScan(), o.prompt_scan);
  assert.deepEqual(json(domandeJev()), o.domande_jev);
  for (const c of o.prompt_nome) assert.equal(promptNome(c.nome), c.atteso, c.nome);
  for (const c of o.pulisci_nome) assert.equal(pulisciNome(c.nome), c.atteso, String(c.nome));
  for (const c of o.leggi_json) assert.deepEqual(leggiJson(c.testo), c.atteso, c.testo);
});

test(`pulizia e dubbi (${o.casi.length} casi)`, () => {
  for (const c of o.casi) {
    const z = normalizza(c.grezzo, c.nome);
    const chi = JSON.stringify([c.grezzo, c.nome]);
    assert.deepEqual(json(z), c.atteso, chi);
    for (const d of c.dubbi) assert.deepEqual(json(dubbi(z, d.jev)), d.atteso, chi + JSON.stringify(d.jev));
    if (c.stato_jev) {
      assert.deepEqual(json(statoJev(z.metadata, true)), c.stato_jev[0], chi);
      assert.deepEqual(json(statoJev(z.metadata, false)), c.stato_jev[1], chi);
    }
  }
});
