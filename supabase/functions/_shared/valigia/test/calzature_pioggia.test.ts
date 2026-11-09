import { test } from "node:test";
import assert from "node:assert/strict";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { strategySlots } from "../slots.ts";
import { postiApp } from "../posti.ts";

const richiesta = { slot: "calzature per la pioggia", category: "Shoes", subCategories: ["Sneakers", "Boots"],
  minWarmth: 1, maxWarmth: 2, minWaterResistance: 1, formality: ["Casual"], activityTags: ["Everyday"],
  frequency: "once", essential: true, reason: "camminare con la pioggia" };
const viaggio = { giorni: 4, lavatrice: false, attivita: ["visite in citta"], bagaglio: "bagaglio a mano" };
const meteo = { temp_min_media: 25, temp_max_media: 31, giorni_di_pioggia: 2 };
const stivali = (warmth = 3, waterResistance = 1): RigaArmadio => ({ id: "stivali", name: "Stivali medi",
  quantity: 1, ai_metadata: { category: "Shoes", subCategory: "Boots", warmth, waterResistance,
    activityTags: ["Everyday"], formality: "Casual", bulk: 2 } });

function genera(righe: RigaArmadio[], extra: Record<string, any> = {}, attivita = viaggio.attivita,
  bagaglio = viaggio.bagaglio) {
  const items = caricaArmadio(righe);
  const valigia = strategySlots(JSON.stringify([{ ...richiesta, ...extra }]), items,
    { ...viaggio, bagaglio, attivita, temp_min: 25, temp_max: 31, giorni_pioggia: 2 });
  const posti = postiApp(valigia, { capi: [], essenziali: [] },
    new Map(righe.map((g) => [String(g.id), g.quantity ?? null])),
    { armadio: items, viaggio: { ...viaggio, bagaglio, attivita }, meteo }).posti;
  return { valigia, posti, scelti: [...valigia.ideali, ...valigia.ripieghi] };
}

test("pioggia leggera: gli stivali medi posseduti sono un compromesso prima di chiedere altri capi", () => {
  const { valigia, scelti, posti } = genera([stivali()]);
  const scarpa = scelti.find((g) => g.item_id === "stivali" && g.assegnazioni?.some((a: any) =>
    a.slot === richiesta.slot && a.match === "compromesso"));
  assert.ok(scarpa, JSON.stringify(valigia));
  assert.equal(scarpa.warmth, 3);
  assert.equal(scarpa.waterResistance, 1);
  assert.ok(!posti.some((p) => p.tipo === "Shoes"), "un bisogno coperto non richiede altre scarpe");
});

test("pioggia leggera: il nome virtuale usa lo stesso compromesso ordinario senza inventare trekking", () => {
  const { valigia, posti } = genera([]);
  assert.equal(valigia.richiesti.find((r: any) => r.slot === richiesta.slot)?.capoTipico?.sub, "Boots");
  assert.ok(posti.some((p) => p.tipo === "Shoes" && p.nome === "Stivali"));
});

test("pioggia: scarpe leggere gia' adatte restano preferite al compromesso piu' caldo", () => {
  const sneakers = { ...stivali(2), id: "sneakers", ai_metadata: { ...stivali(2).ai_metadata!, subCategory: "Sneakers" } };
  const { scelti } = genera([stivali(), sneakers]);
  assert.ok(scelti.some((g) => g.item_id === "sneakers"));
  assert.ok(!scelti.some((g) => g.item_id === "stivali"));
});

test("pioggia: le sneakers senza protezione non coprono il bisogno al posto degli stivali adatti", () => {
  const sneakers = { ...stivali(2, 0), id: "sneakers", ai_metadata: { ...stivali(2, 0).ai_metadata!, subCategory: "Sneakers" } };
  const { scelti } = genera([stivali(), sneakers], {}, viaggio.attivita, "valigia grande");
  assert.ok(scelti.some((g) => g.item_id === "stivali" &&
    g.assegnazioni?.some((a: any) => a.slot === richiesta.slot)));
  assert.ok(!scelti.some((g) => g.item_id === "sneakers" &&
    g.assegnazioni?.some((a: any) => a.slot === richiesta.slot)));
});

test("pioggia: il compromesso non promuove protezione insufficiente o scarpe invernali", () => {
  for (const [warmth, wr, richiestaWr] of [[3, 0, 1], [3, 1, 2], [3, 2, 3], [4, 2, 1], [5, 2, 1]]) {
    const { scelti, posti, valigia } = genera([stivali(warmth, wr)], { minWaterResistance: richiestaWr });
    // La rete finale puo' portare comunque una scarpa: non deve chiudere questo bisogno.
    assert.ok(!scelti.some((g) => g.item_id === "stivali" &&
      g.assegnazioni?.some((a: any) => a.slot === richiesta.slot)), `${warmth}/${wr}/${richiestaWr}`);
    assert.ok(valigia.mancanti.some((g: any) => g.slot === richiesta.slot));
    assert.ok(posti.some((p) => p.tipo === "Shoes"), "la mancanza reale deve restare visibile");
  }
});

test("pioggia: la tolleranza al calore conserva gli altri vincoli e non vale all'asciutto", () => {
  for (const extra of [{ minWaterResistance: 0 }, { formality: ["Formal"] },
    { activityTags: ["Sport"] }, { coverage: ["Full"] }]) {
    const { scelti, valigia } = genera([stivali()], extra, ["visite in citta", "riunioni di lavoro"]);
    assert.ok(!scelti.some((g) => g.item_id === "stivali" &&
      g.assegnazioni?.some((a: any) => a.slot === richiesta.slot)), JSON.stringify(extra));
    assert.ok(valigia.mancanti.some((g: any) => g.slot === richiesta.slot), JSON.stringify(extra));
  }
});

test("trekking: gli stivali quotidiani non diventano scarpe tecniche col nuovo compromesso", () => {
  const { posti, valigia } = genera([stivali()], {}, ["trekking"]);
  assert.ok(valigia.richiesti.some((r: any) => r.category === "Shoes" && r.activityTags.includes("Hiking")));
  assert.ok(posti.some((p) => p.tipo === "Hiking Boots" || p.requisiti?.activityTags.includes("Hiking")),
    "gli stivali quotidiani non chiudono il bisogno tecnico");
});
