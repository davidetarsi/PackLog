// I posti dai mancanti: livello (importante/utile) e nome mostrato all'utente.
// Uso: node --test valigia/test/posti.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { livelloPosto, nomePosto, qualificaDelGap } from "../posti.ts";
import { capoDelGap, NOME_CATEGORIA, NOME_SOTTOCATEGORIA } from "../uscita.ts";
import { NOMI_CATEGORIA, NOMI_SOTTOCATEGORIA } from "../posti_nomi.ts";

const livello = (g: Record<string, any>, viaggioFreddo = false) =>
  livelloPosto(g, capoDelGap(g, viaggioFreddo), viaggioFreddo);

test("livello: la giacca col freddo e' importante, il maglione col freddo no", () => {
  const giacca = { tipo: "assente", category: "Outerwear", subCategories: ["Coat", "Down Jacket", "Casual Jacket", "Windbreaker"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  const maglione = { tipo: "assente", category: "Upper Body", subCategories: ["Sweater"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  assert.equal(livelloPosto(giacca, capoDelGap(giacca, true), true), "importante");
  assert.equal(livelloPosto(maglione, capoDelGap(maglione, true), true), "utile");
});

test("livello: magliette necessarie restano utili; costume e scarponi importanti; camicia elegante importante", () => {
  const maglietta = { tipo: "assente", category: "Upper Body", subCategories: ["T-Shirt"], priorita: "necessario" };
  const costume = { tipo: "assente", category: "Lower Body", subCategories: ["Swimwear"], priorita: "consigliato" };
  const scarponi = { tipo: "assente", category: "Shoes", subCategories: ["Hiking Boots"], priorita: "necessario" };
  const camicia = { tipo: "assente", category: "Upper Body", subCategories: ["Shirt"], formality: ["Formal"] };
  assert.equal(livello(maglietta), "utile");
  assert.equal(livello(costume), "importante");
  assert.equal(livello(scarponi), "importante");
  assert.equal(livello(camicia), "importante");
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
  assert.deepEqual(nomePosto({ sub: "Fleece", categoria: "Upper Body" }, 1, "freddo", "it"), { nome: "Pile caldo", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Fleece", categoria: "Upper Body" }, 2, "freddo", "it"), { nome: "Pile caldi", aggiungi: "Aggiungi i tuoi" });
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
import { essenzialiPerViaggio } from "../quantita.ts";
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
  // id dall'ordine finale
  posti.forEach((p, i) => assert.equal(p.id, `${p.tipo}:${i}`));
});

test("postiApp Seul: copie, tipi e categorie", () => {
  const p = perNome(seul().posti);
  // 31 giorni senza lavatrice: le quantita' di GIORNI_LAVANDERIA giorni
  assert.equal(K.GIORNI_LAVANDERIA, 14);
  assert.deepEqual([p.get("Giacca invernale")!.copie, p.get("Giacca invernale")!.tipo], [1, "Outerwear"]);
  assert.deepEqual([p.get("Guanti")!.copie, p.get("Guanti")!.tipo], [1, "Gloves"]);
  assert.deepEqual([p.get("Maglioni caldi")!.copie, p.get("Maglioni caldi")!.tipo], [3, "Sweater"]);
  assert.deepEqual([p.get("Magliette")!.copie, p.get("Magliette")!.tipo], [14, "T-Shirt"]);
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
  assert.equal(r.posti[0].id, "T-Shirt:0");
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

test("postiApp: due mancanti T-Shirt da slot diversi, un posto con le copie sommate", () => {
  const a = assente("Magliette", "Upper Body", ["T-Shirt"]);
  const b = assente("Magliette per la sera", "Upper Body", ["T-Shirt"]);
  const tutte = [{ radice: "mutand" }, { radice: "calz" }, { radice: "pigiama" }, { radice: "necessaire" }];
  const r = postiApp({ mancanti_canonici: [a, b], richiesti: richiestiDi([a, b], { "Magliette per la sera": "occasional" }),
    essenziali: tutte }, { capi: [], essenziali: [] }, new Map(),
  { meteo: { temp_min_media: 15, temp_max_media: 24 }, viaggio: { giorni: 5, lavatrice: false }, armadio: [] });
  // 5 al giorno + round(5 * 0.4) = 2 per la sera
  assert.deepEqual(r.posti.map((p) => [p.tipo, p.nome, p.copie]), [["T-Shirt", "Magliette", 7]]);
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
