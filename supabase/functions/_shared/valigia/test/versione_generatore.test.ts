// La risposta di pack-trip porta la versione del generatore, fuori dalla valigia.
// Uso: node --test --experimental-strip-types --no-warnings _shared/valigia/test/versione_generatore.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { campoVersione, VERSIONE_GENERATORE } from "../costanti_app.ts";

test("versione_generatore vale 2026-11-08", () => {
  assert.equal(VERSIONE_GENERATORE, "2026-11-08");
  assert.deepEqual(campoVersione(), { versione_generatore: "2026-11-08" });
});

test("pack-trip la mette nella risposta, accanto e non dentro la valigia", () => {
  const src = readFileSync(new URL("../../../pack-trip/index.ts", import.meta.url), "utf8");
  const corpo = src.slice(src.indexOf("risposta = json(200, {"));
  assert.match(corpo.slice(0, corpo.indexOf("});")), /\.\.\.campoVersione\(\)/);
});
