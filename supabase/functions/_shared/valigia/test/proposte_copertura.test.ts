import { test } from "node:test";
import assert from "node:assert/strict";
import { armadioTipico } from "../armadio_tipico.ts";
import { strategySlots } from "../slots.ts";
import { strategySlotsMultitappa } from "../tappe.ts";
import { analizzaFabbisogni } from "../fabbisogni.ts";
import { postiApp } from "../posti.ts";

const bisogno = { slot: "giacca per il lavoro", category: "Outerwear", subCategories: ["Blazer"],
  minWarmth: 2, maxWarmth: 3, formality: ["Business"], frequency: "once" };
const meteo = { temp_min_media: 14, temp_max_media: 22, giorni_di_pioggia: 0 };
const viaggio = { giorni: 4, lavatrice: false, bagaglio: "valigia grande",
  attivita: ["riunioni di lavoro"], destinazione: { nome: "Congresso" } };

function singola(attivita = viaggio.attivita) {
  const items = armadioTipico().filter((g) => g.sub_category !== "Blazer");
  const valigia = strategySlots(JSON.stringify([bisogno]), items, { giorni: 4, lavatrice: false,
    attivita, bagaglio: viaggio.bagaglio, temp_min: 14, temp_max: 22 });
  return { items, valigia };
}

test("proposte: il ripiego gia' accettato per il lavoro evita un blazer aggiuntivo", () => {
  const { items, valigia } = singola();
  const propri = [...valigia.ideali, ...valigia.ripieghi];
  assert.ok(propri.some((g) => g.subCategory === "Coat" && g.assegnazioni?.some((a: any) =>
    a.slot === bisogno.slot && a.match === "ripiego")), "il generatore deve aver accettato un ripiego");
  const prima = structuredClone(valigia);
  const { posti } = postiApp(valigia, { capi: [], essenziali: [] }, new Map(), { armadio: items, viaggio, meteo });
  assert.ok(!posti.some((p) => p.tipo === "Blazer"), "il bisogno coperto non deve tornare come proposta");
  assert.deepEqual(valigia, prima);
});

test("proposte: il ripiego di lavoro resta utilizzabile nelle tappe compatibili", () => {
  const items = armadioTipico().filter((g) => g.sub_category !== "Blazer");
  const tappe = [
    { destinazione: "Alfa", giorni: 3, attivita: ["riunioni di lavoro"], meteo },
    { destinazione: "Beta", giorni: 3, attivita: ["congresso"], meteo: { ...meteo, temp_max_media: 20 } },
  ];
  const v = { ...viaggio, giorni: 6, attivita: [], tappe: tappe.map((t) =>
    ({ nome: t.destinazione, giorni: t.giorni, attivita: t.attivita })) };
  const valigia = strategySlotsMultitappa(JSON.stringify([bisogno]), items,
    { sc: v, geo: { per_tappa: tappe }, bagaglio: v.bagaglio });
  assert.ok([...valigia.ideali, ...valigia.ripieghi].some((g) => g.subCategory === "Coat"));
  const prima = structuredClone(valigia);
  const r = analizzaFabbisogni(valigia, items, v,
    { _per_tappa: tappe.map((t) => ({ destinazione: t.destinazione, ...t.meteo })) });
  assert.ok(!r.mancanti.some((f) => f.vincoli.slot === "strato formale"));
  assert.deepEqual(valigia, prima);
});

test("proposte: un capospalla per un uso diverso non copre automaticamente il bisogno formale", () => {
  const { items, valigia } = singola(["visite in citta"]);
  // La selezione e' avvenuta per una giacca quotidiana, senza una richiesta formale accettata.
  const quotidiana = structuredClone(valigia);
  quotidiana.richiesti = [{ ...bisogno, subCategories: ["Coat"], formality: ["Casual", "Smart Casual"] }];
  const r = analizzaFabbisogni(quotidiana, items, viaggio, meteo);
  assert.ok(r.mancanti.some((f) => f.vincoli.slot === "strato formale"));
});

test("proposte: il trench da lavoro non chiude la richiesta di uno strato caldo", () => {
  const { items, valigia } = singola();
  const r = analizzaFabbisogni(valigia, items, viaggio,
    { ...meteo, temp_min_media: -5, temp_max_media: 3, temp_min_assoluta: -8 });
  assert.ok(r.mancanti.some((f) => f.vincoli.category === "Outerwear" &&
    (f.vincoli.warmth_richiesto?.[0] ?? 0) >= 4));
});

import { servePerTappa } from "../tappe.ts";
function analizzaConPreferenzaAccettata(tipo: string, attivita: string[], extra: Record<string, any> = {}) {
  const g = { ...armadioTipico().find((g) => g.sub_fine === tipo)!, ...extra };
  assert.ok(g.id);
  const t = { destinazione: "Unica", giorni: 4, attivita, meteo: { ...meteo, giorni_di_pioggia: 2 } };
  const capo = { item_id: g.id, category: g.category, subCategory: g.sub_category,
    warmth: g.warmth, formality: g.formality, coverage: g.coverage, waterResistance: g.water_resistance,
    quantita: 1, tappe: [t.destinazione] };
  const mancanti: Record<string, any>[] = [];
  servePerTappa(t, [capo], [g], new Set([g.id]), 0, false, null, false, mancanti, () => true);
  return mancanti;
}

test("proposte: un ripiego accettato non scavalca la protezione minima dalla pioggia", () => {
  const m = analizzaConPreferenzaAccettata("Rain Jacket", [], { water_resistance: 0 });
  assert.ok(m.some((g) => g.slot === "protezione dalla pioggia"));
});

test("proposte: un ripiego accettato non scavalca i tag tecnici richiesti", () => {
  const m = analizzaConPreferenzaAccettata("T-Shirt", ["trekking"], { activity_tags: ["Everyday"] });
  assert.ok(m.some((g) => g.slot === "maglietta tecnica"));
});

test("proposte: un ripiego troppo caldo non copre la richiesta formale di una tappa mite", () => {
  const m = analizzaConPreferenzaAccettata("Coat", ["riunioni di lavoro"], { warmth: 5 });
  assert.ok(m.some((g) => g.slot === "strato formale"));
});

test("proposte: un ripiego quotidiano non scavalca il ruolo tecnico delle scarpe", () => {
  const m = analizzaConPreferenzaAccettata("Boots", ["trekking"], { activity_tags: ["Everyday"], warmth: 2 });
  assert.ok(m.some((g) => g.ruolo === "trekking"));
});
