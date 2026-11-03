// Quando l'archivio storico non risponde, l'errore dice perche': stato e motivo
// di Open-Meteo per ogni anno, cosi' i log della funzione bastano a capirlo.
import { test } from "node:test";
import assert from "node:assert/strict";
import { meteo, type Servizi } from "../meteo.ts";

function servizi(stato: number, corpo: unknown): Servizi {
  return {
    scarica: async () => ({ status: stato, json: async () => corpo }),
    leggiCache: async () => null,
    scriviCache: async () => {},
    oggiUtc: () => "2026-11-03",
    oggi: () => "2026-11-03",
    attendi: async () => {},
  } as Servizi;
}

test("archivio che rifiuta: l'errore riporta stato e motivo", async () => {
  const s = servizi(429, { error: true, reason: "Daily API request limit exceeded" });
  await assert.rejects(meteo(3.2, 73.22, "2026-12-10", "2026-12-17", null, s), (e: Error) => {
    assert.match(e.message, /archivio storico non disponibile/);
    assert.match(e.message, /HTTP 429 Daily API request limit exceeded/);
    assert.match(e.message, /2026-12-10\.\.2026-12-17/);
    return true;
  });
});

test("archivio senza giorni: l'errore lo dice", async () => {
  const s = servizi(200, { daily: { time: [] } });
  await assert.rejects(meteo(3.2, 73.22, "2026-12-10", "2026-12-17", null, s), /risposta senza giorni/);
});
