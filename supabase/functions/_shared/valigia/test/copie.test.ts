// Copie possedute (Davide, 31 ottobre): la quantita' dell'app e' il numero vero di copie.
// Il generatore non ne mette mai di piu', passa ad altri capi uguali e avvisa solo se
// l'armadio non basta. Gli stessi casi di test_copie_possedute.py del bench.
// Uso: node --test test/copie.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { caricaArmadio, type Capo, type RigaArmadio } from "../capo.ts";
import { essenzialiPerViaggio } from "../quantita.ts";
import { strategySlots } from "../slots.ts";
import { uscitaApp } from "../uscita.ts";

const COLORI = ["grigia", "blu", "bianca", "nera", "verde", "rossa"];
const scheda = (category: string, subCategory: string, bulk = 1) => ({
  category, subCategory, warmth: 2, formality: "Casual", activityTags: ["Everyday"], waterResistance: 0, bulk,
});

function armadio(copie: number | null, colori = COLORI): Capo[] {
  const righe: RigaArmadio[] = [
    ...colori.map((c) => ({ id: `t-${c}`, name: `T-shirt ${c}`, quantity: copie,
      ai_metadata: scheda("Upper Body", "T-Shirt") })),
    { id: "jeans", name: "Jeans", quantity: 1, ai_metadata: scheda("Lower Body", "Jeans", 2) },
    { id: "sneakers", name: "Sneakers", quantity: 1, ai_metadata: scheda("Shoes", "Sneakers", 2) },
  ];
  return caricaArmadio(righe);
}

const SLOTS = JSON.stringify([["maglie da citta'", "Upper Body", ["T-Shirt"]], ["gambe", "Lower Body", ["Jeans"]],
  ["scarpe", "Shoes", ["Sneakers"]]].map(([slot, category, subCategories]) => ({
  slot, category, subCategories, minWarmth: 1, maxWarmth: 3, formality: ["Casual"], activityTags: ["Everyday"],
  minWaterResistance: 0, frequency: "daily", essential: true, reason: "t",
})));

const valigia = (capi: Capo[], giorni: number) =>
  strategySlots(SLOTS, capi, { giorni, lavatrice: false, temp_min: 14, temp_max: 22, bagaglio: "valigia grande" });

const tshirt = (r: Record<string, any>) => Object.fromEntries([...r.ideali, ...r.ripieghi]
  .filter((x: Record<string, any>) => x.subCategory === "T-Shirt").map((x: Record<string, any>) => [x.item_id, x.quantita]));

test("sei T-shirt, una copia ciascuna: nessuna oltre la sua copia, il bisogno va sulle altre", () => {
  const r = valigia(armadio(1), 3);
  const q = tshirt(r);
  assert.ok(Object.values(q).every((n) => n === 1), JSON.stringify(q));
  assert.ok(Object.values(q).reduce((a: number, b) => a + (b as number), 0) >= 3, JSON.stringify(q));
  assert.equal(r.mancanti.filter((g: Record<string, any>) => g.tipo === "quantita_insufficiente").length, 0);
});

test("una T-shirt sola: resta una, e l'avviso dice che ne servono di piu'", () => {
  const r = valigia(armadio(1, ["grigia"]), 6);
  assert.deepEqual(tshirt(r), { "t-grigia": 1 });
  const gap = r.mancanti.find((g: Record<string, any>) => g.tipo === "quantita_insufficiente" && g.category === "Upper Body");
  assert.ok(gap, JSON.stringify(r.mancanti));
  // L'avviso per l'app, in italiano e in inglese.
  const avvisi = (lingua: "it" | "en") => uscitaApp({ mancanti_canonici: [{ ...gap, priorita: "consigliato" }] },
    { capi: [], essenziali: [] }, new Map(), { lingua }).avvisi.map((a) => a.titolo);
  assert.deepEqual(avvisi("it"), ["Ti serve più di una maglietta per il viaggio"]);
  assert.deepEqual(avvisi("en"), ["You need more than one T-shirt for the trip"]);
});

test("senza quantita' (armadi del banco) le copie restano quelle di sempre", () => {
  const r = valigia(armadio(null, ["grigia"]), 6);
  assert.ok(tshirt(r)["t-grigia"] > 1, JSON.stringify(tshirt(r)));
});

test("calzini su due oggetti; se non bastano il resto torna sull'ultimo e l'uscita avvisa", () => {
  const calzini = caricaArmadio(["neri", "bianchi"].map((n, i) => ({ id: `c${i}`, name: `Calzini ${n}`, quantity: 4 })));
  assert.deepEqual(essenzialiPerViaggio(calzini, 6, false).map((x) => [x.item_id, x.quantita]), [["c0", 4], ["c1", 3]]);
  const poche = essenzialiPerViaggio(calzini.slice(0, 1), 6, false);
  assert.deepEqual(poche, [{ item: "Calzini neri", item_id: "c0", radice: "calz", quantita: 7, bulk: 1 }]);
  const motivi = { capi: [], essenziali: poche.map((e) => ({ ...e,
    motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "f" } })) };
  const [a] = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["c0", 4]])).avvisi;
  assert.equal(a.titolo, "Ti servono più pezzi di Calzini neri");
  assert.equal(a.perche, "Ne servirebbero 7, nell'armadio ne hai 4.");
});
