// Il meteo del porting contro quello del bench (esporta_oracolo.py meteo):
// metriche, quota, chiave della cache, fonte, weather() con un Open-Meteo
// finto (stesse risposte, stesse richieste) e unione delle tappe.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { chiaveCache, correggiQuota, deriva, fonteMeteo, meteo, type Servizi, unisciTappe } from "../meteo.ts";

const casi: any[] = JSON.parse(readFileSync(new URL("./oracolo_meteo.json", import.meta.url), "utf8"));
const di = (f: string) => casi.filter((c) => c.f === f);
const copia = <T>(x: T): T => structuredClone(x);
// -0.0 e 0.0: la cache (JSON nel bench, jsonb in Supabase) non sempre li distingue
const senzaMenoZero = (x: unknown) => JSON.parse(JSON.stringify(x));

test("metriche derivate, quota, chiave, fonte", () => {
  for (const c of di("derive")) assert.deepEqual(deriva(copia(c.args[0]), c.args[1]), c.out, JSON.stringify(c.args));
  for (const c of di("correggi_quota")) assert.deepEqual(correggiQuota(copia(c.args[0]), c.args[1], c.args[2]), c.out);
  for (const c of di("cache_key")) assert.equal(chiaveCache(c.args[0], c.args[1], c.args[2], c.args[3], c.args[4]), c.out);
  for (const c of di("fonte_meteo")) assert.equal(fonteMeteo(c.args[0], c.args[1], c.args[2]), c.out);
});

const firma = (url: string, p: Record<string, unknown>) =>
  url + "|" + JSON.stringify(Object.keys(p).sort().map((k) => [k, p[k]]));

test("weather intero con Open-Meteo finto, cache condivisa fra le chiamate", async () => {
  const cache = new Map<string, string>();
  let n = 0;
  for (const c of di("weather")) {
    const risposte = new Map<string, any>();
    for (const r of c.richieste) risposte.set(firma(r.url, r.params), r);
    const fatte: string[] = [];
    const s: Servizi = {
      async scarica(url, params) {
        const k = firma(url, params);
        fatte.push(k);
        const r = risposte.get(k);
        assert.ok(r, `richiesta non attesa: ${k}`);
        return { status: r.stato, json: async () => copia(r.risposta ?? {}) };
      },
      async leggiCache(k) { return cache.has(k) ? JSON.parse(cache.get(k)!) : null; },
      async scriviCache(k, v) { cache.set(k, JSON.stringify(v)); },
      oggiUtc: () => "2026-10-19",
      oggi: () => "2026-10-19",
      async attendi() {},
    };
    let out: unknown = null, errore: string | null = null;
    try {
      out = await meteo(c.args[0], c.args[1], c.args[2], c.args[3], c.args[4], s);
    } catch (e) {
      errore = (e as Error).message;
    }
    assert.equal(errore, c.errore);
    assert.deepEqual(senzaMenoZero(out), senzaMenoZero(c.out), JSON.stringify(c.args));
    assert.deepEqual(fatte.sort(), c.richieste.map((r: any) => firma(r.url, r.params)).sort());
    n++;
  }
  assert.ok(n >= 200);
});

test("unione delle tappe", () => {
  for (const c of di("unisci_tappe")) {
    const [geo, wx] = unisciTappe(copia(c.args[0]));
    assert.deepEqual(senzaMenoZero([geo, wx]), senzaMenoZero(c.out));
  }
});
