import { test } from "node:test";
import assert from "node:assert/strict";
import { armadioTipico } from "../armadio_tipico.ts";
import { strategySlots } from "../slots.ts";
import { analizzaFabbisogni, copieResidue, copriConProposte, intersecaVincoli, vincoliCompatibili } from "../fabbisogni.ts";

const viaggio = { giorni: 4, bagaglio: "valigia grande", lavatrice: false,
  attivita: ["riunioni di lavoro"], destinazione: { nome: "Congresso" } };
const meteo = { temp_min_media: 14, temp_max_media: 22, giorni_di_pioggia: 0 };
function prepara(completo: boolean) {
  const items = armadioTipico().filter((g) => completo || g.category !== "Outerwear");
  const valigia = strategySlots(JSON.stringify([{ slot: "capospalla richiesto", category: "Outerwear",
    subCategories: ["Blazer"], minWarmth: 2, maxWarmth: 3, formality: ["Business"], frequency: "once" }]), items,
    { giorni: 4, lavatrice: false, bagaglio: viaggio.bagaglio, attivita: viaggio.attivita, temp_min: 14, temp_max: 22 });
  return { items, valigia };
}

test("fabbisogni: con il blazer posseduto il bisogno formale e' coperto", () => {
  const { items, valigia } = prepara(true);
  assert.ok([...valigia.ideali, ...valigia.ripieghi].some((g) => g.subCategory === "Blazer"));
  const r = analizzaFabbisogni(valigia, items, viaggio, meteo);
  assert.ok(!r.mancanti.some((f) => f.vincoli.slot === "capospalla richiesto"));
});

test("fabbisogni: l'armadio parziale espone il bisogno formale residuo completo", () => {
  const { items, valigia } = prepara(false);
  const r = analizzaFabbisogni(valigia, items, viaggio, meteo);
  const f = r.mancanti.find((f) => f.vincoli.slot === "capospalla richiesto");
  assert.ok(f);
  assert.deepEqual(f.vincoli.formality, ["Business"]);
  assert.equal(f.richiesto?.capoTipico?.sub, "Blazer");
  assert.equal(copieResidue(f, "Blazer"), 1);
});

test("fabbisogni: l'analisi non cambia la valigia, l'armadio o gli input", () => {
  const { items, valigia } = prepara(true);
  const prima = structuredClone({ items, valigia, viaggio, meteo });
  analizzaFabbisogni(valigia, items, viaggio, meteo);
  assert.deepEqual({ items, valigia, viaggio, meteo }, prima);
});

const piano = (tipo: string, copie: number, tappe = ["Alfa"]) => ({ tipo, copie, tappe,
  capo: { sub: tipo, categoria: "Upper Body" }, bisogno: { subCategories: [tipo], warmth_richiesto: [3, 4] } });
const bisogno = (tipo = "Sweater", tappe = ["Alfa"]) => ({ ...piano(tipo, 2, tappe),
  bisogno: { subCategories: ["Sweater", "Hoodie"], warmth_richiesto: [3, 4], tappe } });

test("fabbisogni: uno strato gia' proposto lascia una sola copia residua", () => {
  assert.deepEqual(copriConProposte(bisogno(), [piano("Hoodie", 1)], true), { copie: 1, riusate: [0] });
});

test("fabbisogni: se il tipo e' lo stesso il massimo finale conserva due copie", () => {
  assert.deepEqual(copriConProposte(bisogno("Hoodie"), [piano("Hoodie", 1)], true), { copie: 2, riusate: [0] });
});

test("fabbisogni: le copie proposte per una tappa diversa non coprono questo bisogno", () => {
  assert.deepEqual(copriConProposte(bisogno(), [piano("Hoodie", 2, ["Beta"])], true), { copie: 2, riusate: [] });
});

test("fabbisogni: fasce o attivita' incompatibili restano distinte", () => {
  assert.equal(vincoliCompatibili({ warmth_richiesto: [1, 2] }, { warmth_richiesto: [3, 4] }), false);
  assert.equal(vincoliCompatibili({ requiredActivityTags: ["Hiking"] }, { requiredActivityTags: ["Office"] }), false);
  assert.equal(vincoliCompatibili({ formality: ["Business"] }, { formality: ["Casual"] }), false);
});

test("fabbisogni: l'unione mantiene la fascia comune e la maggiore protezione dall'acqua", () => {
  const r = intersecaVincoli({ warmth_richiesto: [1, 4], formality: ["Casual", "Business"], requiredWaterResistance: 1 },
    { warmth_richiesto: [3, 5], formality: ["Business"], impermeabilita_richiesta: 2 });
  assert.deepEqual(r.warmth_richiesto, [3, 4]);
  assert.deepEqual(r.formality, ["Business"]);
  assert.equal(r.impermeabilita_richiesta, 2);
});

test("fabbisogni: le copie insufficienti degli essenziali escono dal motore come residuo", () => {
  const valigia = { essenziali: [{ radice: "mutand" }], mancanti_canonici: [] };
  const r = analizzaFabbisogni(valigia, [], viaggio, meteo, { salvate: new Map([["intimo", 3]]),
    motivi: { capi: [], essenziali: [{ item_id: "intimo", radice: "mutand", quantita: 8 }] } });
  const f = r.copieMancanti.find((f) => f.id === "intimo");
  assert.ok(f);
  assert.equal(f.copie, 5);
  assert.equal(f.richieste, 8);
  assert.equal(f.presenti, 3);
  assert.equal(f.famiglia?.tipo, "intimo");
  assert.ok(!r.essenzialiMancanti.some((f) => f.tipo === "intimo"));
});

test("fabbisogni: le quattro famiglie gia' coperte non vengono proposte di nuovo", () => {
  const r = analizzaFabbisogni({ mancanti_canonici: [], essenziali: [
    { radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }] }, [], viaggio, meteo);
  assert.deepEqual(r.essenzialiMancanti, []);
});

test("fabbisogni: la stessa analisi si riusa senza mutazioni tra due presentazioni", async () => {
  const { postiApp } = await import("../posti.ts");
  const { items, valigia } = prepara(false);
  const motivi = { capi: [], essenziali: [] }, salvate = new Map<string, number | null>();
  const analisi = analizzaFabbisogni(valigia, items, viaggio, meteo, { motivi, salvate });
  const prima = structuredClone(analisi);
  const contesto = { viaggio, meteo, armadio: items, fabbisogni: analisi };
  const it = postiApp(valigia, motivi, salvate, { ...contesto, lingua: "it" });
  const en = postiApp(valigia, motivi, salvate, { ...contesto, lingua: "en" });
  assert.deepEqual(analisi, prima);
  assert.deepEqual(it.posti.map((p) => [p.id, p.copie]), en.posti.map((p) => [p.id, p.copie]));
});
