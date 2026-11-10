import { test } from "node:test";
import assert from "node:assert/strict";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { essenzialiPerViaggio } from "../quantita.ts";
import { generaValigia } from "../genera.ts";
import * as dopo from "../dopo.ts";
import { strategySlots } from "../slots.ts";
import { postiApp } from "../posti.ts";

const capo = (id: string, category: string, subCategory: string, warmth: number, quantity = 30,
  formality = "Casual"): RigaArmadio => ({ id, name: id, quantity,
  ai_metadata: { category, subCategory, warmth, formality, activityTags: ["Everyday"],
    waterResistance: 0, bulk: 1, coverage: "Full-length" } });
const armadio = [capo("Magliette", "Upper Body", "T-Shirt", 2),
  capo("Camicia", "Upper Body", "Shirt", 1, 3), capo("Pantaloncini", "Lower Body", "Shorts", 1),
  capo("Sneakers", "Shoes", "Sneakers", 2, 1), capo("Mutande", "Essentials", "Underwear", 1),
  capo("Calzini", "Essentials", "Socks", 1)];
const raw = JSON.stringify([{ slot: "maglie", category: "Upper Body", subCategories: ["T-Shirt"], minWarmth: 1,
  maxWarmth: 2, formality: ["Casual"], activityTags: [], minWaterResistance: 0, frequency: "daily", essential: true },
{ slot: "gambe", category: "Lower Body", subCategories: ["Shorts"], minWarmth: 1, maxWarmth: 2,
  formality: ["Casual"], activityTags: [], minWaterResistance: 0, frequency: "daily", essential: true }]);

async function genera(attivita: string[], tempMax: number | null = 31, righe = armadio, lavatrice = false,
  tappe?: { destinazione: string; giorni: number; attivita: string[]; tempMax: number | null }[]) {
  const meteo = { temp_min_media: 25, temp_max_media: tempMax, giorni_di_pioggia: 0,
    ...(tappe ? { _per_tappa: tappe.map((t) => ({ destinazione: t.destinazione,
      temp_min_media: 25, temp_max_media: t.tempMax, giorni_di_pioggia: 0 })) } : {}) };
  const sc = { data_inizio: "2027-07-01", giorni: 9, attivita, lavatrice, bagaglio: "trolley medio",
    ...(tappe ? { legs: tappe.map((t) => ({ destinazione: t.destinazione, giorni: t.giorni, attivita: t.attivita })) }
      : { destinazione: "Destinazione" }) };
  const r = await generaValigia(sc, righe, { modello: async () => ({ testo: raw }), jev: null,
    clima: async () => ({ meteo, geo: tappe ? { per_tappa: tappe.map((t) => ({ destinazione: t.destinazione,
      giorni: t.giorni, attivita: [...attivita, ...t.attivita], geo: { nome: t.destinazione, paese: "Italia", altitudine_m: 0 },
      meteo: { temp_min_media: t.tempMax == null ? null : Math.min(25, t.tempMax - 4),
        temp_max_media: t.tempMax, giorni_di_pioggia: 0 } })) } : {} }) });
  const viaggio = { ...sc, ...(tappe ? { tappe: tappe.map((t) => ({ nome: t.destinazione,
    giorni: t.giorni, attivita: t.attivita })) } : {}) };
  const contesto = { viaggio, meteo, armadio: caricaArmadio(righe) };
  const salvate = new Map(righe.map((g) => [String(g.id), g.quantity ?? null]));
  const a = postiApp(r.valigia, r.motivi as any, salvate, { ...contesto, fabbisogni: r.fabbisogni });
  const b = postiApp(r.valigia, r.motivi as any, salvate, contesto);
  assert.deepEqual(a, b, "il motore e l'adapter devono usare lo stesso conteggio");
  return { ...r, posti: a.posti };
}
const totale = (r: any, radici: string[]) => r.valigia.essenziali.filter((g: any) => radici.includes(g.radice))
  .reduce((n: number, g: any) => n + g.quantita, 0);

test("mare caldo: nove giorni richiedono nove mutande e sette paia di calzini", async () => {
  for (const attivita of [["mare"], ["immersioni"], ["snorkeling"]]) {
    const r = await genera(attivita);
    assert.equal(totale(r, ["mutand"]), 9);
    assert.equal(totale(r, ["calz"]), 7);
  }
});

test("mare caldo: bucato e arrotondamento non ripristinano il pezzo extra", async () => {
  const r = await genera(["mare"], 31, armadio, true);
  assert.equal(totale(r, ["mutand"]), 5);
  assert.equal(totale(r, ["calz"]), 4);
});

test("essenziali mare: la riduzione non porta mai a zero e arrotonda al piu' vicino", () => {
  for (const [giorni, mutande, calzini] of [[1, 1, 1], [4, 4, 4], [9, 9, 7], [10, 10, 8]]) {
    const es = essenzialiPerViaggio(caricaArmadio(armadio), giorni, false, 31, false, true);
    assert.equal(es.filter((g) => g.radice === "mutand").reduce((n, g) => n + g.quantita, 0), mutande);
    assert.equal(es.filter((g) => g.radice === "calz").reduce((n, g) => n + g.quantita, 0), calzini);
  }
});

test("mare caldo: nomi sinonimi condividono un solo fabbisogno per famiglia", async () => {
  const righe = [...armadio, capo("Boxer", "Essentials", "Underwear", 1), capo("Socks", "Essentials", "Socks", 1)];
  const r = await genera(["mare"], 31, righe);
  assert.equal(totale(r, ["mutand", "boxer"]), 9);
  assert.equal(totale(r, ["calz", "sock"]), 7);
});

test("mare caldo: armadio vuoto e parziale ricevono soltanto le copie residue", async () => {
  const vuoto = await genera(["mare"], 31, []);
  assert.equal(vuoto.posti.find((p) => p.tipo === "intimo")?.copie, 9);
  assert.equal(vuoto.posti.find((p) => p.tipo === "calzini")?.copie, 7);
  const parziale = await genera(["mare"], 31, armadio.map((g) => ({ ...g,
    quantity: g.id === "Mutande" || g.id === "Calzini" ? 2 : g.quantity })));
  assert.equal(parziale.posti.filter((p) => p.tipo === "intimo").reduce((n, p) => n + p.copie, 0), 7);
  assert.equal(parziale.posti.filter((p) => p.tipo === "calzini").reduce((n, p) => n + p.copie, 0), 5);
});

test("essenziali: citta' calda, terme, soglia24 e clima ignoto conservano il conteggio precedente", async () => {
  for (const [attivita, temp] of [[["visite in citta"], 31], [["terme"], 31], [["mare"], 24],
    [["mare"], 20], [["mare"], null]] as [string[], number | null][]) {
    const r = await genera(attivita, temp);
    assert.equal(totale(r, ["mutand"]), 10);
    assert.equal(totale(r, ["calz"]), 10);
  }
});

test("mare a tappe: basta una tappa fresca o ignota per conservare il conteggio completo", async () => {
  for (const tempMax of [20, null]) {
    const r = await genera([], 31, armadio, false, [
      { destinazione: "Mare", giorni: 5, attivita: ["mare"], tempMax: 31 },
      { destinazione: "Altra tappa", giorni: 4, attivita: ["visite in citta"], tempMax },
    ]);
    assert.equal(totale(r, ["mutand"]), 10);
    assert.equal(totale(r, ["calz"]), 10);
  }
});

test("mare a tappe: tutte le tappe calde usano la stessa riduzione del viaggio singolo", async () => {
  const r = await genera([], 31, armadio, false, [
    { destinazione: "Mare", giorni: 5, attivita: ["immersioni"], tempMax: 31 },
    { destinazione: "Citta", giorni: 4, attivita: ["visite in citta"], tempMax: 29 },
  ]);
  assert.equal(totale(r, ["mutand"]), 9);
  assert.equal(totale(r, ["calz"]), 7);
});

test("cammino con mare: intimo e calzini mantengono la rotazione gia' approvata", async () => {
  const r = await genera(["cammino", "mare"]);
  assert.equal(totale(r, ["mutand"]), 3);
  assert.equal(totale(r, ["calz"]), 3);
});

// Gap sintetici: due gruppi incompatibili non devono eludere il limite delle copie.
const gap = (slot: string, sub: string, formality: string[] = []) => ({ slot, tipo: "assente", category: sub === "Shirt" ? "Upper Body" : "Lower Body",
  subCategories: [sub], formality, essential: true });
function propostePantaloni(calde = true, leggero?: boolean, massime?: (number | null)[]) {
  const mancanti = [gap("camicia sera", "Shirt"), gap("pantaloni A", "Trousers", ["Casual"]),
    gap("pantaloni B", "Trousers", ["Formal"])];
  const v = { mancanti: mancanti, mancanti_canonici: mancanti, ideali: [], ripieghi: [], essenziali: [],
    richiesti: mancanti.map((g) => ({ ...g, frequency: g.category === "Upper Body" ? "occasional" : "daily",
      ...(g.category === "Lower Body" && leggero != null ? { capoTipico: { sub: "Trousers", categoria: "Lower Body", leggero } } : {}) })) };
  return postiApp(v, { capi: [], essenziali: [] }, new Map(), { armadio: [],
    viaggio: { giorni: 9, lavatrice: false, ...(massime ? { tappe: massime.map((_, i) => ({ nome: `T${i}`, giorni: i ? 4 : 5 })) } : {}) },
    meteo: { temp_min_media: 22, temp_max_media: calde ? 32 : 22,
      ...(massime ? { _per_tappa: massime.map((m, i) => ({ destinazione: `T${i}`, temp_max_media: m })) } : {}) } }).posti;
}

test("pantaloni al caldo: anche i gruppi distinti per requisiti rispettano il totale delle camicie", () => {
  const p = propostePantaloni();
  assert.equal(p.filter((g) => g.tipo === "Shirt").reduce((n, g) => n + g.copie, 0), 2);
  assert.equal(p.filter((g) => g.tipo === "Trousers").reduce((n, g) => n + g.copie, 0), 2);
  assert.equal(p.filter((g) => g.tipo === "Trousers").length, 2, "i requisiti incompatibili restano distinti");
});

test("pantaloni al caldo: quelli esplicitamente leggeri restano disponibili per il giorno", () => {
  const p = propostePantaloni(true, true);
  assert.equal(p.filter((g) => g.tipo === "Trousers").reduce((n, g) => n + g.copie, 0), 10);
  assert.equal(propostePantaloni(false).filter((g) => g.tipo === "Trousers").reduce((n, g) => n + g.copie, 0), 10);
});


test("pantaloni posseduti: i lunghi pesanti condividono il limite, i leggeri restano da giorno", () => {
  const capi = [
    { item_id: "camicia", category: "Upper Body", subCategory: "Shirt", quantita: 2 },
    { item_id: "a", category: "Lower Body", subCategory: "Trousers", warmth: 3, quantita: 5, slot: "sera", assegnazioni: [{ slot: "sera" }] },
    { item_id: "b", category: "Lower Body", subCategory: "Jeans", warmth: 3, quantita: 3, slot: "sera", assegnazioni: [{ slot: "sera" }] },
    { item_id: "lino", category: "Lower Body", subCategory: "Trousers", warmth: 1, quantita: 4, slot: "giorno", assegnazioni: [{ slot: "giorno" }] },
  ];
  dopo.limitaPantaloniDaSera(capi);
  assert.equal(capi[1].quantita + capi[2].quantita, 2);
  assert.equal(capi[3].quantita, 4);
});

test("pantaloni posseduti: il limite non cancella l'unico capo di un bisogno necessario", () => {
  const capi = [
    { category: "Lower Body", subCategory: "Trousers", warmth: 3, quantita: 3, slot: "copertura ginocchia", imposto: true },
    { category: "Lower Body", subCategory: "Trousers", warmth: 3, quantita: 3, slot: "occasione formale", imposto: true },
  ];
  dopo.limitaPantaloniDaSera(capi);
  assert.equal(capi[0].quantita, 1);
  assert.equal(capi[1].quantita, 1);
});


test("pantaloni: una tappa dal clima ignoto non viene trattata come calda", () => {
  const p = propostePantaloni(true, undefined, [32, null]);
  assert.equal(p.filter((g) => g.tipo === "Trousers").reduce((n, g) => n + g.copie, 0), 10);
});

test("pantaloni da sera: posseduti e proposte condividono lo stesso limite totale", () => {
  const pants = { item_id: "p", item: "Pantaloni", category: "Lower Body", subCategory: "Trousers", warmth: 3,
    quantita: 1, assegnazioni: [{ slot: "gambe", match: "ideale" }] };
  const shirt = { item_id: "s", category: "Upper Body", subCategory: "Shirt", quantita: 2 };
  const mancanti = [{ slot: "gambe", tipo: "quantita_insufficiente", category: "Lower Body",
    subCategories: ["Trousers"], usi_richiesti: 5, usi_coperti: 1 }];
  const p = postiApp({ ideali: [pants, shirt], ripieghi: [], mancanti, essenziali: [],
    richiesti: [{ slot: "gambe", category: "Lower Body", subCategories: ["Trousers"], frequency: "daily" }] },
    { capi: [], essenziali: [] }, new Map([["p", 1], ["s", 2]]), { armadio: caricaArmadio([
      capo("p", "Lower Body", "Trousers", 3, 1), capo("s", "Upper Body", "Shirt", 1, 2)]),
      viaggio: { giorni: 9, lavatrice: false }, meteo: { temp_min_media: 22, temp_max_media: 32 } });
  assert.equal(1 + p.posti.filter((x) => x.tipo === "Trousers").reduce((n, x) => n + x.copie, 0), 2);
});

test("pantaloni proposti: la copertura fissa non viene alterata per aggiungere capi superflui", () => {
  for (const quantita of [2, 4]) {
    const fisso = { item_id: "p", category: "Lower Body", subCategory: "Trousers", warmth: 3, quantita,
      assegnazioni: [{ slot: "sera" }] };
    const prima = structuredClone(fisso);
    const proposte = [{ category: "Lower Body", subCategory: "Trousers", warmth: 3, quantita: 5,
      assegnazioni: [{ slot: "sera" }] }];
    dopo.limitaPantaloniDaSera(proposte, 2, undefined, [fisso]);
    assert.equal(proposte[0].quantita, 0);
    assert.deepEqual(fisso, prima);
  }
});

test("pantaloni proposti: copertura fissa incompatibile non chiude un altro bisogno", () => {
  const fisso = { category: "Lower Body", subCategory: "Trousers", warmth: 3, quantita: 2,
    assegnazioni: [{ slot: "culto" }] };
  const proposte = [{ category: "Lower Body", subCategory: "Trousers", warmth: 3, quantita: 5,
    assegnazioni: [{ slot: "formale" }] }];
  dopo.limitaPantaloniDaSera(proposte, 2, undefined, [fisso]);
  assert.equal(proposte[0].quantita, 1);
});

test("pantaloni da sera: due fasce termiche incompatibili restano entrambe coperte", () => {
  const mancanti = [3, 4].map((w) => ({ ...gap(`fascia${w}`, "Trousers"), warmth_richiesto: [w, w] }));
  const p = postiApp({ ideali: [], ripieghi: [], essenziali: [], mancanti,
    richiesti: mancanti.map((g) => ({ ...g, frequency: "daily" })) }, { capi: [], essenziali: [] }, new Map(),
    { armadio: [], viaggio: { giorni: 9, lavatrice: false }, meteo: { temp_min_media: 16, temp_max_media: 32 } }).posti;
  assert.deepEqual(p.filter((g) => g.tipo === "Trousers").map((g) => [g.copie, g.requisiti?.minWarmth]), [[1, 3], [1, 4]]);
});

test("mare: reggiseno e canottiera intima restano distinti dalle mutande, in ogni ordine", () => {
  const righe = ["Mutande", "Reggiseno", "Canottiera intima"].map((n) => capo(n, "Essentials", "Underwear", 1));
  for (const ordine of [righe, [righe[1], righe[2], righe[0]]]) {
    const es = essenzialiPerViaggio(caricaArmadio(ordine), 9, false, 31, false, true);
    assert.equal(es.find((e) => e.item === "Mutande")?.quantita, 9);
    assert.equal(es.find((e) => e.item === "Reggiseno")?.quantita, 6);
    assert.equal(es.find((e) => e.item === "Canottiera intima")?.quantita, 10);
  }
});


test("pantaloni finali: il profilo sul caldo resta disponibile anche all'adapter", () => {
  for (const [warmth, voto, leggero, quantita] of [[2, 0, false, 1], [2, 1, true, 2], [3, 1, true, 5]] as const) {
    const righe = [capo("p", "Lower Body", "Trousers", warmth, 20)];
    const raw = JSON.stringify([{ slot: "gambe", category: "Lower Body", subCategories: ["Trousers"],
      minWarmth: 1, maxWarmth: 4, frequency: "daily", essential: true }]);
    const r = strategySlots(raw, caricaArmadio(righe), { giorni: 9, lavatrice: false,
      attivita: ["visite in citta"], temp_min: 20, temp_max: 32, bagaglio: "trolley medio",
      profili_capi: { p: { caldo_torrido: voto } } });
    const pantaloni = [...r.ideali, ...r.ripieghi].find((g) => g.item_id === "p");
    assert.equal(pantaloni?.leggero, leggero);
    assert.equal(pantaloni?.quantita, quantita);
  }
});
