// Il dettaglio dei prossimi giorni con un Open-Meteo finto: finestra dei
// sette giorni, fasce di quattro ore, cache per il giorno e tappe in fila.
import { test } from "node:test";
import assert from "node:assert/strict";
import { componiGiorni, finestra, giorniTappa, pianoTappe } from "../giorni.ts";
import type { Servizi } from "../meteo.ts";

/** Due giorni di ore finte: la temperatura e' l'ora, piove dalle 14 alle 15 del
 *  secondo giorno, e il codice e' 3 di notte e 61 nella fascia della pioggia. */
function risposta(giorni: string[]) {
  const time: string[] = [], temp: number[] = [], prob: number[] = [], mm: number[] = [];
  const codice: number[] = [], vento: number[] = [];
  for (const [n, d] of giorni.entries()) {
    for (let h = 0; h < 24; h++) {
      time.push(`${d}T${String(h).padStart(2, "0")}:00`);
      temp.push(h);
      const piove = n === 1 && (h === 14 || h === 15);
      prob.push(piove ? 80 : 10);
      mm.push(piove ? 1.25 : 0);
      codice.push(piove ? 61 : h < 4 ? 3 : 1);
      vento.push(10 + h);
    }
  }
  return {
    daily: {
      time: giorni,
      weather_code: giorni.map((_, i) => (i === 1 ? 61 : 3)),
      temperature_2m_max: giorni.map(() => 23.04),
      temperature_2m_min: giorni.map(() => 0),
      precipitation_sum: giorni.map((_, i) => (i === 1 ? 2.5 : 0)),
      precipitation_probability_max: giorni.map((_, i) => (i === 1 ? 80 : 10)),
      wind_speed_10m_max: giorni.map(() => 33),
      uv_index_max: giorni.map(() => 5.55),
    },
    hourly: {
      time,
      temperature_2m: temp,
      precipitation_probability: prob,
      precipitation: mm,
      weather_code: codice,
      wind_speed_10m: vento,
    },
  };
}

function servizi(oggi: string) {
  const cache = new Map<string, string>();
  const richieste: Record<string, string | number>[] = [];
  const s: Servizi = {
    async scarica(_url, params) {
      richieste.push(params);
      const giorni: string[] = [];
      for (let d = Date.parse(params.start_date + "T00:00:00Z"); d <= Date.parse(params.end_date + "T00:00:00Z");
        d += 86400000) giorni.push(new Date(d).toISOString().slice(0, 10));
      return { status: 200, json: async () => risposta(giorni) };
    },
    async leggiCache(k) { return cache.has(k) ? JSON.parse(cache.get(k)!) : null; },
    async scriviCache(k, v) { cache.set(k, JSON.stringify(v)); },
    oggiUtc: () => oggi,
    oggi: () => oggi,
    async attendi() {},
  };
  return { s, richieste };
}

test("finestra: solo i prossimi sette giorni della tappa", () => {
  assert.deepEqual(finestra("2026-10-22", "2026-10-25", "2026-10-21"), ["2026-10-22", "2026-10-25"]);
  assert.deepEqual(finestra("2026-10-19", "2026-10-22", "2026-10-21"), ["2026-10-21", "2026-10-22"]);
  assert.deepEqual(finestra("2026-10-25", "2026-11-05", "2026-10-21"), ["2026-10-25", "2026-10-27"]);
  assert.equal(finestra("2026-10-28", "2026-10-30", "2026-10-21"), null);
  assert.equal(finestra("2026-10-10", "2026-10-20", "2026-10-21"), null);
});

test("sei fasce di quattro ore per giorno", () => {
  const r = risposta(["2026-10-22", "2026-10-23"]);
  const giorni = componiGiorni(r.daily, r.hourly);
  assert.equal(giorni.length, 2);
  const [primo, secondo] = giorni;
  assert.equal(primo.data, "2026-10-22");
  assert.equal(primo.temp_max, 23);
  assert.equal(primo.uv_max, 5.6);
  assert.deepEqual(primo.fasce.map((f) => f.da), [0, 4, 8, 12, 16, 20]);
  // media delle ore 0..3, codice piu' severo, vento massimo
  assert.deepEqual(primo.fasce[0], {
    da: 0, codice: 3, temp_media: 1.5, prob_pioggia: 10, pioggia_mm: 0, vento_kmh: 13,
  });
  assert.equal(primo.fasce[5].temp_media, 21.5);
  // la pioggia delle 14 e 15 sta nella fascia 12-16 del secondo giorno
  assert.deepEqual(secondo.fasce[3], {
    da: 12, codice: 61, temp_media: 13.5, prob_pioggia: 80, pioggia_mm: 2.5, vento_kmh: 25,
  });
  assert.equal(secondo.fasce[2].pioggia_mm, 0);
});

test("giorni di una tappa: fuori finestra niente rete, poi la cache del giorno", async () => {
  const { s, richieste } = servizi("2026-10-21");
  assert.deepEqual(await giorniTappa(38.7, -9.1, "2026-11-01", "2026-11-03", s), []);
  assert.equal(richieste.length, 0);

  const giorni = await giorniTappa(38.7, -9.1, "2026-10-25", "2026-11-02", s);
  assert.deepEqual(giorni.map((g) => g.data), ["2026-10-25", "2026-10-26", "2026-10-27"]);
  assert.equal(richieste.length, 1);
  assert.equal(richieste[0].start_date, "2026-10-25");
  assert.equal(richieste[0].end_date, "2026-10-27");
  assert.equal(richieste[0].timezone, "auto");

  await giorniTappa(38.7, -9.1, "2026-10-25", "2026-11-02", s);
  assert.equal(richieste.length, 1);
});

test("tappe in fila dalla partenza", () => {
  assert.deepEqual(pianoTappe("2026-10-30", [{ giorni: 3 }, { giorni: 3 }]), [
    { da: "2026-10-30", a: "2026-11-01" },
    { da: "2026-11-02", a: "2026-11-04" },
  ]);
});
