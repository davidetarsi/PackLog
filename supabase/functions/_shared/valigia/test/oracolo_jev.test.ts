// Jev nel porting contro il bench (esporta_oracolo.py jev): domande, scheda dei
// capi, viaggio come lo vede Jev e argomenti per il matcher, con un Jev finto
// che risponde come le cache del bench.
// Uso: node --test test/oracolo_jev.test.ts   (ORACOLO_JEV=file per l'oracolo intero)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { CATEGORIE_CAPI, type ChiediJev, datiJev, DOMANDA_CAPI, DOMANDA_SCARPE, DOMANDE_CLASSI, DOMANDE_PROFILO,
  ENDPOINT, MODELLO, scheda, statoViaggio } from "../jev.ts";

const file = process.env.ORACOLO_JEV ?? new URL("./oracolo_jev_campione.json", import.meta.url).pathname;
const o = JSON.parse(readFileSync(file, "utf8"));
const righe: Record<string, RigaArmadio[]> = {};
for (const c of JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"))) {
  if (c.f === "carica_armadio") righe[c.nome + ".json"] = c.args[0];
}

test("domande identiche al bench", () => {
  assert.deepEqual(DOMANDE_PROFILO, o.domande.profilo);
  assert.equal(DOMANDA_SCARPE, o.domande.scarpe);
  assert.equal(DOMANDA_CAPI, o.domande.capi);
  assert.deepEqual(CATEGORIE_CAPI, o.domande.categorie_capi);
  assert.deepEqual(DOMANDE_CLASSI, o.domande.classi);
  assert.equal(MODELLO, o.domande.modello);
  assert.equal(ENDPOINT, o.domande.endpoint);
});

test("scheda di ogni capo", () => {
  for (const [nome, attese] of Object.entries(o.armadi) as [string, any[]][]) {
    const items = caricaArmadio(righe[nome]);
    assert.deepEqual(items.map((g) => ({ id: g.id, scheda: scheda(g) })), attese, nome);
  }
});

test("viaggio come lo vede Jev e argomenti per il matcher", async () => {
  for (const c of o.celle) {
    const { scenario, geo, meteo } = c.viaggio;
    const nome = `${c.insieme}/${c.armadio}/${c.id}`;
    assert.deepEqual(statoViaggio(scenario, geo, meteo), c.stato, nome);
    const items = caricaArmadio(righe[c.armadio]);
    const prof = c.atteso.profili_capi ?? {};
    const finto: ChiediJev = async (stato, domande) => {
      if ("culto" in domande) {
        assert.deepEqual(stato, c.stato);
        if (!c.risposte.classi) throw new Error("niente in cache");
        return { answers: Object.fromEntries(Object.entries(c.risposte.classi).map(([q, v]: [string, any]) =>
          [q, v != null && typeof v === "object" ? { type: "choice", choice: v.scelta, probabilities: v.probabilita }
            : { type: "noul", noul: v }])) };
      }
      const prima = Object.values(domande)[0] as any;
      if (typeof prima.instructions === "string") {        // profilo: lo stato e' la scheda
        const g = items.find((x) => JSON.stringify(scheda(x)) === JSON.stringify(stato))!;
        if (!(g.id in prof)) throw new Error("niente in cache");
        return { answers: Object.fromEntries(Object.entries(prof[g.id]).map(([q, v]) => [q, { noul: v }])) };
      }
      const voti = prima.instructions.question === DOMANDA_SCARPE ? c.risposte.scarpe : c.risposte.capi;
      return { answers: Object.fromEntries(Object.keys(domande).filter((id) => voti[id] != null)
        .map((id) => [id, { noul: voti[id] }])) };
    };
    const d = await datiJev(scenario, geo, meteo, items, finto);
    for (const k of ["voti_scarpe", "profili_capi", "scarti_capi", "classi_viaggio"]) {
      assert.deepEqual((d as any)[k] ?? null, c.atteso[k] ?? null, `${nome} ${k}`);
    }
  }
});
