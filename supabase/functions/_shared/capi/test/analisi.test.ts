// analisi.ts con GPT e Jev finti: cosa si manda, cosa torna, cosa succede
// quando un servizio non risponde. Uso: node --test test/analisi.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { type ChiediGpt, FOTO, NOME, RispostaIlleggibile, schedaDaNome, schedeDaFoto } from "../analisi.ts";
import { domandeJev, MAX_CAPI_SCAN, promptNome, promptScan } from "../scheda.ts";
import type { ChiediJev } from "../../valigia/jev.ts";

const pile = { name: "pile blu", category: "Outerwear", subCategory: "Fleece", warmth: 3, formality: "Casual",
  activityTags: ["Hiking"], waterResistance: 0, bulk: 2 };
const sicuro = (v: string) => ({ type: "choice", choice: v, probabilities: { [v]: 0.95 } });
const jevSicuro: ChiediJev = async () => ({
  answers: { subCategory: sicuro("Fleece"), warmth: sicuro("4"), waterResistance: sicuro("0"), formality: sicuro("Casual") },
});

function gptFinto(risposte: string[], chiamate: unknown[][]): ChiediGpt {
  return async (contenuto, opzioni) => {
    chiamate.push([contenuto, opzioni]);
    return risposte.shift() ?? "";
  };
}

test("dal nome: prompt col nome pulito, categoria dalla sottocategoria, dubbio di Jev", async () => {
  const chiamate: unknown[][] = [];
  const stati: unknown[] = [];
  const jev: ChiediJev = async (stato, domande) => {
    stati.push(stato);
    assert.deepEqual(domande, domandeJev());
    return jevSicuro(stato, domande);
  };
  const r = await schedaDaNome("  pile   blu ", { gpt: gptFinto(["```json\n" + JSON.stringify(pile) + "\n```"], chiamate), jev });
  assert.deepEqual(chiamate, [[promptNome("pile blu"), NOME]]);
  assert.deepEqual(stati, [{ item_name: "pile blu", note: (stati[0] as any).note }]);
  assert.equal(r.items.length, 1);
  assert.equal(r.items[0].metadata.category, "Upper Body");
  assert.equal(r.items[0].app_category, "vestiti");
  assert.deepEqual(r.items[0].dubbi, [{ campo: "warmth", valore: 3, jev: 4, sicurezza: 0.95 }]);
  assert.deepEqual(r.note_tecniche, []);
});

test("dal nome: una risposta illeggibile si richiede una volta, due no", async () => {
  const chiamate: unknown[][] = [];
  const r = await schedaDaNome("pile", { gpt: gptFinto(["non so", JSON.stringify(pile)], chiamate), jev: null });
  assert.equal(chiamate.length, 2);
  assert.equal(r.items[0].metadata.subCategory, "Fleece");
  await assert.rejects(schedaDaNome("pile", { gpt: gptFinto(["no", "[1]"], []), jev: null }), RispostaIlleggibile);
});

test("Jev che non risponde: la scheda si fa lo stesso, con la nota", async () => {
  const jev: ChiediJev = async () => {
    throw new Error("Jev 503: giu'");
  };
  const r = await schedaDaNome("scarpe", { gpt: gptFinto([JSON.stringify({ category: "Shoes", subCategory: "Sneakers" })], []), jev });
  assert.deepEqual(r.note_tecniche, ["jev: Jev 503: giu'"]);
  // senza Jev restano i campi che la pulizia ha dovuto riempire
  assert.deepEqual(r.items[0].dubbi.map((d) => d.campo), ["warmth", "waterResistance", "formality"]);
});

test("dalla foto: immagine nel messaggio, un capo o tanti, testo libero = nessun capo", async () => {
  const chiamate: unknown[][] = [];
  const r = await schedeDaFoto("QUJD", { gpt: gptFinto([JSON.stringify([pile, { ...pile, subCategory: "Jeans" }])], chiamate), jev: jevSicuro });
  assert.deepEqual(chiamate[0], [[
    { type: "text", text: promptScan() },
    { type: "image_url", image_url: { url: "data:image/png;base64,QUJD", detail: "high" } },
  ], { max_tokens: FOTO.max_tokens, temperature: FOTO.temperature }]);
  assert.deepEqual(r.items.map((c) => [c.metadata.category, c.metadata.subCategory]),
    [["Upper Body", "Fleece"], ["Lower Body", "Jeans"]]);
  assert.equal((await schedeDaFoto("x", { gpt: gptFinto([JSON.stringify(pile)], []), jev: null })).items.length, 1);
  assert.deepEqual((await schedeDaFoto("x", { gpt: gptFinto(["Non vedo vestiti."], []), jev: null })).items, []);
  const tanti = JSON.stringify(Array(20).fill(pile));
  assert.equal((await schedeDaFoto("x", { gpt: gptFinto([tanti], []), jev: null })).items.length, MAX_CAPI_SCAN);
});
