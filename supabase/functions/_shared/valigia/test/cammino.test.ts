import { test } from "node:test";
import assert from "node:assert/strict";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { strategySlots, coperturaTermica } from "../slots.ts";
import { strategySlotsMultitappa } from "../tappe.ts";
import { postiApp } from "../posti.ts";
import { generaValigia } from "../genera.ts";
import { normalizzaQuantitaViaggio } from "../contesto_viaggio.ts";

const capo = (id: string, category: string, subCategory: string, warmth: number,
  tags = ["Hiking"], waterResistance = 0, quantity = 8): RigaArmadio => ({
  id, name: id, quantity, ai_metadata: { category, subCategory, warmth, activityTags: tags,
    formality: "Casual", waterResistance, bulk: 1, coverage: "Full-length" },
});
const tecnici = [
  ...[1, 2, 3, 4].map((n) => capo(`Maglia tecnica ${n}`, "Upper Body", "T-Shirt", 2)),
  capo("Pantaloni tecnici", "Lower Body", "Trousers", 2),
  capo("Shorts tecnici", "Lower Body", "Shorts", 2),
  capo("Pile tecnico", "Upper Body", "Fleece", 3),
  capo("Secondo pile", "Upper Body", "Fleece", 3),
  capo("Guscio tecnico", "Outerwear", "Rain Jacket", 2, ["Hiking"], 2),
  capo("Scarpe trail", "Shoes", "Sneakers", 2, ["Hiking", "Sport"], 1, 1),
  capo("Scarponi tecnici", "Shoes", "Hiking Boots", 3, ["Hiking"], 2, 1),
  capo("Ciabatte", "Shoes", "Flip-Flops", 1, ["Lounge"], 0, 1),
  capo("Mutande", "Essentials", "Underwear", 1, ["Everyday"]),
  capo("Boxer", "Essentials", "Underwear", 1, ["Everyday"]),
  capo("Calzini", "Essentials", "Socks", 2, ["Hiking"]),
  capo("Socks", "Essentials", "Socks", 2, ["Hiking"]),
];
const casual = [capo("Jeans", "Lower Body", "Jeans", 3, ["Everyday"]),
  capo("Costume", "Lower Body", "Swimwear", 1, ["Swimming"]),
  capo("Cappotto", "Outerwear", "Coat", 5, ["Hiking"]),
  capo("Piumino urbano", "Outerwear", "Down Jacket", 5, ["Everyday"]),
  capo("Giacca urbana", "Outerwear", "Casual Jacket", 3, ["Everyday"])];
const slot = (nome: string, category: string, subCategories: string[], maxWarmth = 3) => ({
  slot: nome, category, subCategories, minWarmth: 1, maxWarmth, minWaterResistance: 0,
  formality: ["Casual"], activityTags: [], frequency: "daily", essential: true, reason: "necessario" });
const slots = [slot("maglia giornaliera", "Upper Body", ["T-Shirt"]),
  slot("altra maglia", "Upper Body", ["T-Shirt"]), slot("gambe", "Lower Body", ["Trousers", "Shorts"]),
  slot("scarpe principali", "Shoes", ["Sneakers", "Hiking Boots"]),
  slot("strato intermedio", "Upper Body", ["Fleece"], 3)];
const scelti = (v: any): any[] => [...v.ideali, ...v.ripieghi].filter((g) => g.quantita > 0);
const conta = (capi: any[], subs: string[]) => capi.filter((g) => subs.includes(g.subCategory))
  .reduce((n, g) => n + g.quantita, 0);
function genera(righe = tecnici, giorni = 30, bagaglio = "zaino da 30 litri", tempMin = 18, tempMax = 24,
  input = slots, giorniPioggia = 0) {
  const viaggio = { giorni, lavatrice: false, attivita: ["cammino"], bagaglio };
  const meteo = { temp_min_media: tempMin, temp_max_media: tempMax, giorni_di_pioggia: giorniPioggia };
  const items = caricaArmadio(righe);
  const valigia = strategySlots(JSON.stringify(input), items,
    { ...viaggio, temp_min: tempMin, temp_max: tempMax, giorni_pioggia: giorniPioggia });
  const posti = postiApp(valigia, { capi: [], essenziali: [] }, new Map(righe.map((g) => [String(g.id), g.quantity ?? null])),
    { viaggio, meteo, armadio: items }).posti;
  return { valigia, posti, capi: scelti(valigia) };
}

test("cammino: il bucato frequente vale anche senza dieci giorni o uno zaino piccolo", () => {
  for (const [giorni, bagaglio] of [[7, "zaino da 30 litri"], [30, "zaino da 40 litri"], [12, "zaino da 50 litri"]] as const) {
    const q = normalizzaQuantitaViaggio({ giorni, bagaglio, lavatrice: false, attivita: ["cammino"] });
    assert.equal(q.giorni, giorni);
    assert.equal(q.lavatrice, true);
    assert.equal(q.lavatriceEssenziali, true);
  }
});

test("cammino: trenta giorni non moltiplicano i ricambi per slot o modello", () => {
  for (const giorni of [7, 30]) for (const bagaglio of ["zaino da 30 litri", "zaino da 40 litri"]) {
    const { capi, valigia } = genera(tecnici, giorni, bagaglio);
    assert.equal(conta(capi, ["T-Shirt"]), 3);
    assert.equal(conta(capi, ["Trousers", "Shorts"]), 2);
    assert.equal(conta(capi, ["Fleece", "Sweater", "Hoodie"]), 1);
    for (const radici of [["mutand", "boxer"], ["calz", "sock"]]) {
      assert.equal(valigia.essenziali.filter((g: any) => radici.includes(g.radice))
        .reduce((n: number, g: any) => n + g.quantita, 0), 3);
    }
  }
});

test("cammino: un solo paio principale indossato e un paio di ciabatte", () => {
  const { capi, valigia } = genera(tecnici, 30, "zaino da 40 litri");
  const principali = capi.filter((g) => g.category === "Shoes" && g.subCategory !== "Flip-Flops");
  assert.equal(principali.length, 1);
  assert.equal(principali[0].in_partenza, true);
  assert.equal(conta(capi, ["Flip-Flops"]), 1);
  assert.ok(!valigia.richiesti.some((g: any) => g.slot === "calzature di ricambio"));
});

test("cammino: jeans, costumi e piumini urbani restano esclusi anche dalle reti termiche", () => {
  const { capi, posti, valigia } = genera(casual, 30, "zaino da 30 litri", -15, -4,
    [slot("gambe", "Lower Body", ["Jeans", "Swimwear"]), slot("caldo", "Outerwear", ["Coat", "Down Jacket"], 5)]);
  assert.deepEqual(capi, []);
  assert.ok(valigia.mancanti.some((g: any) => g.category === "Outerwear"));
  assert.ok(posti.some((g) => g.categoria === "vestiti" && g.requisiti?.activityTags.includes("Hiking")),
    "il bisogno tecnico deve restare visibile");
  assert.ok(!posti.some((g) => ["Jeans", "Swimwear", "Coat", "Casual Jacket"].includes(g.tipo)));
});

test("cammino: un piumino tecnico caldo resta ammesso, indipendentemente dall'ingombro", () => {
  const tecnico = capo("Piumino tecnico caldo", "Outerwear", "Down Jacket", 5, ["Hiking"]);
  tecnico.ai_metadata = { ...(tecnico.ai_metadata as object), bulk: 3 };
  const { capi } = genera([...tecnici, ...casual, tecnico], 30, "zaino da 40 litri", -15, -4);
  assert.ok(capi.some((g) => g.item_id === tecnico.id));
  assert.ok(!capi.some((g) => casual.some((c) => c.id === g.item_id)));
});

test("cammino: i posti dell'armadio vuoto rispettano i budget delle famiglie", () => {
  const { posti } = genera([]);
  const somma = (tipi: string[]) => posti.filter((p) => tipi.includes(p.tipo)).reduce((n, p) => n + p.copie, 0);
  assert.equal(somma(["T-Shirt", "Thermal Top"]), 3);
  assert.equal(somma(["Trousers", "Shorts"]), 2);
  assert.equal(somma(["intimo"]), 3);
  assert.equal(somma(["calzini"]), 3);
  assert.ok(posti.some((p) => p.tipo === "Flip-Flops"));
});

test("cammino col caldo: i pantaloni suggeriti restano due, come la quantita' compatta", () => {
  for (const tempMax of [24, 26, 30, 36]) {
    const { posti } = genera([], 30, "zaino da 30 litri", 18, tempMax);
    const lunghi = posti.filter((p) => ["Trousers", "Shorts"].includes(p.tipo)).reduce((n, p) => n + p.copie, 0);
    assert.equal(lunghi, 2, `tempMax ${tempMax}`);
  }
});

test("cammino: posseduti e proposte condividono il budget senza chiedere un altro ricambio", () => {
  const righe = tecnici.filter((g) => !["Boxer", "Socks"].includes(String(g.id)))
    .map((g) => ({ ...g, quantity: 1 }));
  const { capi, posti, valigia } = genera(righe);
  const maglie = conta(capi, ["T-Shirt", "Thermal Top"]) + posti.filter((p) => ["T-Shirt", "Thermal Top"].includes(p.tipo))
    .reduce((n, p) => n + p.copie, 0);
  assert.equal(maglie, 3);
  assert.equal(valigia.essenziali.filter((g: any) => g.radice === "mutand")
    .reduce((n: number, g: any) => n + g.quantita, 0), 3);
});

function multi(attGlobale: string[], attBase: string[], attFredda: string[], righe: RigaArmadio[]) {
  const ts = [{ destinazione: "Mite", giorni: 15, attivita: attBase,
    meteo: { temp_min_media: 18, temp_max_media: 24, giorni_di_pioggia: 0 } },
    { destinazione: "Fredda", giorni: 15, attivita: attFredda,
      meteo: { temp_min_media: -10, temp_max_media: -3, giorni_di_pioggia: 0 } }];
  return strategySlotsMultitappa(JSON.stringify(slots), caricaArmadio(righe), {
    sc: { giorni: 30, attivita: attGlobale, lavatrice: false, bagaglio: "zaino da 40 litri", legs: ts },
    geo: { per_tappa: ts }, bagaglio: "zaino da 40 litri",
  });
}

test("cammino a tappe: la rete fredda non recupera capi casual e conserva i ricambi limitati", () => {
  const v = multi(["cammino"], [], [], [...tecnici, ...casual]);
  assert.ok(!scelti(v).some((g) => casual.some((c) => c.id === g.item_id)));
  assert.ok(conta(scelti(v), ["T-Shirt", "Thermal Top"]) <= 3);
  assert.ok(v.mancanti.some((g: any) => g.category === "Outerwear" && g.tappe?.includes("Fredda")));
});

test("cammino a tappe: il filtro non elimina un cappotto necessario nella sola tappa urbana", () => {
  const v = multi([], ["cammino"], ["visite in citta"], [...tecnici, ...casual]);
  const coat = scelti(v).find((g) => g.item_id === "Cappotto");
  assert.ok(coat, "la tappa urbana conserva il proprio capospalla caldo");
  assert.ok(coat.tappe.includes("Fredda"));
  assert.ok(!coat.tappe.includes("Mite"));
});

test("cammino: una maglia quotidiana da riposo non copre i bisogni tecnici e non si moltiplica", () => {
  const riposo = { ...slot("maglia da riposo", "Upper Body", ["T-Shirt"]), frequency: "once", activityTags: ["Everyday"] };
  const quotidiana = capo("Maglia da riposo", "Upper Body", "T-Shirt", 2, ["Everyday"]);
  const { capi, posti } = genera([quotidiana], 30, "zaino da 30 litri", 18, 24, [...slots, riposo]);
  assert.equal(capi.filter((g) => g.item_id === quotidiana.id).reduce((n, g) => n + g.quantita, 0), 1);
  assert.ok(posti.some((p) => p.requisiti?.activityTags.includes("Hiking")), "resta il bisogno tecnico");
  assert.ok(!genera([quotidiana], 30, "zaino da 30 litri", -10, -3, [...slots, riposo]).capi.length);
});

test("cammino: il completo coperto non produce falsi avvisi di ricambi insufficienti", () => {
  const { valigia, posti } = genera(tecnici);
  assert.ok(!valigia.mancanti.some((g: any) => g.tipo === "quantita_insufficiente" &&
    ["Upper Body", "Lower Body", "Shoes"].includes(g.category)));
  assert.ok(!posti.some((p) => ["T-Shirt", "Fleece", "Trousers", "Sneakers", "Hiking Boots", "intimo", "calzini"].includes(p.tipo)));
});

test("cammino: uno strato termico sotto i pantaloni non consuma un ricambio esterno", () => {
  const termico = capo("Calzamaglia tecnica", "Lower Body", "Thermal Bottoms", 4);
  const { capi } = genera([...tecnici, termico], 30, "zaino da 40 litri", -10, -3,
    [...slots, slot("strato sotto i pantaloni", "Lower Body", ["Thermal Bottoms"], 5)]);
  assert.ok(capi.some((g) => g.item_id === termico.id));
  assert.equal(conta(capi, ["Trousers", "Shorts"]), 2);
});


test("cammino: l'informazione sul bucato a mano spiega la dotazione ridotta anche in inglese", () => {
  const v = genera().valigia;
  for (const lingua of ["it", "en"] as const) {
    const r = postiApp(v, { capi: [], essenziali: [] }, new Map(), { lingua, armadio: caricaArmadio(tecnici),
      viaggio: { giorni: 7, attivita: ["cammino"], lavatrice: false }, meteo: {} });
    assert.ok(r.informazioni.some((i) => /mano|hand/i.test(i.perche)));
    assert.ok(!r.informazioni.some((i) => /lavanderia/i.test(i.titolo)));
  }
});

test("cammino: il flusso completo mantiene tre ricambi totali e nessuna proposta duplicata", async () => {
  const r = await generaValigia({ giorni: 30, data_inizio: "2027-05-01", attivita: ["cammino"],
    destinazione: "Tappa", bagaglio: "zaino da 40 litri", lavatrice: false }, tecnici, {
    clima: async () => ({ geo: {}, meteo: { temp_min_media: 18, temp_max_media: 24, giorni_di_pioggia: 0 } }),
    modello: async () => ({ testo: JSON.stringify(slots) }), jev: null,
  });
  assert.equal(conta(scelti(r.valigia), ["T-Shirt"]), 3);
  const viaggio = { giorni: 30, attivita: ["cammino"], lavatrice: false, bagaglio: "zaino da 40 litri" };
  const copertura = { armadio: caricaArmadio(tecnici), viaggio, meteo: r.meteo };
  const salvate = new Map(tecnici.map((g) => [String(g.id), g.quantity ?? null]));
  const a = postiApp(r.valigia, r.motivi as any, salvate, { ...copertura, fabbisogni: r.fabbisogni });
  const b = postiApp(r.valigia, r.motivi as any, salvate, copertura);
  assert.deepEqual(a, b);
  assert.ok(!a.posti.some((p) => ["T-Shirt", "Trousers", "intimo", "calzini"].includes(p.tipo)));
});

test("cammino: il limite di un paio non nasconde una protezione dalla pioggia mancante", () => {
  const { capi, posti } = genera(tecnici.filter((g) => g.id !== "Scarponi tecnici"), 30, "zaino da 30 litri", 18, 24,
    [slot("maglia", "Upper Body", ["T-Shirt"]), slot("gambe", "Lower Body", ["Trousers"]),
      { ...slot("scarpe per la pioggia", "Shoes", ["Sneakers", "Hiking Boots"]), minWaterResistance: 2 }], 3);
  assert.ok(posti.some((p) => p.requisiti?.minWaterResistance === 2 &&
    ["Shoes", "Sneakers", "Hiking Boots", "Boots"].includes(p.tipo)), "manca una scarpa con protezione sufficiente");
  assert.equal(capi.filter((g) => g.category === "Shoes" && g.subCategory !== "Flip-Flops")
    .reduce((n, g) => n + g.quantita, 0), 0, "un paio inadeguato non occupa l'unico posto principale");
});

test("cammino: un costume esplicitamente richiesto dal mare resta per il bagno, mai per camminare", () => {
  const items = caricaArmadio([...tecnici, ...casual]);
  const v = strategySlots(JSON.stringify(slots), items, { giorni: 10, lavatrice: false,
    attivita: ["cammino", "mare"], bagaglio: "zaino da 40 litri", temp_min: 18, temp_max: 24 });
  const costume = scelti(v).find((g) => g.item_id === "Costume");
  assert.ok(costume);
  assert.ok(costume.assegnazioni.every((a: any) => /costume|bagno/.test(a.slot)));
  assert.ok(scelti(v).some((g) => g.subCategory === "Trousers" || g.subCategory === "Shorts"));
});

test("cammino a tappe: un cappotto urbano non viene prestato dalla rete termica", () => {
  const ts = [{ destinazione: "Citta", giorni: 3, attivita: ["visite in citta"],
    meteo: { temp_min_media: 0, temp_max_media: 8 } },
    { destinazione: "Cammino", giorni: 7, attivita: ["cammino"],
      meteo: { temp_min_media: -15, temp_max_media: -4 } }];
  const v = strategySlotsMultitappa("[]", caricaArmadio([...tecnici, ...casual]), {
    sc: { attivita: [], lavatrice: false, legs: ts }, geo: { per_tappa: ts }, bagaglio: "zaino da 40 litri",
  });
  const cappotto = scelti(v).find((g) => g.item_id === "Cappotto");
  assert.ok(cappotto?.tappe.includes("Citta"));
  assert.ok(!cappotto.tappe.includes("Cammino"));
  assert.ok(v.mancanti.some((g: any) => g.category === "Outerwear" && g.tappe?.includes("Cammino")));
});

test("cammino: un sandalo elegante non viene usato come ciabatta da riposo", () => {
  const elegante = capo("Sandali eleganti", "Shoes", "Sandals", 1, ["Formal"]);
  elegante.ai_metadata = { ...(elegante.ai_metadata as object), formality: "Formal" };
  const { capi, posti } = genera([elegante]);
  assert.ok(!capi.some((g) => g.item_id === elegante.id));
  assert.ok(posti.some((p) => p.tipo === "Flip-Flops" || p.tipo === "Sandals"));
});

test("cammino: le copie ignote non nascondono ricambi mancanti rispetto all'uscita dell'app", async () => {
  const righe = tecnici.filter((g) => g.id !== "Boxer" && g.id !== "Socks" &&
    (!String(g.id).startsWith("Maglia tecnica") || g.id === "Maglia tecnica 1"))
    .map((g) => ({ ...g, quantity: null }));
  const r = await generaValigia({ giorni: 30, data_inizio: "2027-05-01", attivita: ["cammino"],
    destinazione: "Tappa", bagaglio: "zaino da 40 litri", lavatrice: false }, righe, {
    clima: async () => ({ geo: {}, meteo: { temp_min_media: 18, temp_max_media: 24, giorni_di_pioggia: 0 } }),
    modello: async () => ({ testo: JSON.stringify(slots) }), jev: null,
  });
  const p = postiApp(r.valigia, r.motivi as any, new Map(righe.map((g) => [String(g.id), null])), {
    armadio: caricaArmadio(righe), viaggio: { giorni: 30, attivita: ["cammino"] }, meteo: r.meteo, fabbisogni: r.fabbisogni,
  });
  assert.equal(p.posti.filter((x) => x.tipo === "T-Shirt").reduce((n, x) => n + x.copie, 0), 2);
  assert.equal(p.posti.filter((x) => x.tipo === "intimo").reduce((n, x) => n + x.copie, 0), 2);
});


test("cammino a tappe: il limite dei pile conserva la copertura termica di entrambe le tappe", () => {
  const ts = [{ destinazione: "Mite", giorni: 3, attivita: ["cammino"], meteo: { temp_min_media: 12, temp_max_media: 24 } },
    { destinazione: "Fredda", giorni: 3, attivita: ["cammino"], meteo: { temp_min_media: -15, temp_max_media: -4 } }];
  const righe = [capo("Guscio", "Outerwear", "Rain Jacket", 2), capo("Piumino", "Outerwear", "Down Jacket", 5),
    capo("Maglia", "Upper Body", "T-Shirt", 2), capo("Pile3", "Upper Body", "Fleece", 3),
    capo("Pile4", "Upper Body", "Fleece", 4), capo("Pantaloni", "Lower Body", "Trousers", 2)];
  const v = strategySlotsMultitappa("[]", caricaArmadio(righe), { sc: { attivita: ["cammino"], lavatrice: false, legs: ts },
    geo: { per_tappa: ts }, bagaglio: "zaino da 40 litri" });
  assert.equal(coperturaTermica(scelti(v), ts[0].meteo, "Mite").coperta, true);
  assert.equal(coperturaTermica(scelti(v), ts[1].meteo, "Fredda").coperta, true);
});

test("cammino a tappe: il pile freddo posseduto non nasconde il pile mite ancora mancante", () => {
  const ts = [{ destinazione: "Mite", giorni: 3, attivita: ["cammino"], meteo: { temp_min_media: 12, temp_max_media: 24 } },
    { destinazione: "Fredda", giorni: 3, attivita: ["cammino"], meteo: { temp_min_media: -15, temp_max_media: -4 } }];
  const righe = [capo("Guscio", "Outerwear", "Rain Jacket", 2), capo("Piumino", "Outerwear", "Down Jacket", 5),
    capo("Maglia", "Upper Body", "T-Shirt", 2), capo("Pile4", "Upper Body", "Fleece", 4),
    capo("Pantaloni", "Lower Body", "Trousers", 2)];
  const v = strategySlotsMultitappa("[]", caricaArmadio(righe), { sc: { attivita: ["cammino"], lavatrice: false, legs: ts },
    geo: { per_tappa: ts }, bagaglio: "zaino da 40 litri" });
  const { posti } = postiApp(v, { capi: [], essenziali: [] }, new Map(righe.map((g) => [String(g.id), g.quantity ?? null])), {
    armadio: caricaArmadio(righe), viaggio: { giorni: 6, attivita: ["cammino"], tappe: ts.map((t) => ({ ...t, nome: t.destinazione })) },
    meteo: { _per_tappa: ts.map((t) => ({ ...t.meteo, destinazione: t.destinazione })) },
  });
  assert.ok(posti.some((p) => ["Fleece", "Sweater", "Hoodie"].includes(p.tipo) && p.requisiti?.maxWarmth === 3));
});

test("cammino: la rotazione minima non dipende dalla frequenza once proposta dal modello", () => {
  const input = slots.map((s) => ({ ...s, frequency: "once" }));
  const a = genera(tecnici, 30, "zaino da 40 litri", 18, 24, input);
  assert.equal(conta(a.capi, ["T-Shirt"]), 3);
  assert.equal(conta(a.capi, ["Trousers", "Shorts"]), 2);
  const b = genera([], 30, "zaino da 40 litri", 18, 24, input);
  assert.equal(b.posti.filter((p) => ["Trousers", "Shorts"].includes(p.tipo)).reduce((n, p) => n + p.copie, 0), 2);
});

test("cammino invernale: gli strati base termici condividono la rotazione delle maglie", () => {
  const righe = [...tecnici, capo("Base termica", "Upper Body", "Thermal Top", 3),
    capo("Piumino tecnico", "Outerwear", "Down Jacket", 5)];
  const { capi } = genera(righe, 30, "zaino da 40 litri", -10, -3,
    [...slots, { ...slot("base termica", "Upper Body", ["Thermal Top"], 4), minWarmth: 3 }]);
  assert.ok(capi.some((g) => g.item_id === "Base termica"));
  assert.equal(conta(capi, ["T-Shirt"]), 3, "Thermal Top e' rappresentata dal genitore T-Shirt nel motore");
});

test("cammino in quota: conserva il bisogno di occhiali da riverbero del trekking", () => {
  const v = strategySlots("[]", caricaArmadio(tecnici), { giorni: 7, lavatrice: false,
    attivita: ["cammino"], bagaglio: "zaino da 30 litri", temp_min: 12, temp_max: 22, quota_m: 4000 });
  assert.ok(v.richiesti.some((r: any) => r.slot === "occhiali da sole"));
});
