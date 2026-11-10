// I viaggi salvati prima del catalogo (spec del 31 ottobre 2026, § 7.1): un id
// di attivita' o di alloggio deve dare al generatore ESATTAMENTE il testo che gli
// dava l'enum dell'app (AiActivity e AiStay in lib/features/trips/model/
// ai_packing.dart al commit bbf66c0). Cosi' un viaggio salvato, rigenerato dopo
// il catalogo, ha la stessa valigia di prima.
//
// QUESTO TEST NON SI AGGIORNA quando si cambia il catalogo. Se fallisce, la
// modifica fa cambiare la valigia dei viaggi esistenti: la voce va ripristinata
// (id e testi non si cambiano), e un significato nuovo e' una voce nuova con la
// vecchia disattivata. Si puo' solo AGGIUNGERE una riga (una voce nuova) a
// ATTIVITA_ENUM o ALLOGGI_ENUM, mai cambiarne una.
//
// Un esempio del perche': "cene di lavoro" in Lavoro contiene la radice "cene" della
// regola della sera, e avrebbe dato un capo presentabile in piu' ai viaggi di lavoro.
// Uso: node --test _shared/catalogo/test/viaggi_esistenti.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { CATALOGO_BASE, testiAttivita, testoAlloggio, voci } from "../catalogo.ts";

// id -> generatorCodes dell'enum AiActivity a bbf66c0, nell'ordine dell'enum.
const ATTIVITA_ENUM: [string, string[]][] = [
  ["city", ["visite in citta"]],
  ["walks", ["escursioni leggere"]],
  ["trekking", ["trekking"]],
  ["cammino", ["cammino"]],
  ["high_mountain", ["escursioni in quota"]],
  ["sea", ["mare"]],
  ["diving", ["immersioni", "mare"]],
  ["ski", ["sci"]],
  ["camping", ["campeggio"]],
  ["work", ["riunioni di lavoro"]],
  ["formal_dinner", ["cena formale"]],
  ["wedding", ["matrimonio"]],
  ["worship", ["visite a siti religiosi"]],
  ["nightlife", ["vita notturna"]],
  ["cycling", ["bicicletta"]],
  ["spa", ["terme"]],
];

// id -> generatorText dell'enum AiStay a bbf66c0.
const ALLOGGI_ENUM: [string, string][] = [
  ["hotel", "hotel"],
  ["apartment", "appartamento"],
  ["hostel", "ostello"],
  ["camping", "campeggio"],
  ["friends", "da amici o parenti"],
];

test("ogni attivita' dell'enum vecchio ha gli stessi testi nel catalogo", () => {
  for (const [id, testi] of ATTIVITA_ENUM) {
    assert.deepEqual(testiAttivita(CATALOGO_BASE, [id]), testi, id);
    const v = CATALOGO_BASE.voci.find((x) => x.domain === "activity" && x.id === id);
    assert.deepEqual(v?.data.generator, testi, `${id}: testi nel catalogo`);
  }
});

test("tutte le attivita' insieme: stessi testi, stesso ordine, senza doppioni", () => {
  const atteso: string[] = [];
  for (const [, testi] of ATTIVITA_ENUM) for (const t of testi) if (!atteso.includes(t)) atteso.push(t);
  assert.deepEqual(testiAttivita(CATALOGO_BASE, ATTIVITA_ENUM.map(([id]) => id)), atteso);
});

test("ogni alloggio dell'enum vecchio ha lo stesso testo nel catalogo", () => {
  for (const [id, testo] of ALLOGGI_ENUM) assert.equal(testoAlloggio(CATALOGO_BASE, id), testo, id);
  assert.deepEqual(voci(CATALOGO_BASE, "stay", false).map((v) => v.id), ALLOGGI_ENUM.map(([id]) => id));
});

test("le attivita' dell'enum vecchio ci sono tutte, anche se disattivate", () => {
  const ids = new Set(voci(CATALOGO_BASE, "activity", false).map((v) => v.id));
  for (const [id] of ATTIVITA_ENUM) assert.ok(ids.has(id), `${id} sparita dal catalogo: si disattiva, non si toglie`);
});
