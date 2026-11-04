// I mancanti della fase 1 vanno alle tappe di cui parlano, come tappe_del_mancante del bench.
// Uso: node --test test/tappe_mancanti.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { tappeDelMancante } from "../tappe.ts";

const TAPPE = [{ destinazione: "Reykjavik", attivita: ["escursioni leggere", "terme"] },
  { destinazione: "Amsterdam", attivita: ["visite in citta", "vita notturna"] },
  { destinazione: "Lisbona", attivita: ["visite in citta"] }];

test("le terme di Reykjavik non finiscono su Lisbona", () => {
  assert.deepEqual(tappeDelMancante({ slot: "Calzature per le terme", reason: "Per le terme servono calzature che si bagnano." }, TAPPE), ["Reykjavik"]);
  assert.deepEqual(tappeDelMancante({ slot: "Strato caldo", reason: "Per le serate fresche a Lisbona." }, TAPPE), ["Lisbona"]);
  assert.deepEqual(tappeDelMancante({ slot: "Giacca leggera", reason: "Per le visite." }, TAPPE), []);
  assert.deepEqual(tappeDelMancante({ slot: "spalle coperte" }, TAPPE), []);
});

import { strategySlotsMultitappa } from "../tappe.ts";
import { armadioTipico } from "../armadio_tipico.ts";
import { postiApp, mancantiDelleTappe } from "../posti.ts";
import type { Capo } from "../capo.ts";

const CALDA = { destinazione: "Porto caldo", giorni: 4, attivita: ["visite in citta"],
  meteo: { temp_min_media: 24, temp_max_media: 31, temp_min_assoluta: 23, giorni_di_pioggia: 0 } };
const FREDDA = { destinazione: "Monte freddo", giorni: 3, attivita: ["sci"],
  meteo: { temp_min_media: -8, temp_max_media: -1, temp_min_assoluta: -10, giorni_di_pioggia: 0 } };
function generaTappe(items: Capo[] = [], tappe = [CALDA, FREDDA], lavatrice = false) {
  const viaggio = { giorni: tappe.reduce((n, t) => n + t.giorni, 0), attivita: [], lavatrice,
    bagaglio: "valigia grande", tappe: tappe.map((t) => ({ nome: t.destinazione, giorni: t.giorni, attivita: t.attivita })) };
  const valigia = strategySlotsMultitappa("[]", items, { sc: viaggio, geo: { per_tappa: tappe }, bagaglio: viaggio.bagaglio });
  const { posti } = postiApp(valigia, { capi: [], essenziali: [] }, new Map(),
    { viaggio, meteo: { _per_tappa: tappe.map((t) => ({ destinazione: t.destinazione, ...t.meteo })) }, armadio: items });
  return { valigia, posti, mancanti: mancantiDelleTappe(valigia, items, viaggio,
    { _per_tappa: tappe.map((t) => ({ destinazione: t.destinazione, ...t.meteo })) }) };
}

test("tappe vuote: la tappa fredda conserva gli strati mancanti e i pantaloni da neve", () => {
  const { mancanti, posti } = generaTappe();
  const medi = mancanti.filter((g: any) => g.category === "Upper Body" && g.tappe.includes(FREDDA.destinazione));
  assert.ok(medi.length > 0, "gli strati della tappa fredda sono persi quando non ci sono candidati");
  assert.ok(medi.some((g: any) => g.copie_minime >= 2), "due strati richiesti non diventano un solo capo");
  assert.ok(posti.some((p) => p.tipo === "Ski Pants"));
  assert.ok(posti.some((p) => p.requisiti?.minWarmth && p.requisiti.minWarmth >= 3 && p.copie >= 2));
});

test("tappe: una tappa senza sci non eredita i pantaloni da neve dell'altra", () => {
  const { mancanti } = generaTappe();
  const sci = mancanti.filter((g: any) => g.subCategories.includes("Ski Pants"));
  assert.ok(sci.length > 0);
  assert.ok(sci.every((g: any) => g.tappe.length === 1 && g.tappe[0] === FREDDA.destinazione));
});

test("tappe: l'ordine non cambia i bisogni e le quantita' delle proposte", () => {
  const normalizza = (ps: ReturnType<typeof generaTappe>["posti"]) => ps.map((p) => [p.id, p.copie]).sort();
  assert.deepEqual(normalizza(generaTappe().posti), normalizza(generaTappe([], [FREDDA, CALDA]).posti));
});

test("tappe: i capi posseduti adatti evitano proposte per gli stessi bisogni", () => {
  const { mancanti } = generaTappe(armadioTipico());
  assert.ok(!mancanti.some((g: any) => g.slot === "strato medio per la sera" && g.tappe.includes(FREDDA.destinazione)),
    "gli strati gia' presenti non vanno proposti di nuovo");
});

test("tappe: la quantita' usa i giorni della tappa, non quelli dell'intero viaggio", () => {
  const mare = { ...CALDA, giorni: 2, attivita: ["mare"] };
  const lunga = { ...FREDDA, giorni: 20, attivita: ["visite in citta"] };
  const { posti } = generaTappe([], [mare, lunga]);
  assert.equal(posti.find((p) => p.tipo === "Swimwear")?.copie, 1);
});

test("tappe parziali: uno strato posseduto lascia un solo strato diverso da proporre", () => {
  const uno = armadioTipico().filter((g) => g.sub_fine === "Hoodie");
  const { mancanti } = generaTappe(uno);
  const medio = mancanti.find((g) => g.slot === "strato medio per la sera" && g.tappe.includes(FREDDA.destinazione));
  assert.equal(medio?.copie_minime, 1);
});

test("tappe: controllare le proposte non modifica capi, assegnazioni o gap della valigia", () => {
  const items = armadioTipico();
  const { valigia } = generaTappe(items);
  const prima = structuredClone(valigia), armadioPrima = structuredClone(items);
  mancantiDelleTappe(valigia, items, { giorni: 7, bagaglio: "valigia grande", tappe: [
    { nome: CALDA.destinazione, giorni: 4, attivita: CALDA.attivita },
    { nome: FREDDA.destinazione, giorni: 3, attivita: FREDDA.attivita }] },
    { _per_tappa: [CALDA, FREDDA].map((t) => ({ destinazione: t.destinazione, ...t.meteo })) });
  assert.deepEqual(valigia, prima);
  assert.deepEqual(items, armadioPrima);
});
