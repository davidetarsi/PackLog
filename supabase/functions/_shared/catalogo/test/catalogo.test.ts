// Il file canonico del catalogo (catalogo.json): FORMA (id unici, etichette
// piene, gruppi validi), seed della migrazione e lettura nelle funzioni. Questi
// test non dipendono dal contenuto: non si toccano quando si cambia una voce.
// Il contenuto fissato al 31 ottobre sta in catalogo_parita.test.ts.
// Uso: node --test test/catalogo.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { azzeraCache, CATALOGO_BASE, CONTROLLO_MS, leggiCatalogo, testiAttivita, testoAlloggio, voci as vociDi }
  from "../catalogo.ts";
import type { Catalogo } from "../catalogo.ts";

type Voce = { domain: string; id: string; sort: number; active: boolean; label: { it: string; en: string };
  data: Record<string, any> };
const voci: Voce[] = JSON.parse(readFileSync(new URL("../catalogo.json", import.meta.url), "utf8")).entries;
const dominio = (d: string) => voci.filter((v) => v.domain === d).sort((a, b) => a.sort - b.sort);

test("forma: id unici per dominio, etichette piene, gruppi e testi validi", () => {
  const visti = new Set<string>();
  for (const v of voci) {
    const k = `${v.domain}|${v.id}`;
    assert.ok(!visti.has(k), `doppione ${k}`);
    visti.add(k);
    assert.ok(v.label.it.trim() && v.label.en.trim(), `etichetta vuota ${k}`);
    assert.equal(typeof v.active, "boolean", k);
    assert.ok(Number.isInteger(v.sort), k);
  }
  const gruppi = new Set(dominio("clothing_group").map((v) => v.id));
  for (const t of dominio("clothing_type")) {
    if (t.id === "Other") assert.equal(t.data.everyGroup, true);
    else assert.ok(gruppi.has(t.data.group), `gruppo di ${t.id}`);
  }
  for (const a of dominio("activity")) {
    assert.ok(Array.isArray(a.data.generator) && a.data.generator.length > 0, a.id);
  }
  for (const s of dominio("stay")) assert.equal(typeof s.data.generator, "string", s.id);
});

// Il seed della migrazione e' SOLO INIZIALE: fotografa il catalogo del 31 ottobre
// (catalogo_seed_iniziale.json, congelato) e non segue catalogo.json. Dopo la
// prima migrazione i cambi si fanno nella tabella (mai con migrazioni nuove) e
// catalogo.json si riallinea con esporta_catalogo.mjs. Questo file non si modifica.
test("la migrazione contiene il seed iniziale (catalogo_seed_iniziale.json)", async () => {
  const { execFileSync } = await import("node:child_process");
  const seed = execFileSync(process.execPath, [new URL("../seed_sql.mjs", import.meta.url).pathname], { encoding: "utf8" });
  const migrazione = readFileSync(
    new URL("../../../../migrations/20261101090000_catalogo.sql", import.meta.url), "utf8");
  assert.ok(migrazione.includes(seed),
    "la migrazione non contiene il seed di catalogo_seed_iniziale.json: la migrazione gia' applicata non si cambia");
});

test("catalogo.json ha tutte le voci del seed iniziale (si disattiva, non si toglie)", () => {
  const iniziale: Voce[] = JSON.parse(
    readFileSync(new URL("../catalogo_seed_iniziale.json", import.meta.url), "utf8")).entries;
  const attuali = new Set(voci.map((v) => `${v.domain}|${v.id}`));
  for (const v of iniziale) assert.ok(attuali.has(`${v.domain}|${v.id}`), `${v.domain}|${v.id} tolta: si disattiva`);
});

// ── Lettura nelle funzioni ───────────────────────────────────────────────────

/** Un database finto: conta le letture; [versione] e [righe] si cambiano. */
function dbFinto(stato: { versione: string; righe: Record<string, any>[]; rotto?: boolean }) {
  const letture = { versione: 0, righe: 0 };
  const risposta = (dati: unknown) => stato.rotto ? { data: null, error: { message: "giu'" } } : { data: dati, error: null };
  return {
    letture,
    from(tabella: string) {
      return {
        select() {
          if (tabella === "catalog_entries") {
            letture.righe++;
            return Promise.resolve(risposta(stato.righe));
          }
          return { eq: () => ({ maybeSingle: () => { letture.versione++; return Promise.resolve(risposta({ value: stato.versione })); } }) };
        },
      };
    },
  };
}
const riga = (v: Voce) => ({ domain: v.domain, id: v.id, sort: v.sort, active: v.active, label_it: v.label.it,
  label_en: v.label.en, data: v.data });

test("cache: una lettura all'avvio, poi niente per un'ora; righe solo se la versione cambia", async () => {
  azzeraCache();
  const stato = { versione: "1", righe: voci.map(riga) };
  const db = dbFinto(stato);
  const t0 = 1_000_000;
  const c1 = await leggiCatalogo(db, t0);
  assert.equal(c1.voci.length, voci.length);
  assert.deepEqual(db.letture, { versione: 1, righe: 1 });
  await leggiCatalogo(db, t0 + CONTROLLO_MS - 1);
  assert.deepEqual(db.letture, { versione: 1, righe: 1 });
  await leggiCatalogo(db, t0 + CONTROLLO_MS);
  assert.deepEqual(db.letture, { versione: 2, righe: 1 }, "versione uguale: righe non rilette");
  stato.versione = "2";
  stato.righe = [...voci.map(riga), { domain: "use", id: "Party", sort: 90, active: true, label_it: "Festa",
    label_en: "Party", data: {} }];
  const c3 = await leggiCatalogo(db, t0 + 2 * CONTROLLO_MS);
  assert.deepEqual(db.letture, { versione: 3, righe: 2 });
  assert.ok(vociDi(c3, "use").some((v) => v.id === "Party"));
});

test("database che non risponde: la copia nel repo, e non si riprova a ogni richiesta", async () => {
  azzeraCache();
  const db = dbFinto({ versione: "1", righe: [], rotto: true });
  assert.equal(await leggiCatalogo(db, 0), CATALOGO_BASE);
  await leggiCatalogo(db, 1000);
  assert.deepEqual(db.letture, { versione: 1, righe: 0 });
});

test("attivita' e alloggi: dagli id ai testi, i testi vecchi restano (catalogo scritto qui)", () => {
  const c: Catalogo = { voci: [
    { domain: "activity", id: "uno", sort: 1, active: true, label: { it: "Uno", en: "One" }, data: { generator: ["a", "b"] } },
    { domain: "activity", id: "due", sort: 2, active: false, label: { it: "Due", en: "Two" }, data: { generator: ["b", "c"] } },
    { domain: "stay", id: "casa", sort: 1, active: true, label: { it: "Casa", en: "Home" }, data: { generator: "a casa" } },
  ] };
  assert.deepEqual(testiAttivita(c, ["uno", "libero"]), ["a", "b", "libero"]);
  assert.deepEqual(testiAttivita(c, ["due", "uno"]), ["b", "c", "a"], "disattivata si traduce, senza doppioni");
  assert.equal(testoAlloggio(c, "casa"), "a casa");
  assert.equal(testoAlloggio(c, "hotel di lusso"), "hotel di lusso");
  assert.equal(testoAlloggio(c, null), null);
  assert.deepEqual(vociDi(c, "activity").map((v) => v.id), ["uno"]);
  assert.deepEqual(vociDi(c, "activity", false).map((v) => v.id), ["uno", "due"]);
});
