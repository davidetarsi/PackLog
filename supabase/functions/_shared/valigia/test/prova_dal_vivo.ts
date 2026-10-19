// Prova dal vivo del giro intero con GPT, Jev e Open-Meteo veri (costa: solo
// con l'ok di Davide). Le chiavi arrivano dall'ambiente (OPENAI_KEY,
// TYPESAFE_API_KEY), mai stampate: lanciarla con prova_dal_vivo.py del bench.
// Scrive per ogni viaggio cio' che serve a rigiocarlo nel bench Python.
// Uso: node test/prova_dal_vivo.ts USCITA.json
import { readFileSync, writeFileSync } from "node:fs";
import type { RigaArmadio } from "../capo.ts";
import { climaViaggio, type Servizi } from "../../clima/meteo.ts";
import { conRiprova, generaValigia, openaiHttp, scenarioDaApp } from "../genera.ts";
import { validaViaggio } from "../ingresso.ts";
import { jevHttp } from "../jev.ts";

const BENCH = "/srv/claude/workspaces/AI-checklist-test-script/";
const cache = new Map<string, any>();
const meteo: Servizi = {
  async scarica(url, params) {
    const u = new URL(url);
    for (const [k, v] of Object.entries(params)) u.searchParams.set(k, String(v));
    const r = await fetch(u, { signal: AbortSignal.timeout(30000) });
    return { status: r.status, json: () => r.json() };
  },
  async leggiCache(k) { return cache.has(k) ? structuredClone(cache.get(k)) : null; },
  async scriviCache(k, v) { cache.set(k, structuredClone(v)); },
  oggiUtc: () => new Date().toISOString().slice(0, 10),
  oggi: () => new Date().toISOString().slice(0, 10),
  attendi: (t) => new Promise<void>((r) => setTimeout(r, 1000 * (t + 1))),
};

const VIAGGI: [string, string, unknown][] = [
  ["lisbona_citta", "inventory_cache.json", { data_inizio: "2026-10-24", giorni: 4,
    destinazione: { nome: "Lisbona", paese: "Portogallo", lat: 38.7223, lon: -9.1393 },
    attivita: ["visite in citta", "cene al ristorante"], bagaglio: "trolley medio", alloggio: "hotel" }],
  ["milano_lavoro", "inventory_cache.json", { data_inizio: "2026-10-27", giorni: 3,
    destinazione: { nome: "Milano", paese: "Italia", lat: 45.4642, lon: 9.19 },
    attivita: ["riunioni di lavoro", "cena elegante"], bagaglio: "borsa a tracolla", alloggio: "hotel" }],
  ["cortina_trekking", "inventory_cache.json", { data_inizio: "2027-07-10", giorni: 5,
    destinazione: { nome: "Cortina d'Ampezzo", paese: "Italia", lat: 46.5369, lon: 12.13903 },
    attivita: ["trekking", "cene al ristorante"], bagaglio: "zaino da 40 litri", alloggio: "rifugio" }],
  ["bali_mare", "wardrobe_femminile.json", { data_inizio: "2027-08-01", giorni: 10,
    destinazione: { nome: "Ubud", paese: "Indonesia", lat: -8.5069, lon: 115.2625 },
    attivita: ["mare", "visita ai templi", "snorkeling", "cene informali"], bagaglio: "valigia grande",
    alloggio: "villa", lavatrice: true }],
  ["islanda_olanda", "wardrobe_femminile.json", { data_inizio: "2027-02-20", tappe: [
    { nome: "Reykjavik", paese: "Islanda", lat: 64.1355, lon: -21.8954, giorni: 5,
      attivita: ["aurora boreale", "terme geotermali", "escursioni leggere"] },
    { nome: "Amsterdam", paese: "Paesi Bassi", lat: 52.3676, lon: 4.9041, giorni: 4,
      attivita: ["visite in citta", "musei", "cene informali"] }],
    bagaglio: "valigia grande", alloggio: "hotel" }],
];

const out: unknown[] = [];
for (const [id, armadio, corpo] of VIAGGI) {
  const righe: RigaArmadio[] = JSON.parse(readFileSync(BENCH + armadio, "utf8"));
  const v = validaViaggio(corpo, new Date().toISOString().slice(0, 10));
  const t0 = Date.now();
  const r = await generaValigia(scenarioDaApp(v), righe, {
    clima: () => climaViaggio(v.data_inizio, v.giorni, v.destinazione ?? null, v.tappe ?? null, meteo),
    modello: conRiprova(openaiHttp(process.env.OPENAI_KEY!)),
    jev: jevHttp(process.env.TYPESAFE_API_KEY!),
  });
  const ms = Date.now() - t0;
  const s = r.valigia;
  console.log(`${id}: ${ms} ms, ${r.meteo.fonte}, min ${r.meteo.temp_min_media} max ${r.meteo.temp_max_media}; `
    + `${s.ideali.length} ideali, ${s.ripieghi.length} ripieghi, ${s.essenziali.length} essenziali, `
    + `${(s.mancanti ?? []).length} mancanti; token ${r.uso?.prompt_tokens}+${r.uso?.completion_tokens}; `
    + `Jev: ${Object.keys(r.diagnostica.jev.profili_capi ?? {}).length} profili, `
    + `${Object.keys(r.diagnostica.jev.voti_scarpe ?? {}).length} scarpe, `
    + `${Object.keys(r.diagnostica.jev.scarti_capi ?? {}).length} capi, classi ${r.diagnostica.jev.classi_viaggio ? "si" : "no"}`
    + (r.jev.errori.length ? `; ERRORI Jev ${r.jev.errori.length}: ${r.jev.errori.slice(0, 2).join(" | ")}` : ""));
  out.push({ id, armadio, scenario: scenarioDaApp(v), geo: r.geo, meteo: r.meteo, prompt: r.diagnostica.prompt,
    raw: r.diagnostica.testo, jev: { ...r.diagnostica.jev, profili_nuovi: undefined }, valigia: s,
    motivi: r.motivi, perche: r.perche, uso: r.uso, ms });
}
writeFileSync(process.argv[2], JSON.stringify(out));
