// I posti dai mancanti: livello (importante/utile) e nome mostrato all'utente.
// Uso: node --test valigia/test/posti.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { livelloPosto, nomePosto, qualificaDelGap } from "../posti.ts";
import { capoDelGap, NOME_CATEGORIA, NOME_SOTTOCATEGORIA } from "../uscita.ts";
import { NOMI_CATEGORIA, NOMI_SOTTOCATEGORIA } from "../posti_nomi.ts";

const livello = (g: Record<string, any>, viaggioFreddo = false) =>
  livelloPosto(g, capoDelGap(g, viaggioFreddo), viaggioFreddo);

test("livello: la giacca col freddo e' importante, il maglione col freddo no", () => {
  const giacca = { tipo: "assente", category: "Outerwear", subCategories: ["Coat", "Down Jacket", "Casual Jacket", "Windbreaker"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  const maglione = { tipo: "assente", category: "Upper Body", subCategories: ["Sweater"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  assert.equal(livelloPosto(giacca, capoDelGap(giacca, true), true), "importante");
  assert.equal(livelloPosto(maglione, capoDelGap(maglione, true), true), "utile");
});

test("livello: magliette necessarie restano utili; costume e scarponi importanti; camicia elegante importante", () => {
  const maglietta = { tipo: "assente", category: "Upper Body", subCategories: ["T-Shirt"], priorita: "necessario" };
  const costume = { tipo: "assente", category: "Lower Body", subCategories: ["Swimwear"], priorita: "consigliato" };
  const scarponi = { tipo: "assente", category: "Shoes", subCategories: ["Hiking Boots"], priorita: "necessario" };
  const camicia = { tipo: "assente", category: "Upper Body", subCategories: ["Shirt"], formality: ["Formal"] };
  assert.equal(livello(maglietta), "utile");
  assert.equal(livello(costume), "importante");
  assert.equal(livello(scarponi), "importante");
  assert.equal(livello(camicia), "importante");
});

test("livello: scarpe senza freddo ne' pioggia sono utili", () => {
  const scarpe = { tipo: "assente", category: "Shoes", subCategories: ["Sneakers"], warmth_richiesto: [1, 3] };
  assert.equal(livello(scarpe), "utile");
  assert.equal(qualificaDelGap(scarpe, capoDelGap(scarpe), false), null);
});

test("livello: scarpe con la pioggia sono importanti, un accessorio col freddo pure", () => {
  const scarpe = { tipo: "assente", category: "Shoes", subCategories: ["Sneakers"], impermeabilita_richiesta: 2 };
  const guanti = { tipo: "assente", category: "Accessory", subCategories: ["Gloves"], warmth_richiesto: [3, 5] };
  assert.equal(livello(scarpe), "importante");
  assert.equal(livello(guanti), "importante");
});

test("qualifica: freddo, poi acqua, poi elegante", () => {
  const freddoAcqua = { category: "Outerwear", subCategories: ["Coat"], warmth_richiesto: [4, 5], impermeabilita_richiesta: 2 };
  const acqua = { category: "Outerwear", subCategories: ["Coat"], warmth_richiesto: [1, 2], impermeabilita_richiesta: 2 };
  const elegante = { category: "Upper Body", subCategories: ["Shirt"], formality: ["Business"] };
  assert.equal(qualificaDelGap(freddoAcqua, capoDelGap(freddoAcqua), false), "freddo");
  assert.equal(qualificaDelGap(acqua, capoDelGap(acqua), false), "acqua");
  assert.equal(qualificaDelGap(elegante, capoDelGap(elegante), false), "elegante");
});

test("nomi del mockup", () => {
  assert.deepEqual(nomePosto({ sub: null, categoria: "Outerwear" }, 1, "freddo", "it"), { nome: "Giacca invernale", aggiungi: "Aggiungi la tua" });
  assert.deepEqual(nomePosto({ sub: null, categoria: "Shoes" }, 1, "freddo", "it"), { nome: "Scarpe invernali", aggiungi: "Aggiungi le tue" });
  assert.deepEqual(nomePosto({ sub: "Cap/Hat", categoria: "Accessory" }, 1, "freddo", "it"), { nome: "Cappello caldo", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Gloves", categoria: "Accessory" }, 1, "freddo", "it"), { nome: "Guanti", aggiungi: "Aggiungi i tuoi" });
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, "freddo", "it").nome, "Maglioni caldi");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 5, null, "it").nome, "Magliette");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 1, null, "it").nome, "Maglietta");
  assert.equal(nomePosto({ sub: "Trousers", categoria: "Lower Body" }, 1, null, "it").nome, "Pantaloni");
  assert.deepEqual(nomePosto({ sub: null, categoria: "Shoes" }, 1, "freddo", "en"), { nome: "Winter shoes", aggiungi: "Add yours" });
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, "freddo", "en").nome, "Warm sweaters");
});

test("nomi: qualificatori in italiano e inglese, concordati col nome mostrato", () => {
  assert.equal(nomePosto({ sub: "Scarf", categoria: "Accessory" }, 1, "freddo", "it").nome, "Sciarpa calda");
  assert.equal(nomePosto({ sub: "Scarf", categoria: "Accessory" }, 2, "freddo", "it").nome, "Sciarpe calde");
  assert.equal(nomePosto({ sub: "Trousers", categoria: "Lower Body" }, 1, "freddo", "it").nome, "Pantaloni caldi");
  assert.equal(nomePosto({ sub: "Coat", categoria: "Outerwear" }, 2, "freddo", "it").nome, "Cappotti invernali");
  assert.equal(nomePosto({ sub: "Boots", categoria: "Shoes" }, 1, "acqua", "it").nome, "Stivali impermeabili");
  assert.equal(nomePosto({ sub: "Casual Jacket", categoria: "Outerwear" }, 1, "acqua", "it").nome, "Giacca casual impermeabile");
  assert.equal(nomePosto({ sub: "Shirt", categoria: "Upper Body" }, 1, "elegante", "it").nome, "Camicia elegante");
  assert.equal(nomePosto({ sub: "Shirt", categoria: "Upper Body" }, 2, "elegante", "it").nome, "Camicie eleganti");
  assert.equal(nomePosto({ sub: null, categoria: "Outerwear" }, 1, "acqua", "en").nome, "Waterproof jacket");
  assert.equal(nomePosto({ sub: "Shirt", categoria: "Upper Body" }, 1, "elegante", "en").nome, "Smart shirt");
  assert.equal(nomePosto({ sub: "Scarf", categoria: "Accessory" }, 1, "freddo", "en").nome, "Warm scarf");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 5, null, "en").nome, "T-shirts");
  assert.equal(nomePosto({ sub: "Gloves", categoria: "Accessory" }, 1, "freddo", "en").nome, "Gloves");
});

test("nomi: articolo di 'aggiungi' secondo genere e numero", () => {
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 1, null, "it").aggiungi, "Aggiungi il tuo");
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, null, "it").aggiungi, "Aggiungi i tuoi");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 1, null, "it").aggiungi, "Aggiungi la tua");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 2, null, "it").aggiungi, "Aggiungi le tue");
  // nome solo plurale: anche con una copia si usa il plurale
  assert.equal(nomePosto({ sub: "Trousers", categoria: "Lower Body" }, 1, null, "it").aggiungi, "Aggiungi i tuoi");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 2, null, "en").aggiungi, "Add yours");
});

test("nomi: chi lo dice gia' non si qualifica", () => {
  for (const [sub, categoria] of [["Down Jacket", "Outerwear"], ["Rain Jacket", "Outerwear"], ["Snow Boots", "Shoes"],
    ["Thermal Top", "Upper Body"], ["Thermal Bottoms", "Lower Body"], ["Ski Jacket", "Outerwear"], ["Ski Pants", "Lower Body"],
    ["Ski Suit", "Outerwear"], ["Gloves", "Accessory"], ["Umbrella", "Accessory"], ["Blazer", "Outerwear"],
    ["Dress Shoes", "Shoes"]] as const) {
    for (const lingua of ["it", "en"] as const) {
      const senza = nomePosto({ sub, categoria }, 1, null, lingua).nome;
      for (const q of ["freddo", "acqua", "elegante"] as const) {
        assert.equal(nomePosto({ sub, categoria }, 1, q, lingua).nome, senza, `${sub} ${q} ${lingua}`);
      }
    }
  }
});

test("ogni sottocategoria e categoria ha il nome in tutte e due le lingue", () => {
  assert.deepEqual(Object.keys(NOMI_SOTTOCATEGORIA).sort(), Object.keys(NOME_SOTTOCATEGORIA).sort());
  assert.deepEqual(Object.keys(NOMI_CATEGORIA).sort(), Object.keys(NOME_CATEGORIA).sort());
  const capi = [
    ...Object.keys(NOME_SOTTOCATEGORIA).map((sub) => ({ sub, categoria: "Accessory" })),
    ...Object.keys(NOME_CATEGORIA).map((categoria) => ({ sub: null, categoria })),
  ];
  for (const capo of capi) {
    for (const lingua of ["it", "en"] as const) {
      for (const copie of [1, 2]) {
        for (const q of [null, "freddo", "acqua", "elegante"] as const) {
          const r = nomePosto(capo, copie, q, lingua);
          assert.ok(r.nome.trim().length > 0, `${capo.sub ?? capo.categoria} ${lingua} ${copie} ${q}`);
          assert.match(r.nome, /^\p{Lu}/u, `${capo.sub ?? capo.categoria} maiuscola`);
          assert.ok(r.aggiungi.trim().length > 0);
        }
      }
    }
  }
});
