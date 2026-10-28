// Il giro intero (genera.ts) con modello, Jev e meteo finti che rispondono come
// nel bench: stesso prompt, stessa valigia, stessi motivi.
// Uso: node --test test/genera.test.ts   (ORACOLO_CELLE=file per l'oracolo intero)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import type { RigaArmadio } from "../capo.ts";
import { type ChiediJev, DOMANDA_SCARPE } from "../jev.ts";
import { generaValigia, scenarioDaApp } from "../genera.ts";

const file = process.env.ORACOLO_CELLE ?? new URL("./oracolo_celle_campione.json", import.meta.url).pathname;
const casi: any[] = JSON.parse(readFileSync(file, "utf8"));
const righe: Record<string, RigaArmadio[]> = {};
for (const c of JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"))) {
  if (c.f === "carica_armadio") righe[c.nome + ".json"] = c.args[0];
}
const numeri = (x: unknown) =>
  JSON.parse(JSON.stringify(x), (_k, v) => typeof v === "string" ? v.replace(/(\d)\.0\b/g, "$1") : v);

function jevCome(a: any): ChiediJev {
  return async (stato, domande) => {
    if ("culto" in domande) {
      if (!a.classi_viaggio) throw new Error("niente");
      return { answers: Object.fromEntries(Object.entries(a.classi_viaggio).map(([q, v]: [string, any]) =>
        [q, v != null && typeof v === "object" ? { type: "choice", choice: v.scelta, probabilities: v.probabilita }
          : { type: "noul", noul: v }])) };
    }
    const prima = Object.values(domande)[0] as any;
    if (typeof prima.instructions === "string") throw new Error("profilo: dai profili noti");
    const voti = (prima.instructions.question === DOMANDA_SCARPE ? a.voti_scarpe : a.scarti_capi) ?? {};
    return { answers: Object.fromEntries(Object.keys(domande).filter((id) => voti[id] != null)
      .map((id) => [id, { noul: voti[id] }])) };
  };
}

test("stesso prompt, stessa valigia, stessi motivi del bench", async () => {
  let n = 0;
  for (const c of casi) {
    const { scenario, geo, meteo } = structuredClone(c.viaggio);
    const nome = `${c.insieme}/${c.armadio}/${c.id}`;
    // i profili noti arrivano dalla tabella: qui dagli argomenti registrati
    const { caricaArmadio } = await import("../capo.ts");
    const { scheda } = await import("../jev.ts");
    const items = caricaArmadio(righe[c.armadio]);
    const profiliNoti = Object.fromEntries(Object.entries(c.args.profili_capi ?? {}).map(([id, r]) =>
      [id, { scheda: JSON.stringify(scheda(items.find((g) => g.id === id)!)), risposte: r as any }]));
    const r = await generaValigia(scenario, righe[c.armadio], {
      clima: async () => ({ geo, meteo }),
      modello: async (p) => { assert.equal(p, c.prompt[0], nome); return { testo: c.grezzo }; },
      jev: jevCome(c.args),
      profiliNoti,
    });
    assert.deepEqual(numeri(r.valigia), numeri(c.atteso), nome);
    // nei testi interni (reason) "2.0" e "2" valgono uguale, come in confronta_celle
    assert.deepEqual(numeri(r.motivi), numeri(c.motivi), nome);
    assert.deepEqual(JSON.parse(JSON.stringify(r.perche)), c.perche, nome);
    n++;
  }
  assert.ok(n > 0);
});

test("scenario dall'app nella forma del bench", () => {
  assert.deepEqual(scenarioDaApp({
    data_inizio: "2027-02-20", giorni: 9, attivita: [], bagaglio: "valigia grande", alloggio: "hotel",
    lavatrice: false, tappe: [{ nome: "Reykjavik", lat: 64.1, lon: -21.9, giorni: 5, attivita: ["terme"] },
      { nome: "Amsterdam", lat: 52.4, lon: 4.9, giorni: 4 }],
  }), { data_inizio: "2027-02-20", giorni: 9, attivita: [], bagaglio: "valigia grande", alloggio: "hotel",
    lavatrice: false, legs: [{ destinazione: "Reykjavik", giorni: 5, attivita: ["terme"] },
      { destinazione: "Amsterdam", giorni: 4, attivita: [] }] });
  assert.deepEqual(scenarioDaApp({ data_inizio: "2026-09-15", giorni: 5, attivita: ["trekking"],
    destinazione: { nome: "Cortina d'Ampezzo", paese: "Italia", lat: 46.5, lon: 12.1 } }),
  { data_inizio: "2026-09-15", giorni: 5, attivita: ["trekking"], bagaglio: "", alloggio: "", lavatrice: false,
    destinazione: "Cortina d'Ampezzo", paese: "Italia" });
});
