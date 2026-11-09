// scheda.ts contro scheda_capo.py del bench: prompt, domande e stato di Jev,
// pulizia delle risposte di GPT e dubbi, su casi scritti a mano e su risposte
// vere di GPT e Jev. Uso: node --test test/oracolo_scheda.test.ts
// (ORACOLO_SCHEDA=file per l'oracolo intero: esporta_oracolo.py scheda FILE)
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import * as tassonomia from "../../valigia/tassonomia.ts";
import { domandeJev, dubbi, leggiJson, normalizza, promptNome, promptScan, pulisciNome, statoJev } from "../scheda.ts";

const file = process.env.ORACOLO_SCHEDA ?? new URL("./oracolo_scheda_campione.json", import.meta.url).pathname;
const o = JSON.parse(readFileSync(file, "utf8"));
// JSON di Python e di JavaScript scrivono 1.0 e 1 in modo diverso: si confronta il valore.
const json = (x: unknown) => JSON.parse(JSON.stringify(x));

test("l'oracolo e' stato generato con la stessa copia del catalogo dell'app", () => {
  // esporta_oracolo.py scheda scrive il sha256 del catalogo.json del bench (copia identica).
  const copia = readFileSync(new URL("../../catalogo/catalogo.json", import.meta.url));
  assert.equal(o.catalogo_sha256, createHash("sha256").update(copia).digest("hex"));
});

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

const daSub = (nome: string, sub: string, cat: string) =>
  normalizza({ name: nome, subCategory: sub, category: cat }, nome);

test("nome_muta_da_sub_diventa_wetsuit", () => {
  const z = daSub("Muta corta", "Other", "Accessory");
  assert.equal(z.metadata.subCategory, "Wetsuit");
  assert.equal(z.metadata.category, tassonomia.categoriaDi("Wetsuit"));
  assert.ok(!z.corretti.includes("subCategory"));
});

test("nome_pile_leggero_diventa_fleece", () => {
  const z = daSub("Pile leggero", "Windbreaker", "Outerwear");
  assert.equal(z.metadata.subCategory, "Fleece");
  assert.equal(z.metadata.category, tassonomia.categoriaDi("Fleece"));
  assert.ok(!z.corretti.includes("subCategory"));
});

test("giacca_in_pile_resta_giacca", () => {
  const z = daSub("Giacca in pile", "Windbreaker", "Outerwear");
  assert.equal(z.metadata.subCategory, "Windbreaker");
});

test("prompt_scan_ha_i_due_casi", () => {
  const p = promptScan();
  assert.ok(p.includes("A person is the main subject"));
  assert.ok(p.includes("No person as the main subject"));
  assert.ok(!p.includes("IGNORE any clothing items in the background"));
});
