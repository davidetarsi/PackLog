// Il giorno per giorno delle normali climatiche: medie per giorno di calendario,
// 29 febbraio, dati mancanti, e il percorso di meteo() con la cache.
import { test } from "node:test";
import assert from "node:assert/strict";
import { giorniStorici, meteo, type Servizi } from "../meteo.ts";

/** Un anno di archivio finto: per ogni data tmax=base+g, tmin=base, vento=20, pioggia data. */
function anno(date: string[], base: number, pioggia: (number | null)[], tmax: (number | null)[] | null = null) {
  return {
    elevation: 10,
    daily: {
      time: date,
      temperature_2m_max: tmax ?? date.map((_, i) => base + i),
      temperature_2m_min: date.map(() => base),
      precipitation_sum: pioggia,
      wind_speed_10m_max: date.map(() => 20),
    },
  };
}

test("media per giorno e pioggia come anni su anni con dato", () => {
  const r = [
    anno(["2024-07-01", "2024-07-02"], 10, [0, 1.0]),
    anno(["2023-07-01", "2023-07-02"], 12, [3, 1.1]),
    anno(["2022-07-01", "2022-07-02"], 14, [null, 5]),
  ];
  const g = giorniStorici("2026-07-01", "2026-07-02", r);
  assert.deepEqual(g.map((x) => x.data), ["2026-07-01", "2026-07-02"]);
  assert.equal(g[0].temp_min, 12);
  assert.equal(g[0].temp_max, 12);          // (10+12+14)/3
  assert.equal(g[1].temp_max, 13);          // (11+13+15)/3
  assert.equal(g[0].vento_max_kmh, 20);
  // 1 luglio: 0 e 3 hanno il dato (uno nullo), solo il 3 supera 1 mm
  assert.deepEqual([g[0].anni_pioggia, g[0].anni_con_dato], [1, 2]);
  // 2 luglio: 1.0 non supera la soglia, 1.1 e 5 si
  assert.deepEqual([g[1].anni_pioggia, g[1].anni_con_dato], [2, 3]);
});

test("29 febbraio conta solo negli anni bisestili e non sposta gli altri giorni", () => {
  const bisestile = anno(["2024-02-28", "2024-02-29", "2024-03-01"], 10, [0, 2, 0]);
  const comune = anno(["2023-02-28", "2023-03-01"], 20, [0, 0]);
  const g = giorniStorici("2028-02-28", "2028-03-01", [bisestile, comune]);
  assert.equal(g.length, 3);
  assert.equal(g[1].data, "2028-02-29");
  assert.equal(g[1].temp_min, 10);                       // solo il bisestile
  assert.deepEqual([g[1].anni_pioggia, g[1].anni_con_dato], [1, 1]);
  assert.equal(g[2].temp_min, 15);                       // 1 marzo: entrambi, nonostante la posizione diversa
  assert.deepEqual([g[2].anni_pioggia, g[2].anni_con_dato], [0, 2]);
});

test("senza nessun dato il giorno resta con valori nulli", () => {
  const g = giorniStorici("2026-07-01", "2026-07-01", [anno(["2025-07-01"], 10, [null], [null])]);
  assert.equal(g[0].temp_max, null);
  assert.equal(g[0].temp_min, 10);
  assert.deepEqual([g[0].anni_pioggia, g[0].anni_con_dato], [0, 0]);
});

function servizi() {
  const cache = new Map<string, string>();
  let richieste = 0;
  const s: Servizi = {
    async scarica(_u, p) {
      richieste++;
      const a = Number(String(p.start_date).slice(0, 4));
      return { status: 200, json: async () => anno([`${a}-07-01`, `${a}-07-02`], 10, [0, 2]) };
    },
    async leggiCache(k) { return cache.has(k) ? JSON.parse(cache.get(k)!) : null; },
    async scriviCache(k, v) { cache.set(k, JSON.stringify(v)); },
    oggiUtc: () => "2026-10-19",
    oggi: () => "2026-10-19",
    async attendi() {},
  };
  return { s, cache, richieste: () => richieste };
}

test("meteo() non cambia con il giorno per giorno e una voce vecchia si ricalcola una volta", async () => {
  const { s, cache, richieste } = servizi();
  const base = await meteo(40, 10, "2027-07-01", "2027-07-02", null, s);
  assert.equal(richieste(), 5);
  assert.ok(!("giorni_storici" in base));
  // una voce nata prima del dettaglio non ha la voce dei giorni: si rifa una volta
  for (const k of [...cache.keys()]) if (k.endsWith("|giorni")) cache.delete(k);
  let g1: any;
  const conGiorni = await meteo(40, 10, "2027-07-01", "2027-07-02", null, s, (g) => { g1 = g; });
  assert.equal(richieste(), 10);
  assert.equal(g1.length, 2);
  assert.deepEqual([g1[1].anni_pioggia, g1[1].anni_con_dato], [5, 5]);
  // ora e' in cache: niente richieste, stesso dettaglio
  let g2: any;
  const dalCache = await meteo(40, 10, "2027-07-01", "2027-07-02", null, s, (g) => { g2 = g; });
  assert.equal(richieste(), 10);
  assert.equal(dalCache.da_cache, true);
  assert.deepEqual(g2, g1);
  assert.deepEqual(cache.size, 2);
});

test("senza il parametro nessuna voce |giorni viene scritta", async () => {
  const { s, cache } = servizi();
  await meteo(40, 10, "2027-07-01", "2027-07-02", null, s);
  assert.ok([...cache.keys()].every((k) => !k.endsWith("|giorni")));
  assert.equal(cache.size, 1);
});

test("lo stesso viaggio chiesto un altro anno riceve le date di quell'anno", async () => {
  const { s } = servizi();
  let a: any, b: any;
  await meteo(40, 10, "2027-07-15", "2027-07-20", null, s, (g) => { a = g; });
  await meteo(40, 10, "2028-07-15", "2028-07-20", null, s, (g) => { b = g; });
  assert.equal(a[0].data, "2027-07-15");
  assert.equal(b[0].data, "2028-07-15");
  assert.equal(b.length, 6);
  assert.equal(b[5].data, "2028-07-20");
});
