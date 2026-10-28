// analisi.ts con modello e Jev finti: cosa si manda, cosa torna, cosa succede
// quando un servizio non risponde. Uso: node --test test/analisi.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  type ChiediModello, MAX_TOKENS_FOTO, MAX_TOKENS_NOME, RispostaIlleggibile, schedaDaNome, schedeDaFoto,
} from "../analisi.ts";
import { domandeJev, MAX_CAPI_SCAN, promptNome, promptScan } from "../scheda.ts";
import type { ChiediJev } from "../../valigia/jev.ts";

const pile = { name: "pile blu", category: "Outerwear", subCategory: "Fleece", warmth: 3, formality: "Casual",
  activityTags: ["Hiking"], waterResistance: 0, bulk: 2 };
const sicuro = (v: string) => ({ type: "choice", choice: v, probabilities: { [v]: 0.95 } });
const jevSicuro: ChiediJev = async () => ({
  answers: { subCategory: sicuro("Fleece"), warmth: sicuro("4"), waterResistance: sicuro("0"), formality: sicuro("Casual") },
});

function modelloFinto(risposte: string[], chiamate: unknown[][]): ChiediModello {
  return async (contenuto, maxTokens) => {
    chiamate.push([contenuto, maxTokens]);
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
  const r = await schedaDaNome("  pile   blu ", { modello: modelloFinto(["```json\n" + JSON.stringify(pile) + "\n```"], chiamate), jev });
  assert.deepEqual(chiamate, [[promptNome("pile blu"), MAX_TOKENS_NOME]]);
  assert.deepEqual(stati, [{ item_name: "pile blu", note: (stati[0] as any).note }]);
  assert.equal(r.items.length, 1);
  assert.equal(r.items[0].metadata.category, "Upper Body");
  assert.equal(r.items[0].app_category, "vestiti");
  assert.deepEqual(r.items[0].dubbi, [{ campo: "warmth", valore: 3, jev: 4, sicurezza: 0.95 }]);
  assert.deepEqual(r.note_tecniche, []);
});

test("dal nome: una risposta illeggibile si richiede una volta, due no", async () => {
  const chiamate: unknown[][] = [];
  const r = await schedaDaNome("pile", { modello: modelloFinto(["non so", JSON.stringify(pile)], chiamate), jev: null });
  assert.equal(chiamate.length, 2);
  assert.equal(r.items[0].metadata.subCategory, "Fleece");
  await assert.rejects(schedaDaNome("pile", { modello: modelloFinto(["no", "[1]"], []), jev: null }), RispostaIlleggibile);
});

test("Jev che non risponde: la scheda si fa lo stesso, con la nota", async () => {
  const jev: ChiediJev = async () => {
    throw new Error("Jev 503: giu'");
  };
  const r = await schedaDaNome("scarpe", { modello: modelloFinto([JSON.stringify({ category: "Shoes", subCategory: "Sneakers" })], []), jev });
  assert.deepEqual(r.note_tecniche, ["jev: Jev 503: giu'"]);
  // senza Jev restano i campi che la pulizia ha dovuto riempire
  assert.deepEqual(r.items[0].dubbi.map((d) => d.campo), ["warmth", "waterResistance", "formality"]);
});

test("dalla foto: immagine nel messaggio, un capo o tanti, testo libero = nessun capo", async () => {
  const chiamate: unknown[][] = [];
  const r = await schedeDaFoto("QUJD", { modello: modelloFinto([JSON.stringify([pile, { ...pile, subCategory: "Jeans" }])], chiamate), jev: jevSicuro });
  assert.deepEqual(chiamate[0], [[
    { type: "image", source: { type: "base64", media_type: "image/jpeg", data: "QUJD" } },
    { type: "text", text: promptScan() },
  ], MAX_TOKENS_FOTO]);
  assert.deepEqual(r.items.map((c) => [c.metadata.category, c.metadata.subCategory]),
    [["Upper Body", "Fleece"], ["Lower Body", "Jeans"]]);
  assert.equal((await schedeDaFoto("x", { modello: modelloFinto([JSON.stringify(pile)], []), jev: null })).items.length, 1);
  assert.deepEqual((await schedeDaFoto("x", { modello: modelloFinto(["Non vedo vestiti."], []), jev: null })).items, []);
  const tanti = JSON.stringify(Array(20).fill(pile));
  assert.equal((await schedeDaFoto("x", { modello: modelloFinto([tanti], []), jev: null })).items.length, MAX_CAPI_SCAN);
});

test("in inglese: il nome dallo scan e le note di Jev in inglese, il resto uguale", async () => {
  assert.equal(promptScan("it"), promptScan());
  assert.equal(promptNome("felpa", "it"), promptNome("felpa"));
  const scan = promptScan("en");
  assert.match(scan, /Short descriptive name in English, e\.g\. "Leather jacket"/);
  assert.doesNotMatch(scan, /in Italian/);
  // Il colore resta la parola italiana della tavolozza: la traduce l'app.
  assert.match(scan, /"baseColor": string \(ONE OF: "Bianco", "Nero"/);
  assert.match(promptNome("hoodie", "en"), /in English: "hoodie"/);
  assert.doesNotMatch(promptNome("hoodie", "en"), /in Italian/);

  const chiamate: unknown[][] = [];
  const stati: Record<string, unknown>[] = [];
  const jev: ChiediJev = async (stato) => {
    stati.push(stato as Record<string, unknown>);
    return { answers: {} };
  };
  await schedeDaFoto("aGVsbG8=", { modello: modelloFinto([JSON.stringify([pile])], chiamate), jev }, "en");
  const testo = (chiamate[0][0] as { type: string; text?: string }[]).find((b) => b.type === "text")!.text;
  assert.equal(testo, scan);
  assert.match(String(stati[0].note), /written in English by another model/);

  await schedaDaNome("hoodie", { modello: modelloFinto([JSON.stringify(pile)], chiamate), jev }, "en");
  assert.equal(chiamate[1][0], promptNome("hoodie", "en"));
  assert.match(String(stati[1].note), /^Name typed by the user, in English,/);
});
