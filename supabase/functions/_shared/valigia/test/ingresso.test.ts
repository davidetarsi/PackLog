// Il controllo del viaggio che arriva dall'app e la riprova del modello.
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  alloggioDaTappe, GIORNI_MAX_SENZA_LAVATRICE, IngressoNonValido, lavatriceDaTappe, validaViaggio,
} from "../ingresso.ts";
import { conRiprova } from "../genera.ts";

const OGGI = "2026-10-19";
const luogo = { nome: "Lisbona", paese: "Portogallo", lat: 38.72, lon: -9.14 };
const rifiuta = (x: unknown, msg: RegExp) =>
  assert.throws(() => validaViaggio(x, OGGI), (e: unknown) => e instanceof IngressoNonValido && msg.test((e as Error).message));

test("viaggi validi", () => {
  assert.deepEqual(validaViaggio({ data_inizio: "2026-11-02", giorni: 5, destinazione: luogo,
    attivita: [" mare ", "musei"], bagaglio: "trolley medio", lavatrice: true }, OGGI), {
    data_inizio: "2026-11-02", giorni: 5, destinazione: { ...luogo, timezone: null },
    attivita: ["mare", "musei"], bagaglio: "trolley medio", alloggio: null, lavatrice: true });
  const t = validaViaggio({ data_inizio: "2027-02-20", tappe: [{ ...luogo, giorni: 3 },
    { nome: "Porto", lat: 41.15, lon: -8.61, giorni: 2, attivita: ["vino"] }] }, OGGI);
  assert.equal(t.giorni, 5);
  assert.deepEqual(t.tappe![1].attivita, ["vino"]);
  assert.equal(t.tappe![1].paese, null);
  // senza dettagli (trip-weather): solo date e luoghi
  assert.deepEqual(Object.keys(validaViaggio({ data_inizio: "2026-11-02", giorni: 2, destinazione: luogo,
    attivita: 3 }, OGGI, false)), ["data_inizio", "giorni", "destinazione"]);
});

test("viaggi rifiutati", () => {
  rifiuta(null, /manca il viaggio/);
  rifiuta({ data_inizio: "2026-02-30", giorni: 2, destinazione: luogo }, /non e' una data/);
  rifiuta({ data_inizio: "02/11/2026", giorni: 2, destinazione: luogo }, /AAAA-MM-GG/);
  rifiuta({ data_inizio: "2030-01-01", giorni: 2, destinazione: luogo }, /fuori intervallo/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 0, destinazione: luogo }, /fra 1 e 60/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 2.5, destinazione: luogo }, /fra 1 e 60/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 2 }, /destinazione/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 2, destinazione: { ...luogo, lat: 91 } }, /lat/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 2, destinazione: { ...luogo, nome: "" } }, /nome/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 2, destinazione: luogo, attivita: ["x".repeat(81)] }, /troppo lungo/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 2, destinazione: luogo, attivita: Array(21).fill("a") }, /al massimo 20/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 2, destinazione: luogo, lavatrice: "si" }, /lavatrice/);
  rifiuta({ data_inizio: "2026-11-02", tappe: [] }, /non vuoto/);
  rifiuta({ data_inizio: "2026-11-02", giorni: 9, tappe: [{ ...luogo, giorni: 3 }] }, /somma delle tappe/);
  rifiuta({ data_inizio: "2026-11-02", tappe: Array(9).fill({ ...luogo, giorni: 1 }) }, /al massimo 8/);
  rifiuta({ data_inizio: "2026-11-02", tappe: [{ ...luogo, giorni: 40 }, { ...luogo, giorni: 30 }] }, /troppo lungo/);
});

test("il modello si richiede una volta se il JSON non si legge", async () => {
  let n = 0;
  const r = await conRiprova(async () => ({ testo: ++n === 1 ? "Ecco:" : "```json\n[]\n```" }))("p");
  assert.equal(n, 2);
  assert.equal(r.testo, "```json\n[]\n```");
  n = 0;
  await assert.rejects(conRiprova(async () => ({ testo: (n++, "no") }))("p"), /non leggibile/);
  assert.equal(n, 2);
});

test("lavatrice: regola dei 5 giorni", () => {
  assert.equal(GIORNI_MAX_SENZA_LAVATRICE, 5);
  assert.equal(lavatriceDaTappe([{ giorni: 5, lavatrice: false }, { giorni: 4, lavatrice: true }]), true);
  assert.equal(lavatriceDaTappe([{ giorni: 7, lavatrice: false }, { giorni: 4, lavatrice: true }]), false);
  assert.equal(lavatriceDaTappe([{ giorni: 9, lavatrice: true }]), true);
  assert.equal(lavatriceDaTappe([{ giorni: 3, lavatrice: false }]), false);
  assert.equal(lavatriceDaTappe([{ giorni: 4, lavatrice: true }, { giorni: 6, lavatrice: false }]), false);
  assert.equal(lavatriceDaTappe([{ giorni: 3, lavatrice: false }, { giorni: 3, lavatrice: false }, { giorni: 2, lavatrice: true }]), false);
});

test("alloggio dalle tappe", () => {
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: null }]), null);
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: "hotel" }, { nome: "Olanda", alloggio: "hotel" }]), "hotel");
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: "hotel" }, { nome: "Olanda", alloggio: "appartamento" }]),
    "hotel (Islanda), appartamento (Olanda)");
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: null }, { nome: "Olanda", alloggio: "ostello" }]), "ostello");
});

test("tappe con alloggio e lavatrice", () => {
  const t = validaViaggio({ data_inizio: "2026-11-02", tappe: [
    { ...luogo, giorni: 5, alloggio: "hotel", lavatrice: false },
    { nome: "Porto", lat: 41.15, lon: -8.61, giorni: 4, alloggio: "appartamento", lavatrice: true }] }, OGGI);
  assert.equal(t.lavatrice, true);
  assert.equal(t.alloggio, "hotel (Lisbona), appartamento (Porto)");
  assert.equal("alloggio" in t.tappe![0], false);
  // il formato vecchio vince
  assert.equal(validaViaggio({ data_inizio: "2026-11-02", lavatrice: false, tappe: [{ ...luogo, giorni: 3, lavatrice: true }] }, OGGI).lavatrice, false);
  rifiuta({ data_inizio: "2026-11-02", tappe: [{ ...luogo, giorni: 3, lavatrice: "si" }] }, /lavatrice/);
});
