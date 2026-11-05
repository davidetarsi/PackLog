// Il passo dei kit di pack-trip: quali oggetti entrano da soli, quali kit si propongono, quali posti si riducono.
import { test } from "node:test";
import assert from "node:assert/strict";
import { kitDelViaggio, riempiPostiConKit, type KitIngresso } from "../kit.ts";
import type { PostoApp } from "../posti.ts";
import type { CapoApp } from "../uscita.ts";
import { caricaArmadio } from "../capo.ts";

const capo = (item_id: string, quantita = 1): CapoApp =>
  ({ item_id, quantita, in_partenza: true, motivo: { codice: "x", etichetta: "x", frase: "x" } });
const kit = (id: string, attivita: string[], mezzi: string[], oggetti: [string, number][]): KitIngresso =>
  ({ id, attivita, mezzi, oggetti: oggetti.map(([item_id, copie]) => ({ item_id, copie })) });
const armadio = (...ids: string[]) => new Set(ids);
const viaggio = (attivita: string[], mezzi: string[] = []) => ({ attivita, mezzi });

test("strada 1 per attivita' di una tappa", () => {
  const k = kit("k1", ["ski"], [], [["guanti", 2], ["casco", 1]]);
  // il viaggio ha sci solo in una tappa: l'unione e' fatta da chi chiama, qui basta che ci sia
  const r = kitDelViaggio([k], [], viaggio(["city", "ski"]), armadio("guanti", "casco"));
  assert.deepEqual(r.aggiunti, [
    { kit_id: "k1", item_id: "guanti", copie: 2 }, { kit_id: "k1", item_id: "casco", copie: 1 }]);
  assert.deepEqual(r.suggeriti, []);
});

test("strada 1 per mezzo", () => {
  const k = kit("k1", [], ["plane"], [["cuscino", 1]]);
  assert.equal(kitDelViaggio([k], [], viaggio([], ["plane", "car"]), armadio("cuscino")).aggiunti.length, 1);
  assert.equal(kitDelViaggio([k], [], viaggio([], ["train"]), armadio("cuscino")).aggiunti.length, 0);
});

test("copie: massimo fra kit e capi", () => {
  const k = kit("k1", ["ski"], [], [["a", 2], ["b", 1], ["c", 3]]);
  const r = kitDelViaggio([k], [capo("a", 4), capo("b", 1), capo("c", 1)], viaggio(["ski"]), armadio("a", "b", "c"));
  assert.deepEqual(r.aggiunti.map((x) => x.copie), [4, 1, 3]);
});

test("strada 2 con 3 su 5", () => {
  const k = kit("k1", ["ski"], [], [["a", 1], ["b", 1], ["c", 2], ["d", 1], ["e", 3]]);
  const r = kitDelViaggio([k], [capo("a"), capo("b"), capo("c")], viaggio(["city"]), armadio("a", "b", "c", "d", "e"));
  assert.deepEqual(r.aggiunti, []);
  assert.deepEqual(r.suggeriti, [{ kit_id: "k1", presi: 3, totale: 5,
    mancanti: [{ item_id: "d", copie: 1 }, { item_id: "e", copie: 3 }] }]);
});

test("strada 2: ordine per presi decrescente", () => {
  const k1 = kit("k1", [], [], [["a", 1], ["b", 1], ["c", 1], ["d", 1]]);
  const k2 = kit("k2", [], [], [["a", 1], ["b", 1], ["c", 1], ["e", 1], ["f", 1]]);
  const r = kitDelViaggio([k1, k2], [capo("a"), capo("b"), capo("c"), capo("e")], viaggio([]), armadio("a", "b", "c", "d", "e", "f"));
  assert.deepEqual(r.suggeriti.map((s) => s.kit_id), ["k2", "k1"]);
});

test("nessuna domanda con 1 su 2 e con 5 su 5", () => {
  const due = kit("k1", [], [], [["a", 1], ["b", 1]]);
  assert.deepEqual(kitDelViaggio([due], [capo("a")], viaggio([]), armadio("a", "b")).suggeriti, []);
  const cinque = kit("k2", [], [], ["a", "b", "c", "d", "e"].map((i) => [i, 1] as [string, number]));
  const capi = ["a", "b", "c", "d", "e"].map((i) => capo(i));
  assert.deepEqual(kitDelViaggio([cinque], capi, viaggio([]), armadio("a", "b", "c", "d", "e")).suggeriti, []);
});

test("nessuna domanda con 2 su 5 (meno della meta')", () => {
  const k = kit("k1", [], [], ["a", "b", "c", "d", "e"].map((i) => [i, 1] as [string, number]));
  assert.deepEqual(kitDelViaggio([k], [capo("a"), capo("b")], viaggio([]), armadio("a", "b", "c", "d", "e")).suggeriti, []);
});

test("oggetto fuori armadio ignorato, anche nel totale", () => {
  const k = kit("k1", ["ski"], [], [["a", 1], ["fantasma", 1]]);
  assert.deepEqual(kitDelViaggio([k], [], viaggio(["ski"]), armadio("a")).aggiunti, [{ kit_id: "k1", item_id: "a", copie: 1 }]);
  // 3 su 3 validi: kit completo, nessuna domanda. Con il fantasma nel totale sarebbe 3 su 4 e la domanda partirebbe.
  const k2 = kit("k2", [], [], [["a", 1], ["b", 1], ["c", 1], ["fantasma", 1]]);
  const r = kitDelViaggio([k2], [capo("a"), capo("b"), capo("c")], viaggio([]), armadio("a", "b", "c"));
  assert.deepEqual(r.suggeriti, []);
});

test("un kit della strada 1 non e' anche suggerito", () => {
  const k = kit("k1", ["ski"], [], [["a", 1], ["b", 1], ["c", 1]]);
  const r = kitDelViaggio([k], [capo("a"), capo("b")], viaggio(["ski"]), armadio("a", "b", "c"));
  assert.equal(r.aggiunti.length, 3);
  assert.deepEqual(r.suggeriti, []);
});

const posto = (tipo: string, copie: number, i: number): PostoApp =>
  ({ id: `${tipo}:${i}`, tipo, categoria: "vestiti", livello: "utile", nome: tipo, copie, motivo: null, aggiungi: "x" });
const g = (id: string, category: string, sub_category: string) => ({ id, category, sub_category }) as any;

test("riempiPostiConKit toglie un posto Rain Jacket con un K-way del kit", () => {
  const posti = [posto("Rain Jacket", 1, 0), posto("T-Shirt", 3, 1)];
  const r = riempiPostiConKit(posti, [{ kit_id: "k1", item_id: "kway", copie: 1 }], [g("kway", "Outerwear", "Rain Jacket")]);
  assert.deepEqual(r.map((p) => p.tipo), ["T-Shirt"]);
});

test("riempiPostiConKit scala le copie, ripiega sulla categoria e lascia gli id", () => {
  const posti = [posto("Outerwear", 1, 0), posto("T-Shirt", 3, 1)];
  const r = riempiPostiConKit(posti, [
    { kit_id: "k1", item_id: "m", copie: 2 }, { kit_id: "k1", item_id: "x", copie: 1 }, { kit_id: "k2", item_id: "m", copie: 1 }],
  [g("m", "Upper Body", "T-Shirt"), g("x", "Outerwear", "Coat")]);
  // m compare in due kit: massimo (2), non somma; x ripiega sulla categoria e azzera Outerwear
  assert.deepEqual(r.map((p) => [p.id, p.copie]), [["T-Shirt:1", 1]]);
  assert.equal(posti[1].copie, 3);
});

test("riempiPostiConKit passa le copie avanzate al posto successivo dello stesso tipo", () => {
  // Due posti T-Shirt (uno e' quello del meteo): 3 copie dal kit ne chiudono uno e scalano l'altro.
  const posti = [posto("T-Shirt", 2, 0), posto("T-Shirt", 2, 1)];
  const r = riempiPostiConKit(posti, [{ kit_id: "k1", item_id: "m", copie: 3 }], [g("m", "Upper Body", "T-Shirt")]);
  assert.deepEqual(r.map((p) => [p.id, p.copie]), [["T-Shirt:1", 1]]);
});

test("riempiPostiConKit ignora gli oggetti gia' in capi e quelli senza posto", () => {
  const posti = [posto("T-Shirt", 3, 0)];
  const aggiunti = [{ kit_id: "k1", item_id: "m", copie: 2 }, { kit_id: "k1", item_id: "z", copie: 1 }];
  const arm = [g("m", "Upper Body", "T-Shirt"), g("z", "Bags", "Backpack")];
  assert.equal(riempiPostiConKit(posti, aggiunti, arm, [capo("m", 1)])[0].copie, 3);
  assert.equal(riempiPostiConKit(posti, aggiunti, arm)[0].copie, 1);
});

test("il kit copre solo il bisogno compatibile per calore e formalita'", () => {
  const posti = [
    { ...posto("Shirt", 1, 0), requisiti: { minWarmth: 2, maxWarmth: 3, formality: ["Business"] } },
    { ...posto("Shirt", 1, 1), requisiti: { minWarmth: 1, maxWarmth: 2, formality: ["Casual"] } },
  ];
  const arm = caricaArmadio([{ id: "estiva", name: "Camicia estiva", ai_metadata: {
    category: "Upper Body", subCategory: "Shirt", warmth: 1, formality: "Casual", waterResistance: 0,
  } }]);
  const r = riempiPostiConKit(posti, [{ kit_id: "k", item_id: "estiva", copie: 1 }], arm);
  assert.deepEqual(r.map((p) => p.id), ["Shirt:0"]);
});

test("un capo del kit non chiude una proposta piu' impermeabile", () => {
  const posti = [{ ...posto("Outerwear", 1, 0), requisiti: { minWaterResistance: 2 } }];
  const arm = caricaArmadio([{ id: "vento", name: "Antivento", ai_metadata: {
    category: "Outerwear", subCategory: "Windbreaker", warmth: 2, formality: "Casual", waterResistance: 1,
  } }]);
  assert.equal(riempiPostiConKit(posti, [{ kit_id: "k", item_id: "vento", copie: 1 }], arm).length, 1);
});

test("il kit riconosce il tipo fine del capo virtuale, oltre al genitore del generatore", () => {
  const arm = caricaArmadio([{ id: "pile", name: "Pile", ai_metadata: {
    category: "Upper Body", subCategory: "Fleece", warmth: 3, formality: "Casual", waterResistance: 0,
  } }]);
  assert.equal(riempiPostiConKit([posto("Fleece", 1, 0)], [{ kit_id: "k", item_id: "pile", copie: 1 }], arm).length, 0);
});

test("il kit non chiude un bisogno tecnico con una maglietta quotidiana", () => {
  const posti = [{ ...posto("T-Shirt", 1, 0), requisiti: { activityTags: ["Hiking"] } }];
  const arm = caricaArmadio([{ id: "m", name: "Maglietta", ai_metadata: {
    category: "Upper Body", subCategory: "T-Shirt", activityTags: ["Everyday"], warmth: 2,
  } }]);
  const aggiunti = [{ kit_id: "k", item_id: "m", copie: 1 }];
  assert.equal(riempiPostiConKit(posti, aggiunti, arm).length, 1);
  assert.equal(riempiPostiConKit(posti, aggiunti, arm.map((g) => ({ ...g, activity_tags: ["Hiking"] }))).length, 0);
});

test("il kit rispetta la copertura richiesta dal bisogno", () => {
  const posti = [{ ...posto("Shirt", 1, 0), requisiti: { coverage: ["Long Sleeves"] } }];
  const arm = caricaArmadio([{ id: "m", name: "Camicia", ai_metadata: {
    category: "Upper Body", subCategory: "Shirt", coverage: "Short Sleeves", warmth: 2,
  } }]);
  const aggiunti = [{ kit_id: "k", item_id: "m", copie: 1 }];
  assert.equal(riempiPostiConKit(posti, aggiunti, arm).length, 1);
  assert.equal(riempiPostiConKit(posti, aggiunti, arm.map((g) => ({ ...g, coverage: "Long Sleeves" }))).length, 0);
});
