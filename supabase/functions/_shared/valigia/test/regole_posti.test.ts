// Le regole fisse dei suggerimenti (posti.ts): invarianti sulle celle del bench e casi mirati.
// Per le 888 celle: PACKLOG_ORACOLO_CELLE=/percorso/celle.json node --test test/regole_posti.test.ts
// (esporta_oracolo.py celle); senza, gira sul campione committato.
import { test } from "node:test";
import assert from "node:assert/strict";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { strategySlots } from "../slots.ts";
import { nomePosto, postiApp, type PostoApp } from "../posti.ts";
import { caricaCelle, rigiocaCella, violazioni } from "./regole_posti.ts";

const file = process.env.PACKLOG_ORACOLO_CELLE ?? new URL("./oracolo_celle_campione.json", import.meta.url);
const celle = caricaCelle(file);

for (const armadio of ["vuoto", "medio"] as const) {
  test(`regole fisse: nessuna violazione su ${celle.length} celle, armadio ${armadio}`, () => {
    const trovate: string[] = [];
    for (const c of celle) {
      const r = rigiocaCella(c, armadio);
      for (const v of violazioni(r)) trovate.push(`${r.id}: ${v.regola} (${v.posto})`);
    }
    assert.deepEqual(trovate.slice(0, 10), [], `${trovate.length} violazioni`);
  });
}

// ── Casi mirati, sui mancanti scritti a mano ───────────────────────────────

const assente = (slot: string, category: string, subCategories: string[], extra: Record<string, unknown> = {}) =>
  ({ slot, tipo: "assente", imposto: false, category, essential: true, subCategories, reason: "r",
    fonte: "slot", priorita: "necessario", ...extra });
const ESSENZIALI = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
const posti = (mancanti: Record<string, any>[], meteo: Record<string, any>, attivita: string[] = [],
  richiesti: Record<string, any>[] = []): PostoApp[] =>
  postiApp({ mancanti_canonici: mancanti, richiesti, essenziali: ESSENZIALI }, { capi: [], essenziali: [] }, new Map(),
    { meteo, viaggio: { giorni: 6, lavatrice: true, attivita }, armadio: [], lingua: "it" }).posti;
const trovato = (p: PostoApp[], tipo: string) => p.find((x) => x.tipo === tipo);

const LEON_MAGGIO = { temp_min_media: 10, temp_max_media: 23, giorni_di_pioggia: 0 };
const FREDDO_VERO = { temp_min_media: 2, temp_max_media: 8, giorni_di_pioggia: 0 };
const MALDIVE = { temp_min_media: 27, temp_max_media: 30, giorni_di_pioggia: 4 };

test("giacca: con minime di 10 gradi e senza pioggia e' leggera e utile, non invernale e importante", () => {
  for (const warmth of [[3, 4], [4, 5]]) {
    const giacca = trovato(posti([assente("capospalla", "Outerwear", ["Coat", "Down Jacket", "Windbreaker"], { warmth_richiesto: warmth })],
      LEON_MAGGIO), "Outerwear")!;
    assert.equal(giacca.nome, "Giacca leggera", `calore ${warmth}`);
    assert.equal(giacca.livello, "utile");
  }
});

test("giacca: col freddo vero e' invernale e importante", () => {
  const giacca = trovato(posti([assente("capospalla", "Outerwear", ["Coat", "Down Jacket"], { warmth_richiesto: [4, 5] })],
    FREDDO_VERO), "Outerwear")!;
  assert.equal(giacca.nome, "Giacca invernale");
  assert.equal(giacca.livello, "importante");
});

test("giacca: l'impermeabile e' importante solo se il meteo ha giorni di pioggia", () => {
  const guscio = () => assente("pioggia", "Outerwear", ["Rain Jacket"], { warmth_richiesto: [1, 2], impermeabilita_richiesta: 2 });
  const asciutto = trovato(posti([guscio()], { ...LEON_MAGGIO, giorni_di_pioggia: 0.6 }), "Outerwear")!;
  assert.equal(asciutto.livello, "utile");
  assert.equal(asciutto.nome, "Giacca leggera");
  const bagnato = trovato(posti([guscio()], { ...LEON_MAGGIO, giorni_di_pioggia: 3 }), "Outerwear")!;
  assert.equal(bagnato.livello, "importante");
  assert.equal(bagnato.nome, "Giacca impermeabile");
  assert.equal(bagnato.requisiti?.minWaterResistance, 2);
});

test("pioggia a tappe: conta il meteo delle tappe del bisogno, non quello del viaggio", () => {
  const meteo = { temp_min_media: 12, temp_max_media: 25, giorni_di_pioggia: 4, _per_tappa: [
    { destinazione: "Secca", giorni: 3, temp_min_media: 12, temp_max_media: 27, giorni_di_pioggia: 0 },
    { destinazione: "Umida", giorni: 3, temp_min_media: 12, temp_max_media: 23, giorni_di_pioggia: 4 }] };
  const viaggio = { giorni: 6, tappe: [{ nome: "Secca", giorni: 3 }, { nome: "Umida", giorni: 3 }] };
  const per = (tappa: string) => postiApp({ mancanti_canonici: [assente("pioggia", "Outerwear", ["Rain Jacket"],
    { warmth_richiesto: [1, 2], impermeabilita_richiesta: 2, tappe: [tappa] })], richiesti: [], essenziali: ESSENZIALI },
  { capi: [], essenziali: [] }, new Map(), { meteo, viaggio, armadio: [] }).posti.find((p) => p.tipo === "Outerwear")!.livello;
  assert.equal(per("Secca"), "utile");
  assert.equal(per("Umida"), "importante");
});

test("ombrello: mai suggerito, nemmeno fra altre sottocategorie o fra i pezzi in meno", () => {
  assert.deepEqual(posti([assente("Ombrello", "Accessory", ["Umbrella"])], MALDIVE).filter((p) => /mbrell/.test(p.tipo + p.nome)), []);
  const misto = posti([assente("pioggia", "Accessory", ["Umbrella", "Cap/Hat"])], MALDIVE);
  assert.ok(!misto.some((p) => p.tipo === "Umbrella"));
  assert.ok(misto.some((p) => p.tipo === "Cap/Hat"));
});

test("Maldive: niente scarponi importanti, muta utile, costume importante, niente scarpette senza acqua", () => {
  const p = posti([
    assente("scarpe", "Shoes", ["Hiking Boots"], { warmth_richiesto: [2, 2] }),
    assente("muta", "Lower Body", ["Wetsuit"]), assente("costume", "Lower Body", ["Swimwear"]),
  ], MALDIVE, ["immersioni", "mare", "escursioni leggere"]);
  assert.equal(trovato(p, "Hiking Boots")!.livello, "utile");
  assert.match(trovato(p, "Hiking Boots")!.nome, /^Scarpe da trekking/);
  assert.equal(trovato(p, "Wetsuit")!.livello, "utile");
  assert.equal(trovato(p, "Swimwear")!.livello, "importante");
  const senzaAcqua = posti([assente("scoglio", "Shoes", ["Water Shoes"])], MALDIVE, ["visite in citta"]);
  assert.equal(trovato(senzaAcqua, "Water Shoes"), undefined);
});

test("scarponi: col freddo vero invernali, col trekking vero importanti anche col caldo", () => {
  const freddo = trovato(posti([assente("scarpe", "Shoes", ["Hiking Boots"])], FREDDO_VERO, ["trekking"]), "Hiking Boots")!;
  assert.equal(freddo.nome, "Scarponi da trekking invernali");
  const caldo = trovato(posti([assente("scarpe", "Shoes", ["Hiking Boots"], { warmth_richiesto: [1, 2] })],
    { temp_min_media: 22, temp_max_media: 32, giorni_di_pioggia: 0 }, ["trekking"]), "Hiking Boots")!;
  assert.equal(caldo.livello, "importante");
  assert.equal(caldo.nome, "Scarpe da trekking");
  const fresco = trovato(posti([assente("scarpe", "Shoes", ["Hiking Boots"], { warmth_richiesto: [2, 3] })],
    { temp_min_media: 8, temp_max_media: 16, giorni_di_pioggia: 0 }, ["trekking"]), "Hiking Boots")!;
  assert.equal(fresco.nome, "Scarponi da trekking");
});

test("nomi: il freddo non rende caldi leggings, camicie e polo", () => {
  const p = posti([
    assente("leggings", "Lower Body", ["Leggings"], { warmth_richiesto: [3, 5] }),
    assente("camicia", "Upper Body", ["Shirt"], { warmth_richiesto: [3, 5] }),
    assente("maglione", "Upper Body", ["Sweater"], { warmth_richiesto: [3, 5] }),
  ], FREDDO_VERO);
  assert.equal(trovato(p, "Leggings")!.nome, "Leggings");
  assert.match(trovato(p, "Shirt")!.nome, /^Camic(ia|ie)$/);
  for (const sub of ["T-Shirt", "Polo", "Shirt", "Leggings", "Tank Top", "Crop Top"]) {
    const nome = nomePosto({ sub, categoria: "Upper Body" }, 3, "freddo", "it").nome;
    assert.ok(!/cald/i.test(nome), `${sub}: ${nome}`);
  }
  assert.match(trovato(p, "Sweater")!.nome, /^Maglion(e|i) cald(o|i)$/);
});

test("camicie eleganti: solo con lavoro, cerimonie o serate formali; 'cene informali' non lo e'", () => {
  const presentabile = () => assente("capo presentabile per la sera", "Upper Body", ["Polo", "Shirt"],
    { formality: ["Business", "Formal", "Smart Casual"] });
  const caldo = { temp_min_media: 22, temp_max_media: 31, giorni_di_pioggia: 0 };
  const informale = trovato(posti([presentabile()], caldo, ["visite a siti religiosi", "cene informali"]), "Shirt")!;
  assert.match(informale.nome, /^Camic(ia|ie)$/);
  assert.equal(informale.livello, "utile");
  for (const attivita of [["matrimonio"], ["cena formale"], ["riunioni di lavoro"], ["cerimonia"]]) {
    const formale = trovato(posti([presentabile()], caldo, attivita), "Shirt")!;
    assert.match(formale.nome, /^Camic(ia|ie) elegant(e|i)$/, attivita.join());
    assert.equal(formale.livello, "importante");
  }
});

test("camicie per spalle coperte: al massimo due, non una al giorno", () => {
  const spalle = assente("spalle coperte", "Upper Body", ["Shirt", "T-Shirt", "Polo", "Sweater"], { coverage: ["Long-sleeve"], formality: [] });
  const camicie = trovato(posti([spalle], { temp_min_media: 22, temp_max_media: 31, giorni_di_pioggia: 0 }, ["visite a templi"],
    [{ slot: "spalle coperte", category: "Upper Body", capoTipico: { sub: "Shirt", categoria: "Upper Body" } }]), "Shirt")!;
  assert.ok(camicie.copie <= 2, `${camicie.copie}`);
});

// ── Copertura leggera: l'armadio ha solo capi troppo caldi ───────────────────

const capo = (id: string, category: string, subCategory: string, warmth: number, coverage: string): RigaArmadio => ({
  id, name: id, quantity: 3, ai_metadata: { category, subCategory, warmth, activityTags: ["Everyday"], formality: "Casual",
    waterResistance: 0, bulk: 2, coverage } });
const slotCulto = (nome: string, category: string, subCategories: string[], coverage: string[]) => ({ slot: nome, category, subCategories,
  minWarmth: 1, maxWarmth: 5, minWaterResistance: 0, formality: ["Casual"], activityTags: [], coverage, frequency: "daily",
  essential: true, reason: "x" });

test("culto col caldo: la valigia prende i capi caldi che ci sono e i suggerimenti propongono quelli leggeri", () => {
  const righe = [capo("Camicia di flanella", "Upper Body", "Shirt", 3, "Long-sleeve"), capo("Jeans pesanti", "Lower Body", "Jeans", 3, "Full-length")];
  const items = caricaArmadio(righe);
  const attivita = ["visite a siti religiosi"];
  const valigia = strategySlots(JSON.stringify([
    slotCulto("spalle coperte", "Upper Body", ["Shirt", "T-Shirt", "Polo", "Sweater"], ["Long-sleeve"]),
    slotCulto("ginocchia coperte", "Lower Body", ["Trousers", "Skirt", "Jeans"], ["Full-length"])]), items,
  { giorni: 5, lavatrice: false, attivita, temp_min: 24, temp_max: 33, bagaglio: "trolley medio", giorni_pioggia: 0 });
  const presi = [...valigia.ideali, ...valigia.ripieghi].filter((g: any) => g.quantita > 0).map((g: any) => g.item_id);
  assert.ok(presi.includes("Camicia di flanella") && presi.includes("Jeans pesanti"), `la valigia prende ${presi}`);
  const { posti: suggeriti } = postiApp(valigia, { capi: [], essenziali: [] }, new Map(righe.map((r) => [String(r.id), 3])),
    { meteo: { temp_min_media: 24, temp_max_media: 33, giorni_di_pioggia: 0 }, viaggio: { giorni: 5, lavatrice: false, attivita }, armadio: items });
  for (const tipo of ["Shirt", "Trousers"]) {
    const leggero = trovato(suggeriti, tipo)!;
    assert.ok(leggero, `manca il suggerimento leggero per ${tipo}: ${suggeriti.map((p) => p.nome)}`);
    assert.ok((leggero.requisiti?.maxWarmth ?? 5) <= 2, `${tipo}: calore massimo ${leggero.requisiti?.maxWarmth}`);
    assert.match(leggero.motivo ?? "", /troppo pesante/);
  }
});
