// Criteri fissati prima del giro: controlli deterministici, senza nuove chiamate al modello.
import { test } from "node:test";
import assert from "node:assert/strict";
import { armadioTipico } from "../armadio_tipico.ts";
import { strategySlots } from "../slots.ts";
import { postiApp } from "../posti.ts";
import { motiviValigia } from "../motivi.ts";

const casi = [
  { nome: "Riunioni e pioggia", giorni: 4, min: 12, max: 19, pioggia: 3, attivita: ["riunioni di lavoro"],
    sub: "Shirt", category: "Upper Body", formality: ["Business", "Formal"], necessario: true },
  { nome: "Passeggiate temperate", giorni: 6, min: 18, max: 25, pioggia: 0, attivita: ["escursioni leggere"],
    sub: "Hiking Boots", category: "Shoes", necessario: true },
  { nome: "Sentieri di montagna", giorni: 5, min: 10, max: 20, pioggia: 0, attivita: ["trekking"],
    sub: "Hiking Boots", category: "Shoes", necessario: true },
  { nome: "Settimana al mare", giorni: 7, min: 24, max: 31, pioggia: 0, attivita: ["mare"],
    sub: "Swimwear", category: "Lower Body", necessario: true },
  { nome: "Sport sulla neve", giorni: 5, min: -9, max: -2, pioggia: 0, attivita: ["sci"],
    sub: "Ski Pants", category: "Lower Body", necessario: true },
  { nome: "Immersioni tropicali", giorni: 6, min: 25, max: 30, pioggia: 1, attivita: ["immersioni"],
    sub: "Wetsuit", category: "Lower Body", necessario: false },
];

for (const c of casi) for (const modo of ["vuoto", "parziale", "completo"] as const) {
  test(`scenari proposte: ${c.nome}, armadio ${modo}`, () => {
    const tutti = armadioTipico();
    const items = modo === "vuoto" ? [] : modo === "parziale" ? tutti.filter((_, i) => i % 2 === 0) : tutti;
    const giorni = c.giorni, attivita = c.attivita, lavatrice = false;
    const viaggio = { giorni, attivita, lavatrice, bagaglio: "valigia grande", destinazione: { nome: c.nome } };
    const meteo = { temp_min_media: c.min, temp_max_media: c.max, temp_min_assoluta: c.min - 2, giorni_di_pioggia: c.pioggia };
    const valigia = strategySlots(JSON.stringify([{ slot: "funzione specifica", category: c.category,
      subCategories: [c.sub], minWarmth: c.min < 0 ? 3 : 1, maxWarmth: 5,
      formality: c.formality ?? [], activityTags: [], minWaterResistance: 0, frequency: "occasional" }]),
      items, { giorni, attivita, lavatrice, bagaglio: viaggio.bagaglio,
        temp_min: c.min, temp_max: c.max, temp_min_assoluta: c.min - 2, giorni_pioggia: c.pioggia });
    const prima = structuredClone(valigia);
    const motivi = motiviValigia({ scenario: { ...viaggio, destinazione: c.nome }, meteo, slots: valigia },
      Object.fromEntries(items.map((g) => [g.id, g.activity_tags])));
    const { posti } = postiApp(valigia, motivi as any, new Map(items.map((g) => [g.id, g.copie])),
      { viaggio, meteo, armadio: items });
    assert.deepEqual(valigia, prima);
    assert.equal(new Set(posti.map((p) => p.id)).size, posti.length, "identita' univoche");
    assert.ok(posti.every((p) => Number.isInteger(p.copie) && p.copie > 0));
    if (c.necessario) {
      const scelti = new Set([...valigia.ideali, ...valigia.ripieghi].map((g) => g.item_id));
      const coperto = items.some((g) => scelti.has(g.id) && (g.sub_fine === c.sub || g.sub_category === c.sub));
      assert.ok(coperto || posti.some((p) => p.tipo === c.sub && p.livello === "importante"),
        `${c.sub}: il bisogno deve essere coperto da un capo posseduto o da una proposta`);
    }
    if (modo === "vuoto") {
      const specifico = posti.find((p) => p.tipo === c.sub);
      if (c.necessario) assert.equal(specifico?.livello, "importante", c.sub);
      else if (specifico) assert.equal(specifico.livello, "utile", c.sub);
    }
    if (c.sub === "Swimwear") assert.ok(!posti.some((p) => p.tipo === "Ski Pants"));
    if (c.sub === "Wetsuit") assert.ok(!posti.some((p) => p.tipo === "Wetsuit" && p.livello === "importante"));
  });
}
