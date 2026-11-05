// Attivita' con responsabilita' separate (Davide, 31 ottobre): gli stessi casi di
// test_riverbero_quota.py e test_attivita_separate.py del bench.
// Uso: node --test test/attivita.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import * as K from "../costanti.ts";
import { eTrekking, riverbero } from "../inject.ts";
import { strategySlots } from "../slots.ts";

test("riverbero: il trekking sopra la soglia di quota, le voci vecchie come prima", () => {
  const s = K.SOGLIA_QUOTA_RIVERBERO as number;
  assert.ok(riverbero(new Set(["trekking"]), null, s));
  assert.ok(riverbero(new Set(["escursioni leggere"]), null, s + 500));
  assert.ok(!riverbero(new Set(["trekking"]), null, s - 1));
  assert.ok(!riverbero(new Set(["visite in citta"]), null, s + 1000));
  assert.ok(!riverbero(new Set(["trekking"]), null, null));
  assert.ok(riverbero(new Set(["escursioni in quota"]), null, 0));
});

const capo = (id: string, category: string, subCategory: string, warmth: number, formality: string,
  activityTags: string[]): RigaArmadio => ({
  id, name: id, quantity: null,
  ai_metadata: { category, subCategory, warmth, formality, activityTags, waterResistance: 0, bulk: 1 },
});

const armadio = caricaArmadio([
  capo("tshirt", "Upper Body", "T-Shirt", 2, "Casual", ["Everyday"]),
  capo("camicia", "Upper Body", "Shirt", 2, "Smart Casual", ["Everyday", "Office"]),
  capo("chino", "Lower Body", "Trousers", 2, "Smart Casual", ["Everyday", "Office"]),
  capo("blazer", "Outerwear", "Blazer", 2, "Business", ["Office", "Formal"]),
  capo("giubbotto", "Outerwear", "Casual Jacket", 3, "Casual", ["Everyday"]),
  capo("sneakers", "Shoes", "Sneakers", 2, "Casual", ["Everyday"]),
  capo("scarponi", "Shoes", "Hiking Boots", 3, "Casual", ["Hiking"]),
]);

// Il modello che chiede un capo da lavoro anche se non serve.
const SLOTS = JSON.stringify([
  ["busto", "Upper Body", ["T-Shirt"], ["Casual"]], ["gambe", "Lower Body", ["Trousers"], ["Casual"]],
  ["scarpe", "Shoes", ["Sneakers"], ["Casual"]], ["giacca elegante", "Outerwear", ["Blazer"], ["Business", "Formal"]],
].map(([slot, category, subCategories, formality]) => ({
  slot, category, subCategories, minWarmth: 1, maxWarmth: 3, formality, activityTags: [], minWaterResistance: 0,
  frequency: "daily", essential: true, reason: "t",
})));

const richiesti = (attivita: string[], quota_m: number | null = null) => {
  const r = strategySlots(SLOTS, armadio, { giorni: 4, lavatrice: false, attivita, temp_min: 14, temp_max: 22,
    bagaglio: "trolley medio", quota_m });
  return { r, slot: (r.richiesti as Record<string, any>[]).map((x) => x.slot) };
};

test("Cene e serate: un capo per la sera, niente slot da lavoro ne' blazer", () => {
  const { r, slot } = richiesti(["cene al ristorante", "vita notturna"]);
  assert.ok(!slot.includes("giacca elegante") && !slot.includes("strato formale"), JSON.stringify(slot));
  assert.ok(slot.includes(K.SLOT_SERA_PRESENTABILE), JSON.stringify(slot));
  assert.ok(![...r.ideali, ...r.ripieghi].some((x: Record<string, any>) => x.item === "blazer"));
});

test("Lavoro: il blazer resta", () => {
  const { slot } = richiesti(["riunioni di lavoro", "cene di lavoro"]);
  assert.ok(slot.includes("strato formale") || slot.includes("giacca elegante"), JSON.stringify(slot));
});

test("trekking: il bisogno del riverbero solo in quota", () => {
  assert.ok(richiesti(["trekking"], 3500).slot.includes("occhiali da sole"));
  assert.ok(!richiesti(["trekking"], 400).slot.includes("occhiali da sole"));
});

test("passeggiate: escursioni leggere non equivalgono a trekking tecnico", () => {
  for (const a of ["escursioni leggere", "Escursione leggera", "ESCURSIONI LEGGERE nella natura"]) {
    assert.equal(eTrekking([a]), false, a);
  }
  for (const a of ["trekking", "escursioni in quota", "escursioni", "escursioni leggere e trekking",
    "escursioni leggermente impegnative"]) {
    assert.equal(eTrekking([a]), true, a);
  }
  assert.equal(eTrekking(["escursioni leggere", "trekking"]), true);
});

test("passeggiate: il sistema non impone Hiking ai capi quotidiani o coprenti", () => {
  for (const attivita of [["escursioni leggere"], ["escursioni leggere", "mare", "visite a siti religiosi"]]) {
    const { r } = richiesti(attivita);
    assert.ok(r.richiesti.every((s: any) => !(s.activityTags ?? []).includes("Hiking")),
      JSON.stringify(r.richiesti));
    assert.ok([...r.ideali, ...r.ripieghi].some((g: any) => g.item_id === "sneakers"));
  }
});

test("passeggiate: anche una preferenza Hiking del modello resta proporzionata alle attivita' dichiarate", () => {
  const input = JSON.parse(SLOTS).map((s: any) => ({ ...s, activityTags: ["Hiking"] }));
  const r = strategySlots(JSON.stringify(input), armadio,
    { giorni: 4, lavatrice: false, attivita: ["escursioni leggere"], temp_min: 14, temp_max: 22,
      bagaglio: "trolley medio" });
  assert.ok(r.richiesti.every((s: any) => !s.activityTags.includes("Hiking")));
  assert.ok([...r.ideali, ...r.ripieghi].some((g: any) => g.item_id === "sneakers"));
});

test("passeggiate: il trekking esplicito conserva scarpe con ruolo tecnico", () => {
  const { r } = richiesti(["escursioni leggere", "trekking"]);
  assert.ok(r.richiesti.some((s: any) => s.category === "Shoes" && s.activityTags.includes("Hiking")));
  assert.ok([...r.ideali, ...r.ripieghi].some((g: any) => g.item_id === "scarponi"));
});

import { servePerTappa } from "../tappe.ts";
test("passeggiate a tappe: gli obblighi Hiking restano nella sola tappa di trekking", () => {
  const meteo = { temp_min_media: 18, temp_max_media: 25, giorni_di_pioggia: 0 };
  const controlla = (attivita: string[]) => {
    const mancanti: any[] = [];
    servePerTappa({ destinazione: "Tappa", giorni: 4, meteo, attivita }, [], [], new Set(), 0,
      false, null, false, mancanti);
    return mancanti;
  };
  const leggera = controlla(["escursioni leggere", "visite a siti religiosi"]);
  assert.ok(!leggera.some((g) => g.ruolo === "trekking" || g.requiredActivityTags?.includes("Hiking")));
  const tecnica = controlla(["trekking"]);
  assert.ok(tecnica.some((g) => g.ruolo === "trekking"));
  assert.ok(tecnica.some((g) => g.requiredActivityTags?.includes("Hiking")));
});
