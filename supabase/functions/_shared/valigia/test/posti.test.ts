// I posti dai mancanti: livello (importante/utile) e nome mostrato all'utente.
// Uso: node --test valigia/test/posti.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { livelloPosto, nomePosto, qualificaDelGap } from "../posti.ts";
import { strategySlots } from "../slots.ts";
import { capoDelGap, NOME_CATEGORIA, NOME_SOTTOCATEGORIA } from "../uscita.ts";
import { NOMI_CATEGORIA, NOMI_SOTTOCATEGORIA } from "../posti_nomi.ts";

const livello = (g: Record<string, any>, viaggioFreddo = false, attivita: string[] = []) =>
  livelloPosto(g, capoDelGap(g, viaggioFreddo), viaggioFreddo, attivita);

test("livello: la giacca col freddo e' importante, il maglione col freddo no", () => {
  const giacca = { tipo: "assente", category: "Outerwear", subCategories: ["Coat", "Down Jacket", "Casual Jacket", "Windbreaker"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  const maglione = { tipo: "assente", category: "Upper Body", subCategories: ["Sweater"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  assert.equal(livelloPosto(giacca, capoDelGap(giacca, true), true), "importante");
  assert.equal(livelloPosto(maglione, capoDelGap(maglione, true), true), "utile");
});

test("livello: magliette utili; costume al mare, scarponi al trekking e camicia al matrimonio importanti", () => {
  const maglietta = { tipo: "assente", category: "Upper Body", subCategories: ["T-Shirt"], priorita: "necessario" };
  const costume = { tipo: "assente", category: "Lower Body", subCategories: ["Swimwear"], priorita: "consigliato" };
  const scarponi = { tipo: "assente", category: "Shoes", subCategories: ["Hiking Boots"], priorita: "necessario" };
  const camicia = { tipo: "assente", category: "Upper Body", subCategories: ["Shirt"], formality: ["Formal"] };
  assert.equal(livello(maglietta), "utile");
  assert.equal(livello(costume, false, ["mare"]), "importante");
  assert.equal(livello(scarponi, false, ["trekking"]), "importante");
  assert.equal(livello(camicia, false, ["matrimonio"]), "importante");
});

test("livello: scarpe senza freddo ne' pioggia sono utili", () => {
  const scarpe = { tipo: "assente", category: "Shoes", subCategories: ["Sneakers"], warmth_richiesto: [1, 3] };
  assert.equal(livello(scarpe), "utile");
  assert.equal(qualificaDelGap(scarpe, capoDelGap(scarpe), false), null);
});

test("livello: scarpe con la pioggia sono importanti, un accessorio col freddo pure", () => {
  const scarpe = { tipo: "assente", category: "Shoes", subCategories: ["Sneakers"], impermeabilita_richiesta: 2 };
  const guanti = { tipo: "assente", category: "Accessory", subCategories: ["Gloves"], warmth_richiesto: [3, 5] };
  assert.equal(livello(scarpe), "importante");
  assert.equal(livello(guanti), "importante");
});

test("livello: l'ombrello resta utile anche con pioggia, freddo o un'occasione formale", () => {
  for (const attivita of [[], ["mare"], ["congresso"]]) {
    assert.equal(livello({ category: "Accessory", subCategories: ["Umbrella"],
      impermeabilita_richiesta: 2, warmth_richiesto: [4, 5], formality: ["Formal"] }, true, attivita), "utile");
  }
});

test("qualifica: freddo, poi acqua, poi elegante", () => {
  const freddoAcqua = { category: "Outerwear", subCategories: ["Coat"], warmth_richiesto: [4, 5], impermeabilita_richiesta: 2 };
  const acqua = { category: "Outerwear", subCategories: ["Coat"], warmth_richiesto: [1, 2], impermeabilita_richiesta: 2 };
  const elegante = { category: "Upper Body", subCategories: ["Shirt"], formality: ["Business"] };
  assert.equal(qualificaDelGap(freddoAcqua, capoDelGap(freddoAcqua), false), "freddo");
  assert.equal(qualificaDelGap(acqua, capoDelGap(acqua), false), "acqua");
  assert.equal(qualificaDelGap(elegante, capoDelGap(elegante), false), "elegante");
});

test("nomi del mockup", () => {
  assert.deepEqual(nomePosto({ sub: null, categoria: "Outerwear" }, 1, "freddo", "it"), { nome: "Giacca invernale", aggiungi: "Aggiungi la tua" });
  assert.deepEqual(nomePosto({ sub: null, categoria: "Shoes" }, 1, "freddo", "it"), { nome: "Scarpe invernali", aggiungi: "Aggiungi le tue" });
  assert.deepEqual(nomePosto({ sub: "Cap/Hat", categoria: "Accessory" }, 1, "freddo", "it"), { nome: "Cappello caldo", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Gloves", categoria: "Accessory" }, 1, "freddo", "it"), { nome: "Guanti", aggiungi: "Aggiungi i tuoi" });
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, "freddo", "it").nome, "Maglioni caldi");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 5, null, "it").nome, "Magliette");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 1, null, "it").nome, "Maglietta");
  assert.equal(nomePosto({ sub: "Trousers", categoria: "Lower Body" }, 1, null, "it").nome, "Pantaloni");
  assert.deepEqual(nomePosto({ sub: null, categoria: "Shoes" }, 1, "freddo", "en"), { nome: "Winter shoes", aggiungi: "Add yours" });
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, "freddo", "en").nome, "Warm sweaters");
});

test("nomi: qualificatori in italiano e inglese, concordati col nome mostrato", () => {
  assert.equal(nomePosto({ sub: "Scarf", categoria: "Accessory" }, 1, "freddo", "it").nome, "Sciarpa calda");
  assert.equal(nomePosto({ sub: "Scarf", categoria: "Accessory" }, 2, "freddo", "it").nome, "Sciarpe calde");
  assert.equal(nomePosto({ sub: "Trousers", categoria: "Lower Body" }, 1, "freddo", "it").nome, "Pantaloni caldi");
  assert.equal(nomePosto({ sub: "Coat", categoria: "Outerwear" }, 2, "freddo", "it").nome, "Cappotti invernali");
  assert.equal(nomePosto({ sub: "Boots", categoria: "Shoes" }, 1, "acqua", "it").nome, "Stivali impermeabili");
  assert.equal(nomePosto({ sub: "Casual Jacket", categoria: "Outerwear" }, 1, "acqua", "it").nome, "Giacca casual impermeabile");
  assert.equal(nomePosto({ sub: "Shirt", categoria: "Upper Body" }, 1, "elegante", "it").nome, "Camicia elegante");
  assert.equal(nomePosto({ sub: "Shirt", categoria: "Upper Body" }, 2, "elegante", "it").nome, "Camicie eleganti");
  assert.equal(nomePosto({ sub: null, categoria: "Outerwear" }, 1, "acqua", "en").nome, "Waterproof jacket");
  assert.equal(nomePosto({ sub: "Shirt", categoria: "Upper Body" }, 1, "elegante", "en").nome, "Smart shirt");
  assert.equal(nomePosto({ sub: "Scarf", categoria: "Accessory" }, 1, "freddo", "en").nome, "Warm scarf");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 5, null, "en").nome, "T-shirts");
  assert.equal(nomePosto({ sub: "Gloves", categoria: "Accessory" }, 1, "freddo", "en").nome, "Gloves");
});

test("nomi: articolo di 'aggiungi' secondo genere e numero", () => {
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 1, null, "it").aggiungi, "Aggiungi il tuo");
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, null, "it").aggiungi, "Aggiungi i tuoi");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 1, null, "it").aggiungi, "Aggiungi la tua");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 2, null, "it").aggiungi, "Aggiungi le tue");
  // nome solo plurale: anche con una copia si usa il plurale
  assert.equal(nomePosto({ sub: "Trousers", categoria: "Lower Body" }, 1, null, "it").aggiungi, "Aggiungi i tuoi");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 2, null, "en").aggiungi, "Add yours");
});

test("nomi: chi lo dice gia' non si qualifica", () => {
  for (const [sub, categoria] of [["Down Jacket", "Outerwear"], ["Rain Jacket", "Outerwear"], ["Snow Boots", "Shoes"],
    ["Thermal Top", "Upper Body"], ["Thermal Bottoms", "Lower Body"], ["Ski Jacket", "Outerwear"], ["Ski Pants", "Lower Body"],
    ["Ski Suit", "Outerwear"], ["Gloves", "Accessory"], ["Umbrella", "Accessory"], ["Blazer", "Outerwear"],
    ["Dress Shoes", "Shoes"]] as const) {
    for (const lingua of ["it", "en"] as const) {
      const senza = nomePosto({ sub, categoria }, 1, null, lingua).nome;
      for (const q of ["freddo", "acqua", "elegante"] as const) {
        assert.equal(nomePosto({ sub, categoria }, 1, q, lingua).nome, senza, `${sub} ${q} ${lingua}`);
      }
    }
  }
});

test("ogni sottocategoria e categoria ha il nome in tutte e due le lingue", () => {
  assert.deepEqual(Object.keys(NOMI_SOTTOCATEGORIA).sort(), Object.keys(NOME_SOTTOCATEGORIA).sort());
  assert.deepEqual(Object.keys(NOMI_CATEGORIA).sort(), Object.keys(NOME_CATEGORIA).sort());
  const capi = [
    ...Object.keys(NOME_SOTTOCATEGORIA).map((sub) => ({ sub, categoria: "Accessory" })),
    ...Object.keys(NOME_CATEGORIA).map((categoria) => ({ sub: null, categoria })),
  ];
  for (const capo of capi) {
    for (const lingua of ["it", "en"] as const) {
      for (const copie of [1, 2]) {
        for (const q of [null, "freddo", "acqua", "elegante"] as const) {
          const r = nomePosto(capo, copie, q, lingua);
          assert.ok(r.nome.trim().length > 0, `${capo.sub ?? capo.categoria} ${lingua} ${copie} ${q}`);
          assert.match(r.nome, /^\p{Lu}/u, `${capo.sub ?? capo.categoria} maiuscola`);
          assert.ok(r.aggiungi.trim().length > 0);
        }
      }
    }
  }
});

test("nomi invariabili (Polo, Pile, Gilet, Blazer): con una copia singolare, con piu' copie plurale", () => {
  // stessa voce per singolare e plurale ma NON solo plurali: una copia = singolare e articolo singolare
  assert.deepEqual(nomePosto({ sub: "Fleece", categoria: "Upper Body" }, 1, "freddo", "it"), { nome: "Pile", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Fleece", categoria: "Upper Body" }, 2, "freddo", "it"), { nome: "Pile", aggiungi: "Aggiungi i tuoi" });
  assert.deepEqual(nomePosto({ sub: "Vest", categoria: "Outerwear" }, 1, "freddo", "it"), { nome: "Gilet invernale", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Vest", categoria: "Outerwear" }, 2, "freddo", "it"), { nome: "Gilet invernali", aggiungi: "Aggiungi i tuoi" });
  assert.deepEqual(nomePosto({ sub: "Blazer", categoria: "Outerwear" }, 1, null, "it"), { nome: "Blazer", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Blazer", categoria: "Outerwear" }, 2, null, "it"), { nome: "Blazer", aggiungi: "Aggiungi i tuoi" });
  assert.deepEqual(nomePosto({ sub: "Polo", categoria: "Upper Body" }, 1, "elegante", "it"), { nome: "Polo elegante", aggiungi: "Aggiungi la tua" });
  assert.deepEqual(nomePosto({ sub: "Polo", categoria: "Upper Body" }, 2, "elegante", "it"), { nome: "Polo eleganti", aggiungi: "Aggiungi le tue" });
  assert.deepEqual(nomePosto({ sub: "Crop Top", categoria: "Upper Body" }, 1, null, "it"), { nome: "Top", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Crop Top", categoria: "Upper Body" }, 3, null, "it"), { nome: "Top", aggiungi: "Aggiungi i tuoi" });
});

test("soloPlurale: solo i veri nomi plurali, e la tabella e' coerente", () => {
  for (const [chiave, v] of [...Object.entries(NOMI_SOTTOCATEGORIA), ...Object.entries(NOMI_CATEGORIA)]) {
    if (v.soloPlurale) assert.equal(v.it[0], v.it[1], `${chiave}: solo plurale ma voci diverse`);
  }
  for (const sub of ["Polo", "Fleece", "Blazer", "Vest", "Crop Top"]) assert.equal(NOMI_SOTTOCATEGORIA[sub].soloPlurale, false, sub);
  for (const sub of ["Trousers", "Gloves", "Jeans", "Shorts", "Sneakers"]) assert.equal(NOMI_SOTTOCATEGORIA[sub].soloPlurale, true, sub);
  for (const cat of ["Shoes", "Lower Body"]) assert.equal(NOMI_CATEGORIA[cat].soloPlurale, true, cat);
});

// ── postiApp: copie, pezzi in meno, essenziali di base, informazioni ─────────
import { postiApp, type PostoApp } from "../posti.ts";
import { caricaArmadio } from "../capo.ts";
import { essenzialiPerViaggio, giorniDiMare, quantityFor } from "../quantita.ts";
import * as K from "../costanti.ts";

const SEUL_METEO = { temp_min_media: -7, temp_max_media: 1, giorni_di_pioggia: 4 };
const SEUL_VIAGGIO = { giorni: 31, lavatrice: false, attivita: [] as string[] };
const motivoGiorno = { codice: "giorno", etichetta: "Tutti i giorni", frase: "x" };
const motivoEss = { codice: "essenziale", etichetta: "Essenziali", frase: "e" };

/** Un mancante come lo da' il generatore con l'armadio vuoto (canonicalizeGaps). */
const assente = (slot: string, category: string, subCategories: string[], extra: Record<string, unknown> = {}) =>
  ({ slot, tipo: "assente", imposto: false, category, essential: true, subCategories, reason: "r",
    fonte: "slot", priorita: "necessario", ...extra });

const SEUL_MANCANTI = [
  assente("Giacca pesante", "Outerwear", ["Coat", "Down Jacket", "Rain Jacket", "Windbreaker"]),
  assente("Scarpe chiuse", "Shoes", ["Boots", "Hiking Boots", "Sneakers", "Snow Boots"]),
  assente("Cappello (Cap/Hat)", "Accessory", ["Cap/Hat"]),
  assente("Guanti (Gloves)", "Accessory", ["Gloves"]),
  assente("Maglione", "Upper Body", ["Sweater"]),
  assente("Magliette", "Upper Body", ["T-Shirt"]),
  assente("Pantaloni", "Lower Body", ["Trousers"]),
];
const richiestiDi = (mancanti: Record<string, any>[], freq: Record<string, string> = {}) =>
  mancanti.map((g) => ({ slot: g.slot, category: g.category, subCategories: g.subCategories, frequency: freq[g.slot] ?? "daily" }));

const seul = (lingua: "it" | "en" = "it", extra: Record<string, any> = {}) => postiApp(
  { mancanti_canonici: SEUL_MANCANTI, richiesti: richiestiDi(SEUL_MANCANTI), essenziali: [], ...extra },
  { capi: [], essenziali: [] }, new Map(),
  { meteo: SEUL_METEO, viaggio: SEUL_VIAGGIO, armadio: [], lingua });

const perNome = (posti: PostoApp[]) => new Map(posti.map((p) => [p.nome, p]));

test("postiApp Seul, armadio vuoto: quattro importanti, il resto proposte utili", () => {
  const { posti } = seul();
  const importanti = posti.filter((p) => p.livello === "importante").map((p) => p.nome);
  assert.deepEqual(new Set(importanti), new Set(["Giacca invernale", "Scarpe invernali", "Cappello caldo", "Guanti"]));
  assert.equal(importanti.length, 4);
  const utili = posti.filter((p) => p.livello === "utile");
  const nomiUtili = utili.map((p) => p.nome);
  for (const n of ["Maglioni caldi", "Magliette", "Mutande", "Calzini", "Pigiama", "Necessaire"]) {
    assert.ok(nomiUtili.includes(n), `${n} in ${nomiUtili.join(", ")}`);
  }
  // I pantaloni col freddo di Seul si qualificano come gli altri capi caldi (nomePosto, Task 1).
  assert.ok(nomiUtili.some((n) => n.startsWith("Pantaloni")), nomiUtili.join(", "));
  for (const p of posti) assert.ok(p.copie >= 1, `${p.nome} ${p.copie}`);
  // prima gli importanti, poi gli utili
  const primoUtile = posti.findIndex((p) => p.livello === "utile");
  assert.ok(posti.slice(primoUtile).every((p) => p.livello === "utile"));
  assert.equal(new Set(posti.map((p) => p.id)).size, posti.length);
});

test("postiApp Seul: copie, tipi e categorie", () => {
  const p = perNome(seul().posti);
  // 31 giorni senza lavatrice: le quantita' di GIORNI_LAVANDERIA giorni
  assert.equal(K.GIORNI_LAVANDERIA, 14);
  assert.deepEqual([p.get("Giacca invernale")!.copie, p.get("Giacca invernale")!.tipo], [1, "Outerwear"]);
  assert.deepEqual([p.get("Guanti")!.copie, p.get("Guanti")!.tipo], [1, "Gloves"]);
  // come slots.ts: quantityFor(sub, nome, giorni, lavatrice, freq, intensita, tempMax, giorniDiMare, calore)
  const generatore = (sub: string) => quantityFor(sub, "", 14, false, "daily", null, 1, giorniDiMare(14, []), null);
  assert.deepEqual([p.get("Maglioni caldi")!.copie, p.get("Maglioni caldi")!.tipo], [generatore("Sweater"), "Sweater"]);
  // sotto i 18 gradi una maglietta regge due giorni: 7, non 14
  assert.deepEqual([p.get("Magliette")!.copie, p.get("Magliette")!.tipo], [generatore("T-Shirt"), "T-Shirt"]);
  assert.equal(p.get("Magliette")!.copie, 7);
  assert.equal(p.get("Pantaloni caldi")!.copie, generatore("Trousers"));
  assert.deepEqual([p.get("Mutande")!.tipo, p.get("Mutande")!.categoria], ["intimo", "vestiti"]);
  assert.deepEqual([p.get("Calzini")!.tipo, p.get("Pigiama")!.tipo], ["calzini", "notte"]);
  assert.deepEqual([p.get("Necessaire")!.tipo, p.get("Necessaire")!.categoria, p.get("Necessaire")!.copie], ["igiene", "toiletries", 1]);
  assert.equal(p.get("Mutande")!.aggiungi, "Aggiungi le tue");
  assert.equal(p.get("Calzini")!.aggiungi, "Aggiungi i tuoi");
  assert.equal(p.get("Pigiama")!.aggiungi, "Aggiungi il tuo");
  assert.equal(p.get("Necessaire")!.aggiungi, "Aggiungi il tuo");
  // il motivo e' il perche' degli avvisi di oggi
  assert.equal(p.get("Giacca invernale")!.motivo, "Nell'armadio di questa casa non c'è niente di adatto al freddo previsto.");
  assert.equal(p.get("Mutande")!.motivo, null);
});

test("postiApp: l'essenziale dell'armadio vuoto ha le copie che essenzialiPerViaggio darebbe a quel capo", () => {
  const p = perNome(seul().posti);
  const finto = (name: string) => essenzialiPerViaggio(caricaArmadio([{ id: "x", name }]), 14, false)[0].quantita;
  assert.equal(p.get("Mutande")!.copie, finto("Mutande"));
  assert.equal(p.get("Calzini")!.copie, finto("Calzini"));
  assert.equal(p.get("Pigiama")!.copie, finto("Pigiama"));
  assert.equal(p.get("Necessaire")!.copie, finto("Necessaire"));
});

test("postiApp: un capo 'Mutande' nell'armadio (senza copie) toglie il posto dell'intimo", () => {
  const armadio = caricaArmadio([{ id: "m1", name: "Mutande" }]);
  const essenziali = essenzialiPerViaggio(armadio, 14, false);
  const r = postiApp({ mancanti_canonici: [], richiesti: [], essenziali }, { capi: [], essenziali: [] }, new Map(),
    { meteo: SEUL_METEO, viaggio: SEUL_VIAGGIO, armadio });
  assert.ok(!r.posti.some((p) => p.tipo === "intimo"), r.posti.map((p) => p.tipo).join(", "));
  assert.ok(r.posti.some((p) => p.tipo === "calzini"));
});

test("postiApp: quantita_insufficiente, copie dai capi diversi che mancano", () => {
  const g = { slot: "Magliette", tipo: "quantita_insufficiente", imposto: false, category: "Upper Body", essential: true,
    subCategories: ["T-Shirt"], usi_richiesti: 10, usi_coperti: 4, capi_diversi_necessari: 2, priorita: "necessario" };
  const r = postiApp({ mancanti_canonici: [g], richiesti: [], essenziali: [{ radice: "mutand" }, { radice: "calz" },
    { radice: "pigiama" }, { radice: "necessaire" }] }, { capi: [], essenziali: [] }, new Map(),
    { meteo: SEUL_METEO, viaggio: SEUL_VIAGGIO, armadio: [] });
  assert.deepEqual(r.posti.map((p) => [p.tipo, p.copie, p.livello]), [["T-Shirt", 1, "utile"]]);
});

test("postiApp: T-Shirt con 5 da portare e 2 nell'armadio, un posto Magliette x3", () => {
  const armadio = caricaArmadio([{ id: "t1", name: "Maglietta bianca",
    ai_metadata: { category: "Upper Body", subCategory: "T-Shirt" } }]);
  const motivi = { capi: [{ item_id: "t1", item: "Maglietta bianca", quantita: 5, motivo: motivoGiorno }], essenziali: [] };
  const tutte = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
  const r = postiApp({ mancanti_canonici: [], richiesti: [], essenziali: tutte }, motivi, new Map([["t1", 2]]),
    { meteo: SEUL_METEO, viaggio: SEUL_VIAGGIO, armadio });
  assert.deepEqual(r.posti.map((p) => [p.nome, p.copie, p.tipo, p.livello, p.categoria]),
    [["Magliette", 3, "T-Shirt", "utile", "vestiti"]]);
  assert.equal(r.posti[0].motivo, "Ne servirebbero 5, nell'armadio ne hai 2.");
  assert.ok(r.posti[0].id.startsWith("need:v1:"));
});

test("postiApp: mutande con 8 da portare e 3 nell'armadio, un solo posto intimo x5", () => {
  const armadio = caricaArmadio([{ id: "m1", name: "Mutande nere", quantity: 3 }]);
  const ess = { item_id: "m1", item: "Mutande nere", radice: "mutand", quantita: 8, bulk: 1 };
  const motivi = { capi: [], essenziali: [{ ...ess, motivo: motivoEss }] };
  const r = postiApp({ mancanti_canonici: [], richiesti: [], essenziali: [ess, { radice: "calz" }, { radice: "pigiama" },
    { radice: "necessaire" }] }, motivi, new Map([["m1", 3]]), { meteo: SEUL_METEO, viaggio: SEUL_VIAGGIO, armadio });
  const intimo = r.posti.filter((p) => p.tipo === "intimo");
  assert.deepEqual(intimo.map((p) => [p.nome, p.copie, p.livello]), [["Mutande", 5, "utile"]]);
  assert.equal(r.posti.length, 1);
});

test("postiApp: un pezzo solo in meno non e' mai importante", () => {
  const armadio = caricaArmadio([{ id: "b1", name: "Scarponi", ai_metadata: { category: "Shoes", subCategory: "Hiking Boots" } }]);
  const tutte = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
  const conQuantita = (q: number) => postiApp({ mancanti_canonici: [], richiesti: [], essenziali: tutte },
    { capi: [{ item_id: "b1", item: "Scarponi", quantita: q, motivo: motivoGiorno }], essenziali: [] }, new Map([["b1", 1]]),
    { meteo: SEUL_METEO, viaggio: SEUL_VIAGGIO, armadio }).posti;
  assert.deepEqual(conQuantita(2).map((p) => [p.tipo, p.copie, p.livello]), [["Hiking Boots", 1, "utile"]]);
  assert.deepEqual(conQuantita(3).map((p) => [p.tipo, p.copie, p.livello]), [["Hiking Boots", 2, "importante"]]);
});

test("postiApp: due mancanti T-Shirt da slot diversi, un posto con il massimo delle copie", () => {
  const a = assente("Magliette", "Upper Body", ["T-Shirt"]);
  const b = assente("Magliette per la sera", "Upper Body", ["T-Shirt"]);
  const tutte = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
  const r = postiApp({ mancanti_canonici: [a, b], richiesti: richiestiDi([a, b], { "Magliette per la sera": "occasional" }),
    essenziali: tutte }, { capi: [], essenziali: [] }, new Map(),
  { meteo: { temp_min_media: 15, temp_max_media: 24 }, viaggio: { giorni: 5, lavatrice: false }, armadio: [] });
  // giornaliera 5 e occasionale round(5 * 0.4) = 2 coprono gli stessi giorni: vale il massimo
  assert.deepEqual(r.posti.map((p) => [p.tipo, p.nome, p.copie]), [["T-Shirt", "Magliette", 5]]);
});

test("postiApp: gonna, vestito e cravatta senza averne nell'armadio non diventano posti", () => {
  const tutte = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
  const mancanti = [assente("Gonna", "Lower Body", ["Skirt"]), assente("Vestito", "Full Body", ["Dress"]),
    assente("Cravatta", "Accessory", ["Tie"])];
  const r = postiApp({ mancanti_canonici: mancanti, richiesti: richiestiDi(mancanti), essenziali: tutte },
    { capi: [], essenziali: [] }, new Map(), { meteo: SEUL_METEO, viaggio: SEUL_VIAGGIO, armadio: [] });
  assert.deepEqual(r.posti, []);
});

test("postiApp: lavanderia e bagaglio troppo pieno sono informazioni, mai posti", () => {
  const volume = { slot: "volume del bagaglio", tipo: "volume_eccedente", category: "", essential: false, imposto: true,
    priorita: "necessario", capienza: 30, volume: 41, da_valutare: ["Felpa grigia"] };
  const r = seul("it", { mancanti_canonici: [...SEUL_MANCANTI, volume] });
  assert.deepEqual(r.informazioni, [
    { codice: "volume_eccedente", titolo: "Il bagaglio è troppo pieno",
      perche: "Considera un bagaglio più grande oppure lascia a casa qualcosa tra Felpa grigia." },
    { codice: "lavanderia", titolo: "Prevedi una lavanderia",
      perche: "Il viaggio è lungo: la valigia conta di lavare i vestiti strada facendo." },
  ]);
  assert.ok(!r.posti.some((p) => p.tipo === "volume_eccedente" || p.tipo === "" || p.tipo === "lavanderia"));
  assert.equal(r.posti.length, seul().posti.length);
  // con la lavatrice niente lavanderia
  const conLavatrice = postiApp({ mancanti_canonici: [], richiesti: [], essenziali: [] }, { capi: [], essenziali: [] },
    new Map(), { meteo: SEUL_METEO, viaggio: { giorni: 31, lavatrice: true }, armadio: [] });
  assert.deepEqual(conLavatrice.informazioni, []);
});

test("postiApp: a tappe i giorni sono la somma delle tappe e la lavanderia non c'e'", () => {
  const viaggio = { giorni: 10, lavatrice: false, tappe: [{ nome: "Seul", giorni: 6 }, { nome: "Busan", giorni: 4 }] };
  const m = [assente("Magliette", "Upper Body", ["T-Shirt"])];
  const r = postiApp({ mancanti_canonici: m, richiesti: richiestiDi(m), essenziali: [] }, { capi: [], essenziali: [] },
    new Map(), { meteo: SEUL_METEO, viaggio, armadio: [] });
  const p = perNome(r.posti);
  assert.equal(p.get("Magliette")!.copie, 10);
  assert.equal(p.get("Mutande")!.copie, essenzialiPerViaggio(caricaArmadio([{ id: "x", name: "Mutande" }]), 10, false)[0].quantita);
  assert.deepEqual(r.informazioni, []);
});

test("postiApp in inglese: nomi e 'aggiungi' in inglese", () => {
  const { posti, informazioni } = seul("en");
  const nomi = posti.map((p) => p.nome);
  for (const n of ["Winter jacket", "Winter shoes", "Warm hat", "Gloves", "Warm sweaters", "T-shirts", "Underwear",
    "Socks", "Pyjamas", "Toiletry bag"]) {
    assert.ok(nomi.includes(n), `${n} in ${nomi.join(", ")}`);
  }
  for (const p of posti) assert.equal(p.aggiungi, "Add yours");
  assert.equal(perNome(posti).get("Winter jacket")!.motivo, "Nothing in this home's wardrobe is suited to the expected cold.");
  assert.deepEqual(informazioni.map((i) => i.titolo), ["Plan to do laundry"]);
});

// ── Copie come il generatore (revisione del Task 2) ─────────────────────────
const TUTTE = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
const copieDi = (mancante: Record<string, any>, richiesto: Record<string, any>, meteo: Record<string, any>,
  viaggio: Record<string, any>) => {
  const r = postiApp({ mancanti_canonici: [mancante], richiesti: [{ slot: mancante.slot, ...richiesto }], essenziali: TUTTE },
    { capi: [], essenziali: [] }, new Map(), { meteo, viaggio, armadio: [] });
  assert.equal(r.posti.length, 1);
  return r.posti[0].copie;
};

test("postiApp: costume senza mare, una volta o ogni tanto, uno solo", () => {
  const costume = assente("Costume", "Lower Body", ["Swimwear"]);
  const viaggio = { giorni: 7, lavatrice: false, attivita: ["visite in citta"] };
  const meteo = { temp_min_media: 18, temp_max_media: 27 };
  for (const frequency of ["once", "occasional"]) {
    const copie = copieDi(costume, { frequency }, meteo, viaggio);
    assert.equal(copie, quantityFor("Swimwear", "", 7, false, frequency, null, 27, giorniDiMare(7, viaggio.attivita), null));
    assert.equal(copie, 1, frequency);
  }
});

test("postiApp: camicie con 32 gradi, una al giorno col calore minimo dello slot", () => {
  const camicie = assente("Camicie", "Upper Body", ["Shirt"]);
  const viaggio = { giorni: 10, lavatrice: false, attivita: [] };
  const copie = copieDi(camicie, { frequency: "daily", minWarmth: 1 }, { temp_min_media: 24, temp_max_media: 32 }, viaggio);
  assert.equal(copie, quantityFor("Shirt", "", 10, false, "daily", null, 32, giorniDiMare(10, []), 1));
  assert.equal(copie, 10);
  // senza il calore dello slot vale quello chiesto dal mancante
  const inadatte = { ...camicie, tipo: "posseduto_ma_inadatto", candidato_scartato: "Camicia di flanella", warmth_richiesto: [1, 2] };
  assert.equal(copieDi(inadatte, { frequency: "daily" }, { temp_min_media: 24, temp_max_media: 32 }, viaggio), 10);
});

test("postiApp: cammino a piedi con lo zaino piccolo, si lava a mano come nel generatore", () => {
  const magliette = assente("Magliette", "Upper Body", ["T-Shirt"]);
  const viaggio = { giorni: 12, lavatrice: false, attivita: ["cammino di Santiago"], bagaglio: "zaino da 35 litri" };
  const meteo = { temp_min_media: 12, temp_max_media: 22 };
  const copie = copieDi(magliette, { frequency: "daily" }, meteo, viaggio);
  assert.equal(copie, quantityFor("T-Shirt", "", 12, true, "daily", null, 22, giorniDiMare(12, viaggio.attivita), null));
  assert.ok(copie < quantityFor("T-Shirt", "", 12, false, "daily", null, 22, giorniDiMare(12, viaggio.attivita), null));
  // gli essenziali invece no: la lavatrice del viaggio
  const r = postiApp({ mancanti_canonici: [], richiesti: [], essenziali: [] }, { capi: [], essenziali: [] }, new Map(),
    { meteo, viaggio, armadio: [] });
  assert.equal(r.posti.find((p) => p.tipo === "intimo")!.copie,
    essenzialiPerViaggio(caricaArmadio([{ id: "x", name: "Mutande" }]), 12, false, 22)[0].quantita);
});

test("postiApp a tappe: la massima della tappa base per i capi", () => {
  // La tappa base e' la piu' calda (ordinaTappe): Bangkok a 33, non Seul a 1.
  const viaggio = { giorni: 10, lavatrice: false, tappe: [{ nome: "Seul", giorni: 5 }, { nome: "Bangkok", giorni: 5 }] };
  const meteo = { temp_min_media: -7, temp_max_media: 33, _per_tappa: [
    { destinazione: "Seul", giorni: 5, temp_min_media: -7, temp_max_media: 1 },
    { destinazione: "Bangkok", giorni: 5, temp_min_media: 25, temp_max_media: 33 }] };
  const camicie = assente("Camicie", "Upper Body", ["Shirt"]);
  const copie = copieDi(camicie, { frequency: "daily", minWarmth: 1 }, meteo, viaggio);
  assert.equal(copie, quantityFor("Shirt", "", 10, false, "daily", null, 33, giorniDiMare(10, []), 1));
  assert.equal(copie, 10);
});

// ── Un posto solo per le giacche e per le scarpe del meteo (Task 3b) ───────────────────────
const TUTTI_ESSENZIALI = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
const postiDi = (mancanti: Record<string, any>[], opzioni: { meteo?: Record<string, any>; lingua?: "it" | "en";
  viaggio?: Record<string, any>; capi?: Record<string, any>[]; armadio?: ReturnType<typeof caricaArmadio>; salvate?: Map<string, number | null> } = {}) =>
  postiApp({ mancanti_canonici: mancanti, richiesti: richiestiDi(mancanti), essenziali: TUTTI_ESSENZIALI },
    { capi: opzioni.capi ?? [], essenziali: [] }, opzioni.salvate ?? new Map(),
    { meteo: opzioni.meteo ?? SEUL_METEO, viaggio: opzioni.viaggio ?? SEUL_VIAGGIO, armadio: opzioni.armadio ?? [], lingua: opzioni.lingua }).posti;
const MITE = { temp_min_media: 14, temp_max_media: 22, giorni_di_pioggia: 3 };
const freddoGap = (slot: string, category: string, sub: string) =>
  assente(slot, category, [sub], { warmth_richiesto: [4, 5] });
const pioggiaGap = (slot: string, category: string, sub: string) =>
  assente(slot, category, [sub], { warmth_richiesto: [1, 2], impermeabilita_richiesta: 2 });

test("un posto solo: Seul armadio vuoto resta Giacca invernale, Scarpe invernali, Cappello caldo, Guanti", () => {
  const importanti = seul().posti.filter((p) => p.livello === "importante").map((p) => p.nome);
  assert.deepEqual(new Set(importanti), new Set(["Giacca invernale", "Scarpe invernali", "Cappello caldo", "Guanti"]));
  assert.equal(importanti.length, 4);
});

test("un posto solo: due gap Shoes freddi (Sneakers e Boots) diventano Scarpe invernali", () => {
  const posti = postiDi([freddoGap("Sneakers", "Shoes", "Sneakers"), freddoGap("Stivali", "Shoes", "Boots")]);
  const scarpe = posti.filter((p) => p.categoria === "vestiti" && ["Shoes", "Sneakers", "Boots"].includes(p.tipo));
  assert.deepEqual(scarpe.map((p) => [p.nome, p.tipo, p.copie, p.livello]), [["Scarpe invernali", "Shoes", 1, "importante"]]);
});

test("posti meteo: il guscio leggero non viene assorbito nel bisogno di un cappotto caldo", () => {
  const posti = postiDi([freddoGap("Piumino", "Outerwear", "Down Jacket"), freddoGap("Cappotto", "Outerwear", "Coat"),
    pioggiaGap("Pioggia", "Outerwear", "Rain Jacket")]);
  const giacche = posti.filter((p) => ["Outerwear", "Down Jacket", "Coat", "Rain Jacket"].includes(p.tipo));
  assert.deepEqual(giacche.map((p) => [p.nome, p.tipo, p.copie, p.livello]), [
    ["Giacca invernale", "Outerwear", 1, "importante"], ["Giacca impermeabile", "Outerwear", 1, "importante"]]);
  assert.equal(giacche[0].motivo, posti.find((p) => p.tipo === "Outerwear")!.motivo);
  assert.ok(giacche[0].motivo, "il motivo e' quello del primo posto unito");
});

test("un posto solo: solo pioggia (nessun freddo), Rain Jacket e Windbreaker diventano Giacca impermeabile", () => {
  const posti = postiDi([pioggiaGap("Pioggia", "Outerwear", "Rain Jacket"), pioggiaGap("Vento", "Outerwear", "Windbreaker")],
    { meteo: MITE });
  const giacche = posti.filter((p) => p.tipo === "Outerwear");
  assert.deepEqual(giacche.map((p) => [p.nome, p.copie, p.livello]), [["Giacca impermeabile", 1, "importante"]]);
  assert.ok(!posti.some((p) => p.tipo === "Rain Jacket" || p.tipo === "Windbreaker"));
});

test("scarpe solo pioggia: il raggruppamento conserva il nome concreto", () => {
  const posti = postiDi([pioggiaGap("Sneakers", "Shoes", "Sneakers"), pioggiaGap("Stivali", "Shoes", "Boots")], { meteo: MITE });
  assert.deepEqual(posti.filter((p) => p.tipo === "Shoes").map((p) => [p.nome, p.copie]), [["Sneakers", 1]]);
});

test("inglese: il freddo resta qualificato e le scarpe da pioggia hanno un nome concreto", () => {
  const inverno = postiDi([freddoGap("a", "Outerwear", "Coat"), freddoGap("b", "Shoes", "Boots")], { lingua: "en" });
  assert.deepEqual(inverno.filter((p) => p.livello === "importante").map((p) => p.nome).sort(), ["Winter jacket", "Winter shoes"]);
  const acqua = postiDi([pioggiaGap("a", "Outerwear", "Rain Jacket"), pioggiaGap("b", "Shoes", "Sneakers")],
    { meteo: MITE, lingua: "en" });
  assert.deepEqual(acqua.filter((p) => p.livello === "importante").map((p) => p.nome).sort(), ["Sneakers", "Waterproof jacket"]);
});

test("posti meteo: freddo e pioggia con fasce incompatibili restano distinti anche invertiti", () => {
  const posti = postiDi([pioggiaGap("Pioggia", "Outerwear", "Rain Jacket"), freddoGap("Cappotto", "Outerwear", "Coat")]);
  assert.deepEqual(posti.filter((p) => p.tipo === "Outerwear").map((p) => p.nome), ["Giacca impermeabile", "Giacca invernale"]);
});

test("un posto solo: gli scarponi da trekking (attivita') restano accanto alle Scarpe invernali", () => {
  // clima mite: gli scarponi non prendono "invernali" dal viaggio; le Boots lo chiedono col loro calore
  const posti = postiDi([assente("Scarponi", "Shoes", ["Hiking Boots"]), freddoGap("Stivali", "Shoes", "Boots")], { meteo: MITE, viaggio: { giorni: 4, attivita: ["trekking"] } });
  const importanti = posti.filter((p) => p.livello === "importante" && ["Shoes", "Hiking Boots"].includes(p.tipo));
  assert.deepEqual(importanti.map((p) => p.nome).sort(), ["Scarpe invernali", "Scarponi da trekking"]);
});

test("un posto solo: le Scarpe eleganti (Dress Shoes) restano accanto alle Scarpe invernali", () => {
  const eleganti = assente("Sera", "Shoes", ["Dress Shoes"], { formality: ["Formal"] });
  const posti = postiDi([eleganti, freddoGap("Stivali", "Shoes", "Boots")]);
  const importanti = posti.filter((p) => p.livello === "importante" && ["Shoes", "Dress Shoes"].includes(p.tipo));
  assert.deepEqual(importanti.map((p) => p.nome).sort(), ["Scarpe eleganti", "Scarpe invernali"]);
});

test("un posto solo: il Blazer elegante non entra nella Giacca invernale", () => {
  const blazer = assente("Sera", "Outerwear", ["Blazer"], { formality: ["Business"] });
  const posti = postiDi([blazer, freddoGap("Cappotto", "Outerwear", "Coat")]);
  assert.deepEqual(posti.filter((p) => ["Outerwear", "Blazer"].includes(p.tipo)).map((p) => p.nome).sort(),
    ["Blazer", "Giacca invernale"]);
});

test("un posto solo: le Sneakers utili spariscono se c'e' il posto del meteo per le scarpe", () => {
  const utile = assente("Sneakers", "Shoes", ["Sneakers"], { warmth_richiesto: [1, 5] });
  const posti = postiDi([utile, freddoGap("Stivali", "Shoes", "Boots")]);
  assert.deepEqual(posti.filter((p) => ["Shoes", "Sneakers", "Boots"].includes(p.tipo)).map((p) => p.nome), ["Scarpe invernali"]);
  assert.ok(!posti.some((p) => p.nome === "Sneakers"));
});

test("un posto solo: le Sneakers utili restano senza alcun posto del meteo per le scarpe", () => {
  const utile = assente("Sneakers", "Shoes", ["Sneakers"], { warmth_richiesto: [1, 3] });
  const posti = postiDi([utile, freddoGap("Cappotto", "Outerwear", "Coat")]);
  assert.deepEqual(posti.find((p) => p.tipo === "Sneakers")!.livello, "utile");
  assert.equal(posti.find((p) => p.tipo === "Sneakers")!.nome, "Sneakers");
});

test("un posto solo: un utile d'attivita' o elegante della stessa categoria resta", () => {
  const acqua = assente("Acqua", "Shoes", ["Water Shoes"], { warmth_richiesto: [1, 2] });
  const posti = postiDi([acqua, freddoGap("Stivali", "Shoes", "Boots")], { meteo: MITE });
  // Water Shoes e' sempre importante (attivita'): resta, e le Boots fredde sono un posto a parte.
  assert.deepEqual(posti.filter((p) => ["Shoes", "Water Shoes"].includes(p.tipo)).map((p) => p.nome).sort(),
    ["Scarpe invernali", "Scarpette da scoglio"]);
});

test("un posto solo: i pezzi in meno di un capo Shoes dell'utente non si toccano", () => {
  const armadio = caricaArmadio([{ id: "s1", name: "Sneakers bianche", ai_metadata: { category: "Shoes", subCategory: "Sneakers" } }]);
  const motivi = { capi: [{ item_id: "s1", item: "Sneakers bianche", quantita: 3, motivo: motivoGiorno }] };
  const posti = postiDi([freddoGap("Stivali", "Shoes", "Boots")], { armadio, capi: motivi.capi, salvate: new Map([["s1", 1]]) });
  const scarpe = posti.filter((p) => ["Shoes", "Sneakers"].includes(p.tipo));
  assert.deepEqual(scarpe.map((p) => [p.nome, p.tipo, p.copie]).sort(), [["Scarpe invernali", "Shoes", 1], ["Sneakers", "Sneakers", 2]]);
});

test("accessori del meteo: cappello e guanti importanti, ombrello utile", () => {
  const posti = postiDi([assente("Cappello", "Accessory", ["Cap/Hat"], { warmth_richiesto: [4, 5] }),
    assente("Guanti", "Accessory", ["Gloves"], { warmth_richiesto: [4, 5] }),
    pioggiaGap("Ombrello", "Accessory", "Umbrella")]);
  assert.deepEqual(new Set(posti.filter((p) => p.livello === "importante").map((p) => p.nome)),
    new Set(["Cappello caldo", "Guanti"]));
  assert.equal(posti.find((p) => p.tipo === "Umbrella")!.livello, "utile");
});

test("un posto solo: identita' univoca e ordine del primo bisogno unito", () => {
  const posti = postiDi([freddoGap("a", "Outerwear", "Coat"), freddoGap("b", "Shoes", "Boots"), freddoGap("c", "Outerwear", "Down Jacket")]);
  assert.equal(new Set(posti.map((p) => p.id)).size, posti.length);
  assert.deepEqual(posti.filter((p) => p.livello === "importante").map((p) => p.tipo), ["Outerwear", "Shoes"]);
});

test("un posto solo: pezzi in meno su un capo Shoes 'Other' non si sommano alle Scarpe invernali", () => {
  // "Other" e' una sottocategoria valida ma non ha nome in tabella: il tipo del posto e' la categoria, "Shoes".
  const armadio = caricaArmadio([{ id: "o1", name: "Scarpe strane", ai_metadata: { category: "Shoes", subCategory: "Other" } }]);
  const capi = [{ item_id: "o1", item: "Scarpe strane", quantita: 3, motivo: motivoGiorno }];
  const posti = postiDi([freddoGap("Stivali", "Shoes", "Boots")], { armadio, capi, salvate: new Map([["o1", 1]]) });
  const scarpe = posti.filter((p) => p.tipo === "Shoes");
  assert.equal(scarpe.length, 2, posti.map((p) => p.nome).join(", "));
  const meteo = scarpe.find((p) => p.livello === "importante" && p.copie === 1)!;
  assert.equal(meteo.nome, "Scarpe invernali");
  const pezzi = scarpe.find((p) => p !== meteo)!;
  assert.equal(pezzi.copie, 2);
  assert.equal(pezzi.motivo, "Ne servirebbero 3, nell'armadio ne hai 1.");
  assert.notEqual(meteo.id, pezzi.id);
  assert.equal(new Set(posti.map((p) => p.id)).size, posti.length);
});

test("un posto solo: pezzi in meno su un capo Outerwear 'Other' non si sommano alla Giacca invernale", () => {
  const armadio = caricaArmadio([{ id: "o2", name: "Giacca strana", ai_metadata: { category: "Outerwear", subCategory: "Other" } }]);
  const capi = [{ item_id: "o2", item: "Giacca strana", quantita: 2, motivo: motivoGiorno }];
  const posti = postiDi([freddoGap("Cappotto", "Outerwear", "Coat")], { armadio, capi, salvate: new Map([["o2", 1]]) });
  const giacche = posti.filter((p) => p.tipo === "Outerwear");
  assert.deepEqual(giacche.map((p) => [p.nome, p.copie]).sort(), [["Giacca invernale", 1], ["Giacca", 1]].sort());
  assert.ok(giacche.some((p) => p.motivo === "Ne servirebbero 2, nell'armadio ne hai 1."));
});


// ── Copie unite col massimo, muta mai importante, pantaloni lunghi da sera al caldo ────────
const TEPIDO = { temp_min_media: 14, temp_max_media: 22, giorni_di_pioggia: 0 };
const CALDO = { temp_min_media: 22, temp_max_media: 32, giorni_di_pioggia: 0 };
const NOVE_GIORNI = { giorni: 9, lavatrice: false, attivita: [] as string[] };
const postiNove = (mancanti: Record<string, any>[], freq: Record<string, string>, meteo: Record<string, any>) =>
  postiApp({ mancanti_canonici: mancanti, richiesti: richiestiDi(mancanti, freq), essenziali: TUTTI_ESSENZIALI },
    { capi: [], essenziali: [] }, new Map(), { meteo, viaggio: NOVE_GIORNI, armadio: [] }).posti;
const copiePer = (posti: PostoApp[]) => Object.fromEntries(posti.map((p) => [p.tipo, p.copie]));

test("copie unite: T-Shirt giornaliera e occasionale di 9 giorni, 9 e non 13", () => {
  const a = assente("Magliette", "Upper Body", ["T-Shirt"]);
  const b = assente("Magliette per la sera", "Upper Body", ["T-Shirt"]);
  const posti = postiNove([a, b], { "Magliette per la sera": "occasional" }, TEPIDO);
  assert.equal(posti.find((p) => p.tipo === "T-Shirt")?.copie, 9);
});

test("copie unite: anche in Lower Body i gap dello stesso tipo si uniscono col massimo", () => {
  const a = assente("Pantaloni", "Lower Body", ["Trousers"]);
  const b = assente("Pantaloni per la sera", "Lower Body", ["Trousers"]);
  const unico = postiNove([a], {}, TEPIDO).find((p) => p.tipo === "Trousers")!.copie;
  const due = postiNove([a, b], { "Pantaloni per la sera": "occasional" }, TEPIDO).find((p) => p.tipo === "Trousers")!.copie;
  assert.equal(due, unico);
});

test("copie unite: i pezzi in meno restano sommati al posto dei gap", () => {
  const armadio = caricaArmadio([{ id: "t1", name: "Maglietta bianca",
    ai_metadata: { category: "Upper Body", subCategory: "T-Shirt" } }]);
  const motivi = { capi: [{ item_id: "t1", item: "Maglietta bianca", quantita: 5, motivo: motivoGiorno }], essenziali: [] };
  const a = assente("Magliette", "Upper Body", ["T-Shirt"]);
  const b = assente("Magliette per la sera", "Upper Body", ["T-Shirt"]);
  const r = postiApp({ mancanti_canonici: [a, b], richiesti: richiestiDi([a, b], { "Magliette per la sera": "occasional" }),
    essenziali: TUTTI_ESSENZIALI }, motivi, new Map([["t1", 2]]),
  { meteo: { temp_min_media: 15, temp_max_media: 24 }, viaggio: { giorni: 5, lavatrice: false }, armadio });
  // gap: max(5, 2) = 5; pezzi: 5 - 2 = 3, sommati
  assert.equal(r.posti.find((p) => p.tipo === "T-Shirt")?.copie, 8);
});

test("muta: il Wetsuit al massimo utile, il costume resta importante", () => {
  const muta = { tipo: "assente", category: "Lower Body", subCategories: ["Wetsuit"], priorita: "necessario" };
  const costume = { tipo: "assente", category: "Lower Body", subCategories: ["Swimwear"], priorita: "necessario" };
  assert.equal(livello(muta), "utile");
  assert.equal(livelloPosto(muta, { sub: "Wetsuit", categoria: "Lower Body" }, true), "utile");
  assert.equal(livello(costume, false, ["mare"]), "importante");
});

test("pantaloni lunghi al caldo: al massimo le copie delle camicie", () => {
  const mancanti = [assente("Camicie", "Upper Body", ["Shirt"]), assente("Pantaloni", "Lower Body", ["Trousers"]),
    assente("Jeans", "Lower Body", ["Jeans"]), assente("Pantaloncini", "Lower Body", ["Shorts"])];
  const camicieSera = { Camicie: "occasional" }; // meno camicie dei pantaloni
  const caldo = copiePer(postiNove(mancanti, camicieSera, CALDO));
  const tiepido = copiePer(postiNove(mancanti, camicieSera, TEPIDO));
  assert.deepEqual([tiepido.Shirt, tiepido.Trousers, tiepido.Jeans], [2, 5, 3], "senza caldo i pantaloni non sono limitati");
  assert.deepEqual([caldo.Shirt, caldo.Trousers, caldo.Jeans], [2, 2, 2]);
  // i pantaloncini non sono pantaloni lunghi
  assert.equal(caldo.Shorts, tiepido.Shorts);
});

test("pantaloni lunghi al caldo: senza posto Camicie, una copia sola", () => {
  const caldo = copiePer(postiNove([assente("Pantaloni", "Lower Body", ["Trousers"])], {}, CALDO));
  assert.equal(caldo.Trousers, 1);
});

test("armadio normale: senza gap doppi, muta o caldo i posti non cambiano", () => {
  const mancanti = [assente("Magliette", "Upper Body", ["T-Shirt"]), assente("Pantaloni", "Lower Body", ["Trousers"]),
    assente("Camicie", "Upper Body", ["Shirt"])];
  const copie = copiePer(postiNove(mancanti, {}, TEPIDO));
  assert.equal(copie["T-Shirt"], 9);
  assert.equal(copie.Trousers, 5);
});

// ── Viaggi a piu' tappe: il caldo vale per tutte le tappe, il massimo solo nella stessa tappa ──
const DUE_TAPPE = { giorni: 10, lavatrice: false, attivita: [] as string[], tappe: [
  { nome: "Alfa", paese: "", giorni: 5, attivita: [] }, { nome: "Beta", paese: "", giorni: 5, attivita: [] }] };
const meteoTappe = (a: number, b: number) => ({ temp_min_media: 15, temp_max_media: Math.max(a, b), giorni_di_pioggia: 0,
  _per_tappa: [{ destinazione: "Alfa", giorni: 5, temp_min_media: 15, temp_max_media: a },
    { destinazione: "Beta", giorni: 5, temp_min_media: 15, temp_max_media: b }] });
const postiTappe = (mancanti: Record<string, any>[], freq: Record<string, string>, meteo: Record<string, any>) =>
  postiApp({ mancanti_canonici: mancanti, richiesti: richiestiDi(mancanti, freq), essenziali: TUTTI_ESSENZIALI },
    { capi: [], essenziali: [] }, new Map(), { meteo, viaggio: DUE_TAPPE, armadio: [] }).posti;

test("pantaloni lunghi: con una tappa fresca nessun tetto, con tutte le tappe calde si", () => {
  const mancanti = [assente("Camicie", "Upper Body", ["Shirt"]), assente("Pantaloni", "Lower Body", ["Trousers"])];
  const freq = { Camicie: "occasional" };
  const fresca = copiePer(postiTappe(mancanti, freq, meteoTappe(32, 12)));
  const calde = copiePer(postiTappe(mancanti, freq, meteoTappe(32, 28)));
  assert.ok(fresca.Trousers > fresca.Shirt, "con una tappa fresca i pantaloni restano da giorno");
  assert.equal(calde.Trousers, calde.Shirt);
});

test("copie unite: tappe diverse si sommano, la stessa tappa si unisce col massimo", () => {
  const maglia = (slot: string, tappe?: string[]) => ({ ...assente(slot, "Upper Body", ["T-Shirt"]), ...(tappe ? { tappe } : {}) });
  const meteo = meteoTappe(20, 20);
  const copieT = (m: Record<string, any>[], freq = {}) => postiTappe(m, freq, meteo).find((p) => p.tipo === "T-Shirt")!.copie;
  const uno = copieT([maglia("A", ["Alfa"])]);
  assert.equal(copieT([maglia("A", ["Alfa"]), maglia("B", ["Alfa"])]), uno, "stessa tappa: massimo");
  assert.equal(copieT([maglia("A", ["Alfa"]), maglia("B", ["Beta"])]), uno * 2, "tappe diverse: somma");
  assert.equal(copieT([maglia("A"), maglia("B")]), copieT([maglia("A")]) * 2, "tappa ignota: ogni bisogno usa l'intera durata");
});

test("copie unite: tre mancanti Sneakers nella stessa tappa, le copie del maggiore e non la somma", () => {
  const sneakers = (slot: string) => ({ ...assente(slot, "Shoes", ["Sneakers"]), tappe: ["Alfa"] });
  const tre = [sneakers("scarpe da cammino"), sneakers("Sneakers"), sneakers("scarpe comode")];
  const meteo = meteoTappe(30, 30);
  const uno = postiTappe([tre[0]], {}, meteo).find((p) => p.tipo === "Sneakers")!.copie;
  const tutte = postiTappe(tre, {}, meteo).find((p) => p.tipo === "Sneakers")!.copie;
  assert.equal(tutte, uno);
  assert.equal(uno, 1);
});

// ── Il nome del posto lo sceglie il generatore su un armadio tipico (slots.ts, armadio_tipico.ts) ─────────

type Bisogno = Record<string, unknown>;
const bisogno = (slot: string, category: string, subCategories: string[], extra: Bisogno = {}): Bisogno =>
  ({ slot, category, subCategories, minWarmth: 1, maxWarmth: 5, formality: ["Casual"], activityTags: [], frequency: "daily",
    essential: true, reason: "prova", ...extra });

/** Il giro vero: il generatore su un armadio vuoto, poi i posti. Restano i capi da vestire (non intimo, calzini, ecc.). */
function postiDelGeneratore(bisogni: Bisogno[], meteo: { temp_min: number; temp_max: number }, attivita: string[] = [],
  giorni = 5): PostoApp[] {
  const valigia = strategySlots(JSON.stringify(bisogni), [], { giorni, lavatrice: true, attivita, temp_min: meteo.temp_min,
    temp_max: meteo.temp_max, bagaglio: "trolley medio", giorni_pioggia: 0 });
  return postiApp(valigia, { capi: [], essenziali: [] }, new Map(),
    { meteo: { temp_min_media: meteo.temp_min, temp_max_media: meteo.temp_max, giorni_di_pioggia: 0 },
      viaggio: { giorni, lavatrice: true, attivita }, armadio: [], lingua: "it" })
    .posti.filter((p) => !["intimo", "calzini", "notte", "igiene"].includes(p.tipo));
}
const tipoDi = (posti: PostoApp[]) => posti.map((p) => p.tipo);

test("posto: il capo e' quello che il generatore sceglierebbe nell'armadio tipico, non il primo dell'elenco", () => {
  // Un posto su richiesti: il generatore lo ha scritto in capoTipico, i posti lo seguono.
  const g = assente("inferiore", "Lower Body", ["Jeans", "Trousers"]);
  const conTipico = (capoTipico?: Bisogno) => postiApp({ mancanti_canonici: [g], richiesti: [{ slot: "inferiore", category: "Lower Body",
    subCategories: ["Jeans", "Trousers"], frequency: "daily", ...(capoTipico ? { capoTipico } : {}) }], essenziali: [] },
  { capi: [], essenziali: [] }, new Map(),
  { meteo: { temp_min_media: 14, temp_max_media: 22, giorni_di_pioggia: 0 }, viaggio: { giorni: 5, lavatrice: true, attivita: [] },
    armadio: [], lingua: "it" }).posti.filter((p) => !["intimo", "calzini", "notte", "igiene"].includes(p.tipo));
  assert.deepEqual(tipoDi(conTipico({ sub: "Trousers", categoria: "Lower Body" })), ["Trousers"]);
  // nessun capo tipico va: resta capoDelGap, come prima
  assert.deepEqual(tipoDi(conTipico()), [capoDelGap(g).sub]);
  // un capo che si nomina solo se l'armadio lo ha (la gonna) e l'armadio no: capoDelGap
  assert.deepEqual(tipoDi(conTipico({ sub: "Skirt", categoria: "Lower Body" })), [capoDelGap(g).sub]);
});

test("posto, Livigno (sintetico): maglia termica, pile, maglione e un capospalla da sci, non tutti maglioni", () => {
  const p = postiDelGeneratore([
    bisogno("strato base caldo", "Upper Body", ["Thermal Top"], { minWarmth: 3, formality: ["Loungewear"], activityTags: ["Sport"] }),
    bisogno("strato intermedio", "Upper Body", ["Fleece", "Hoodie"], { minWarmth: 3, activityTags: ["Hiking"] }),
    bisogno("strato per la sera", "Upper Body", ["Sweater"], { minWarmth: 3, formality: ["Smart Casual"] }),
    bisogno("giacca da sci", "Outerwear", ["Ski Jacket"], { minWarmth: 5, activityTags: ["Sport"], minWaterResistance: 2 }),
  ], { temp_min: -9, temp_max: 1 }, ["sci"], 7);
  const tipi = tipoDi(p);
  assert.ok(tipi.includes("Thermal Top"), `maglia termica: ${tipi}`);
  assert.ok(tipi.includes("Fleece"), `pile: ${tipi}`);
  assert.ok(tipi.includes("Sweater"), `maglione la sera: ${tipi}`);
  assert.ok(tipi.includes("Ski Jacket"), `giacca da sci: ${tipi}`);
  assert.equal(p.find((x) => x.tipo === "Fleece")!.nome, "Pile");
});

test("posto, Ginevra: in un viaggio di lavoro il bisogno casual non diventa jeans", () => {
  const p = postiDelGeneratore([bisogno("inferiore casual", "Lower Body", ["Jeans", "Trousers"], { minWarmth: 2 })],
    { temp_min: 3.5, temp_max: 11.5 }, ["congresso", "cene di lavoro", "riunioni di lavoro"]);
  assert.ok(!tipoDi(p).includes("Jeans"), `niente jeans: ${tipoDi(p)}`);
});

test("posto, matrimonio: il bisogno elegante prende un capo elegante, non la maglietta", () => {
  const p = postiDelGeneratore([bisogno("superiore elegante", "Upper Body", ["T-Shirt", "Shirt"],
    { minWarmth: 2, formality: ["Formal"], activityTags: ["Formal"] })], { temp_min: 15, temp_max: 25 }, ["matrimonio"]);
  assert.ok(tipoDi(p).includes("Shirt"), `camicia: ${tipoDi(p)}`);
  assert.ok(!tipoDi(p).includes("T-Shirt"), `niente maglietta: ${tipoDi(p)}`);
  assert.equal(p.find((x) => x.tipo === "Shirt")!.livello, "importante");
});

test("requisiti: blazer e stivali formali restano distinti dai posti per il freddo", () => {
  const p = postiDelGeneratore([
    bisogno("capospalla per il lavoro", "Outerwear", ["Blazer"], { minWarmth: 2, maxWarmth: 3, formality: ["Business", "Formal"] }),
    bisogno("scarpe per il lavoro", "Shoes", ["Dress Shoes"], { minWarmth: 2, maxWarmth: 3, formality: ["Business", "Formal"] }),
    bisogno("capospalla per il freddo", "Outerwear", ["Coat", "Down Jacket"], { minWarmth: 4 }),
    bisogno("scarpe per il freddo", "Shoes", ["Boots"], { minWarmth: 4 }),
  ], { temp_min: -4, temp_max: 5 }, ["riunioni di lavoro"]);
  // Sotto zero il generatore sostituisce le scarpe eleganti con stivali caldi compatibili con l'ufficio.
  for (const tipo of ["Blazer", "Boots", "Outerwear", "Shoes"]) {
    assert.equal(p.find((x) => x.tipo === tipo)?.livello, "importante", `${tipo}: ${JSON.stringify(p)}`);
  }
});

test("requisiti: la protezione dalla pioggia resta importante anche senza pioggia nel riepilogo", () => {
  const p = postiDelGeneratore([
    bisogno("guscio impermeabile", "Outerwear", ["Rain Jacket", "Windbreaker"],
      { minWarmth: 1, maxWarmth: 2, minWaterResistance: 2 }),
  ], { temp_min: 16, temp_max: 23 });
  assert.ok(p.some((x) => x.livello === "importante" && x.nome === "Giacca impermeabile"), JSON.stringify(p));
});

test("requisiti: giacca calda e guscio leggero incompatibili restano due posti", () => {
  const p = postiDi([
    assente("freddo", "Outerwear", ["Coat"], { warmth_richiesto: [4, 5] }),
    assente("pioggia", "Outerwear", ["Rain Jacket"], { warmth_richiesto: [1, 2], impermeabilita_richiesta: 2 }),
  ], { meteo: MITE }).filter((x) => x.tipo === "Outerwear");
  assert.equal(p.length, 2);
  assert.deepEqual(new Set(p.map((x) => x.nome)), new Set(["Giacca invernale", "Giacca impermeabile"]));
  assert.notEqual(p[0].id, p[1].id);
});

test("requisiti: un posto meteo compatibile conserva sia freddo sia pioggia nel motivo", () => {
  const p = postiDi([
    assente("freddo", "Outerwear", ["Coat"], { warmth_richiesto: [3, 5] }),
    assente("pioggia", "Outerwear", ["Rain Jacket"], { warmth_richiesto: [2, 4], impermeabilita_richiesta: 2 }),
  ], { meteo: MITE }).filter((x) => x.tipo === "Outerwear");
  assert.equal(p.length, 1);
  assert.match(p[0].motivo!, /freddo e alla pioggia/);
});

test("requisiti: camicie con fasce di calore incompatibili non diventano un posto solo", () => {
  const p = postiDi([
    assente("giorno caldo", "Upper Body", ["Shirt"], { warmth_richiesto: [1, 1] }),
    assente("sera fredda", "Upper Body", ["Shirt"], { warmth_richiesto: [3, 4] }),
  ], { meteo: MITE }).filter((x) => x.tipo === "Shirt");
  assert.equal(p.length, 2);
  assert.notEqual(p[0].id, p[1].id);
  assert.ok(p.some((x) => x.nome.includes("cald")));
  assert.ok(p.some((x) => !x.nome.includes("cald")));
});

test("requisiti: l'identita' resta stabile cambiando ordine, lingua e quantita'", () => {
  const camicia = assente("camicia", "Upper Body", ["Shirt"], { warmth_richiesto: [2, 3], formality: ["Business"] });
  const giacca = freddoGap("giacca", "Outerwear", "Coat");
  const prima = postiDi([camicia, giacca]);
  const dopo = postiDi([giacca, camicia], { lingua: "en" });
  assert.equal(prima.find((p) => p.tipo === "Shirt")!.id, dopo.find((p) => p.tipo === "Shirt")!.id);
  assert.equal(prima.find((p) => p.tipo === "Outerwear")!.id, dopo.find((p) => p.tipo === "Outerwear")!.id);
  const pochi = postiDi([{ ...camicia, tipo: "quantita_insufficiente", usi_richiesti: 7, usi_coperti: 2 }]);
  const tanti = postiDi([{ ...camicia, tipo: "quantita_insufficiente", usi_richiesti: 11, usi_coperti: 2 }]);
  assert.notEqual(pochi[0].copie, tanti[0].copie);
  assert.equal(pochi[0].id, tanti[0].id);
});

test("requisiti: l'intersezione di piu' fasce non unisce bisogni incompatibili indirettamente", () => {
  const p = postiDi([
    assente("a", "Upper Body", ["Shirt"], { warmth_richiesto: [1, 3] }),
    assente("b", "Upper Body", ["Shirt"], { warmth_richiesto: [3, 5] }),
    assente("c", "Upper Body", ["Shirt"], { warmth_richiesto: [4, 5] }),
  ], { meteo: MITE }).filter((x) => x.tipo === "Shirt");
  assert.equal(p.length, 2);
});

test("requisiti: richiesti conserva il massimo effettivo del calore per i posti", () => {
  const valigia = strategySlots(JSON.stringify([
    bisogno("camicia", "Upper Body", ["Shirt"], { minWarmth: 2, maxWarmth: 3, formality: ["Business"] }),
  ]), [], { giorni: 5, lavatrice: true, attivita: [], temp_min: 14, temp_max: 20, bagaglio: "trolley medio" });
  const r = valigia.richiesti.find((r: Bisogno) => r.slot === "camicia");
  assert.equal(r.minWarmth, 2);
  assert.equal(r.maxWarmth, 3);
});

test("requisiti: un intervallo non vincolante non cancella il freddo del viaggio", () => {
  const p = postiDelGeneratore([
    bisogno("testa coperta", "Accessory", ["Cap/Hat"]),
  ], { temp_min: -4, temp_max: 5 });
  assert.equal(p.find((x) => x.tipo === "Cap/Hat")!.livello, "importante");
  assert.match(p.find((x) => x.tipo === "Cap/Hat")!.nome, /cald/);
});

test("requisiti: un blazer compatibile copre piu' occasioni senza raddoppiare le copie", () => {
  const p = postiDi([
    assente("congresso", "Outerwear", ["Blazer"], { warmth_richiesto: [2, 3], formality: ["Business"] }),
    assente("cena di lavoro", "Outerwear", ["Blazer"], { warmth_richiesto: [2, 4], formality: ["Business"] }),
  ], { meteo: MITE }).filter((x) => x.tipo === "Blazer");
  assert.equal(p.length, 1);
  assert.equal(p[0].copie, 1);
});

test("posto, polare: le giacche del meteo restano un posto solo, 'Giacca invernale' (il capo tipico non lo cambia)", () => {
  const p = postiDelGeneratore([bisogno("capospalla caldo", "Outerwear", ["Coat", "Down Jacket"], { minWarmth: 5 })],
    { temp_min: -15, temp_max: -5 }, ["visite in citta"]);
  assert.match(p.find((x) => x.tipo === "Outerwear")!.nome, /^Giacc[ae] invernal[ei]$/);
});

test("posto: un bisogno senza capo tipico (nessun capo in fascia) resta a capoDelGap", () => {
  // Il generatore non trova nulla, nemmeno nell'armadio tipico: il posto c'e' e ha il capo di capoDelGap.
  const p = postiDelGeneratore([bisogno("strato", "Upper Body", ["Tank Top"], { minWarmth: 5, formality: ["Formal"] })],
    { temp_min: -40, temp_max: -30 }, ["visite in citta"]);
  assert.ok(p.length > 0);
});

test("destinazione singola: anche senza possederli compaiono i pantaloni da sci", () => {
  const ps = postiDelGeneratore([], { temp_min: -8, temp_max: -1 }, ["sci"], 5);
  assert.ok(ps.some((p) => p.tipo === "Ski Pants"));
});

test("destinazione singola: i capi da neve non compaiono per una visita estiva", () => {
  const ps = postiDelGeneratore([], { temp_min: 19, temp_max: 27 }, ["visite in citta"], 5);
  assert.ok(!ps.some((p) => p.tipo === "Ski Pants" || p.tipo === "Ski Jacket"));
});

test("destinazione singola: il controllo dei bisogni non raddoppia i costumi gia' proposti", () => {
  const valigia = strategySlots("[]", [], { giorni: 8, attivita: ["mare"], temp_min: 24, temp_max: 31 });
  const { posti } = postiApp(valigia, { capi: [], essenziali: [] }, new Map(), {
    viaggio: { giorni: 8, attivita: ["mare"], destinazione: { nome: "Malindi" } },
    meteo: { temp_min_media: 24, temp_max_media: 31 }, armadio: [] });
  assert.equal(posti.find((p) => p.tipo === "Swimwear")?.copie, 3);
});

// La priorita' dipende dall'attivita' dichiarata, non dal nome tecnico del capo.
const postoAttivita = (sub: string, attivita: string[], extra: Record<string, any> = {}) => {
  const category = ["Hiking Boots", "Water Shoes", "Snow Boots"].includes(sub) ? "Shoes" :
    ["Ski Jacket", "Ski Suit"].includes(sub) ? "Outerwear" : "Lower Body";
  return postiApp({ mancanti_canonici: [{ slot: "test", tipo: "assente", category,
    subCategories: [sub], warmth_richiesto: [1, 2], ...extra }], essenziali: TUTTI_ESSENZIALI },
    { capi: [], essenziali: [] }, new Map(), { armadio: [], viaggio: { giorni: 4, attivita },
      meteo: { temp_min_media: 18, temp_max_media: 25 } }).posti[0];
};

test("attivita': escursioni leggere non rendono gli scarponi automaticamente importanti", () => {
  assert.equal(postoAttivita("Hiking Boots", ["escursioni leggere"]).livello, "utile");
  assert.equal(postoAttivita("Hiking Boots", ["trekking"]).livello, "importante");
  assert.equal(postoAttivita("Hiking Boots", ["escursioni in quota"]).livello, "importante");
  assert.equal(postoAttivita("Hiking Boots", ["escursioni leggere e trekking"]).livello, "importante");
});

test("attivita': il mare rende importante il costume, non le scarpette da scoglio", () => {
  for (const sub of ["Swimwear", "Water Shoes"]) {
    assert.equal(postoAttivita(sub, ["visite in citta"]).livello, "utile");
    assert.equal(postoAttivita(sub, ["mare"]).livello, sub === "Water Shoes" ? "utile" : "importante");
    assert.equal(postoAttivita(sub, ["immersioni"]).livello, "importante");
  }
});

test("attivita': la neve rende importanti i capi da sci, la citta' temperata no", () => {
  for (const sub of ["Ski Pants", "Ski Jacket", "Ski Suit", "Snow Boots"]) {
    assert.equal(postoAttivita(sub, ["visite in citta"]).livello, "utile");
    assert.equal(postoAttivita(sub, ["sci"]).livello, "importante");
  }
});

test("attivita': la muta rimane utile anche per le immersioni", () => {
  assert.equal(postoAttivita("Wetsuit", ["immersioni"]).livello, "utile");
});

test("attivita': la protezione dalla pioggia resta importante senza trekking", () => {
  assert.equal(postoAttivita("Hiking Boots", ["escursioni leggere"], { impermeabilita_richiesta: 2 }).livello, "importante");
});

test("attivita': il trekking di un'altra tappa non rende importanti gli scarponi per la citta'", () => {
  const per = (nome: string) => postiApp({ mancanti_canonici: [{ tipo: "assente", category: "Shoes",
    subCategories: ["Hiking Boots"], warmth_richiesto: [1, 2], tappe: [nome] }], essenziali: TUTTI_ESSENZIALI },
    { capi: [], essenziali: [] }, new Map(), { armadio: [], viaggio: { giorni: 6, tappe: [
      { nome: "Centro", giorni: 3, attivita: ["escursioni leggere"] },
      { nome: "Monte", giorni: 3, attivita: ["trekking"] }] } }).posti[0].livello;
  assert.equal(per("Centro"), "utile");
  assert.equal(per("Monte"), "importante");
});

test("attivita': le copie mancanti usano la tappa del capo, non il trekking di un'altra tappa", () => {
  const armadio = caricaArmadio([{ id: "scarpe", name: "Scarponi", quantity: 1,
    ai_metadata: { category: "Shoes", subCategory: "Hiking Boots", warmth: 2 } }]);
  const per = (nome: string) => postiApp({ ideali: [{ item_id: "scarpe", tappe: [nome] }], ripieghi: [],
    mancanti_canonici: [], essenziali: TUTTI_ESSENZIALI },
    { capi: [{ item_id: "scarpe", quantita: 3, motivo: motivoGiorno }], essenziali: [] }, new Map([["scarpe", 1]]),
    { armadio, viaggio: { giorni: 6, tappe: [
      { nome: "Centro", giorni: 3, attivita: ["escursioni leggere"] },
      { nome: "Monte", giorni: 3, attivita: ["trekking"] }] } }).posti.find((p) => p.tipo === "Hiking Boots")!;
  assert.equal(per("Centro").livello, "utile");
  assert.equal(per("Monte").livello, "importante");
});

test("requisiti: gli obblighi tecnici distinti conservano identita' e tag per i kit", () => {
  const mancanti = ["Hiking", "Sport"].map((tag) => ({ ...assente(tag, "Upper Body", ["T-Shirt"]),
    requiredActivityTags: [tag] }));
  const ps = postiDi(mancanti, { meteo: MITE });
  assert.equal(ps.length, 2);
  assert.equal(new Set(ps.map((p) => p.id)).size, 2);
  assert.deepEqual(ps.map((p) => p.requisiti?.activityTags).sort(), [["Hiking"], ["Sport"]]);
});

test("requisiti: la copertura di uno slot assente resta disponibile ai kit", () => {
  const ps = postiDelGeneratore([bisogno("coperto", "Upper Body", ["Shirt"], { coverage: ["Long Sleeves"] })],
    { temp_min: 20, temp_max: 27 });
  assert.ok(ps.some((p) => p.tipo === "Shirt" && p.requisiti?.coverage?.includes("Long Sleeves")));
});

test("requisiti: un bisogno utile assorbito dal meteo restringe comunque i vincoli", () => {
  const ps = postiDi([
    assente("pioggia", "Outerwear", ["Rain Jacket"], { warmth_richiesto: [1, 5], impermeabilita_richiesta: 2 }),
    assente("vento leggero", "Outerwear", ["Windbreaker"], { warmth_richiesto: [1, 2] }),
  ], { meteo: MITE });
  assert.equal(ps.length, 1);
  assert.equal(ps[0].requisiti?.maxWarmth, 2);
  assert.equal(ps[0].requisiti?.minWaterResistance, 2);
});

test("requisiti: gli strati gia' proposti coprono il minimo senza un terzo doppione", () => {
  const ps = postiDelGeneratore([], { temp_min: -4, temp_max: 5 }, ["riunioni di lavoro"], 5);
  const medi = ps.filter((p) => ["Hoodie", "Sweater", "Sweatshirt", "Fleece"].includes(p.tipo));
  assert.equal(medi.reduce((n, p) => n + p.copie, 0), 2);
});

test("requisiti: due strati dello stesso tipo restano almeno due copie dopo la deduplicazione", () => {
  const ps = postiDelGeneratore([
    bisogno("primo strato", "Upper Body", ["Sweater"], { minWarmth: 3, frequency: "once" }),
    bisogno("secondo strato", "Upper Body", ["Sweater"], { minWarmth: 3, frequency: "once" }),
  ], { temp_min: -4, temp_max: 5 }, [], 5);
  const medi = ps.filter((p) => ["Hoodie", "Sweater", "Sweatshirt", "Fleece"].includes(p.tipo));
  assert.equal(medi.reduce((n, p) => n + p.copie, 0), 2);
});

test("scarpe per la pioggia: nome concreto, protezione nel motivo e nei requisiti", () => {
  const p = postiDi([pioggiaGap("scarpe per camminare", "Shoes", "Sneakers")], { meteo: MITE });
  const scarpe = p.find((p) => p.tipo === "Shoes")!;
  assert.equal(scarpe.nome, "Sneakers");
  assert.equal(scarpe.copie, 1);
  assert.equal(scarpe.livello, "importante");
  assert.equal(scarpe.requisiti?.minWaterResistance, 2);
  assert.match(scarpe.motivo!, /pioggia/);
});

test("mare generico: scarpette da scoglio utili e distinte dalle scarpe per la pioggia", () => {
  const p = postiDi([assente("calzature da mare", "Shoes", ["Water Shoes"], { warmth_richiesto: [1, 2] }),
    pioggiaGap("pioggia", "Shoes", "Sneakers")],
    { meteo: MITE, viaggio: { giorni: 10, attivita: ["mare"] } });
  assert.equal(p.find((p) => p.tipo === "Water Shoes")?.nome, "Scarpette da scoglio");
  assert.equal(p.find((p) => p.tipo === "Water Shoes")?.livello, "utile");
  assert.ok(p.some((p) => p.tipo === "Shoes" && p.livello === "importante"));
});

test("luoghi di culto al caldo: il foulard leggero non si chiama sciarpa", () => {
  const p = postiDi([assente("foulard", "Accessory", ["Scarf"], { warmth_richiesto: [1, 2] })],
    { meteo: { temp_min_media: 25, temp_max_media: 31 },
      viaggio: { giorni: 10, attivita: ["visite a siti religiosi"] } });
  assert.equal(p.find((p) => p.tipo === "Scarf")?.nome, "Foulard leggero");
  assert.equal(p.find((p) => p.tipo === "Scarf")?.livello, "utile");
  const inverno = postiDi([freddoGap("collo e mani", "Accessory", "Scarf")]);
  assert.equal(inverno.find((p) => p.tipo === "Scarf")?.nome, "Sciarpa calda");
});

test("scarpe da pioggia: il motivo spiega il bisogno anche quando il candidato e' troppo caldo", () => {
  const g = { ...pioggiaGap("scarpe", "Shoes", "Boots"), tipo: "posseduto_ma_inadatto",
    candidato_scartato: "Blundstone", candidato_warmth: 3, candidato_wr: 1 };
  const p = postiDi([g], { meteo: MITE }).find((p) => p.tipo === "Shoes")!;
  assert.equal(p.nome, "Stivali");
  assert.match(p.motivo!, /Blundstone/);
  assert.match(p.motivo!, /pioggia/);
});
