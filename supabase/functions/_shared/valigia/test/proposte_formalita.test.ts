import { test } from "node:test";
import assert from "node:assert/strict";
import { livelloPosto, postiApp } from "../posti.ts";

const camicia = { tipo: "assente", slot: "camicia elegante", category: "Upper Body",
  subCategories: ["Shirt"], formality: ["Business", "Formal"], warmth_richiesto: [1, 2] };
const capo = { sub: "Shirt", categoria: "Upper Body" };

test("proposte formali: mare e serate presentabili non rendono importante una camicia elegante", () => {
  for (const attivita of [[], ["mare", "immersioni"], ["ristoranti", "vita notturna"]]) {
    assert.equal(livelloPosto(camicia, capo, false, attivita), "utile");
  }
});

test("proposte formali: lavoro e cerimonie rendono importante il capo adatto", () => {
  for (const attivita of [["congresso"], ["cene di lavoro"], ["riunioni di lavoro"],
    ["matrimonio"], ["cerimonia di laurea"], ["cena di gala"]]) {
    assert.equal(livelloPosto(camicia, capo, false, attivita), "importante");
  }
});

test("proposte formali: freddo e pioggia restano importanti senza eventi formali", () => {
  const giacca = { category: "Outerwear", subCategories: ["Coat"], formality: ["Business"] };
  assert.equal(livelloPosto({ ...giacca, warmth_richiesto: [4, 5] },
    { sub: "Coat", categoria: "Outerwear" }, true, ["visite in citta"]), "importante");
  assert.equal(livelloPosto({ ...giacca, impermeabilita_richiesta: 1, warmth_richiesto: [1, 2] },
    { sub: "Coat", categoria: "Outerwear" }, false, ["visite in citta"]), "importante");
});

test("proposte formali: il matrimonio di un'altra tappa non promuove un bisogno locale", () => {
  const valigia = { mancanti_canonici: [{ ...camicia, tappe: ["Mare"] }],
    richiesti: [{ ...camicia, minWarmth: 1, maxWarmth: 2, frequency: "once" }],
    essenziali: [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }] };
  const viaggio = { giorni: 6, attivita: [], tappe: [
    { nome: "Mare", giorni: 3, attivita: ["mare"] },
    { nome: "Festa", giorni: 3, attivita: ["matrimonio"] },
  ] };
  const opzioni = { viaggio, armadio: [] };
  const prima = structuredClone(valigia);
  const a = postiApp(valigia, { capi: [], essenziali: [] }, new Map(), opzioni).posti;
  assert.equal(a.find((p) => p.tipo === "Shirt")?.livello, "utile");
  const b = postiApp({ ...valigia, mancanti_canonici: [{ ...camicia, tappe: ["Festa"] }] },
    { capi: [], essenziali: [] }, new Map(), opzioni).posti;
  assert.equal(b.find((p) => p.tipo === "Shirt")?.livello, "importante");
  assert.deepEqual(valigia, prima);
});
