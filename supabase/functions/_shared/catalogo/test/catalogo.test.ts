// Il file canonico del catalogo (catalogo.json): forma, e valori uguali a
// quelli di oggi della tassonomia e della scheda dei capi.
// Uso: node --test test/catalogo.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as tassonomia from "../../valigia/tassonomia.ts";
import * as scheda from "../../capi/scheda.ts";
import { azzeraCache, CATALOGO_BASE, CONTROLLO_MS, leggiCatalogo, testiAttivita, testoAlloggio, voci as vociDi }
  from "../catalogo.ts";

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
    if (t.id === tassonomia.ALTRO) assert.equal(t.data.everyGroup, true);
    else assert.ok(gruppi.has(t.data.group), `gruppo di ${t.id}`);
  }
  for (const a of dominio("activity")) {
    assert.ok(Array.isArray(a.data.generator) && a.data.generator.length > 0, a.id);
  }
  for (const s of dominio("stay")) assert.equal(typeof s.data.generator, "string", s.id);
});

test("i valori degli oggetti sono quelli di oggi", () => {
  assert.deepEqual(dominio("clothing_group").map((v) => v.id), tassonomia.CATEGORIE);
  for (const c of tassonomia.CATEGORIE) {
    const tipi = dominio("clothing_type").filter((t) => t.data.group === c).map((t) => t.id);
    assert.deepEqual([...tipi, tassonomia.ALTRO], tassonomia.SOTTOCATEGORIE[c], c);
  }
  for (const t of dominio("clothing_type")) {
    if (t.id === tassonomia.ALTRO) continue;
    assert.equal(t.data.parent, tassonomia.GENITORE[t.id] ?? null, t.id);
    assert.equal(t.data.hint, tassonomia.NUOVE[t.id]?.[2] || tassonomia.SPIEGA_VECCHIE[t.id] || null, t.id);
  }
  assert.deepEqual(dominio("use").map((v) => v.id), scheda.TAG);
  assert.deepEqual(dominio("formality").map((v) => v.id), scheda.FORMALITA);
  assert.deepEqual(dominio("color").map((v) => v.id), scheda.COLORI);
  const sinonimi = Object.fromEntries(dominio("color").flatMap((c) => c.data.synonyms.map((s: string) => [s, c.id])));
  assert.deepEqual(sinonimi, scheda.SINONIMI_COLORE);
  assert.deepEqual(dominio("warmth").map((v) => v.id), ["1", "2", "3", "4", "5"]);
  assert.deepEqual(dominio("water").map((v) => v.id), ["0", "1", "2"]);
});

test("attivita': quelle decise il 31 ottobre, con le voci tolte disattivate", () => {
  const a = dominio("activity");
  assert.deepEqual(a.filter((v) => v.active).map((v) => v.id),
    ["city", "walks", "trekking", "cammino", "sea", "diving", "ski", "camping", "work", "evenings", "wedding",
      "worship", "spa"]);
  assert.deepEqual(a.filter((v) => !v.active).map((v) => v.id), ["high_mountain", "formal_dinner", "nightlife", "cycling"]);
  const testi = Object.fromEntries(a.map((v) => [v.id, v.data.generator]));
  assert.deepEqual(testi.evenings, ["cene al ristorante", "vita notturna"]);
  assert.deepEqual(testi.work, ["riunioni di lavoro", "cene di lavoro"]);
  assert.deepEqual(testi.wedding, ["matrimonio", "cerimonia"]);
  assert.deepEqual(testi.walks, ["escursioni leggere"]);
  assert.deepEqual(testi.high_mountain, ["escursioni in quota"]);
  assert.deepEqual(dominio("stay").map((v) => [v.id, v.data.generator]),
    [["hotel", "hotel"], ["apartment", "appartamento"], ["hostel", "ostello"], ["camping", "campeggio"],
      ["friends", "da amici o parenti"]]);
});

test("la migrazione contiene il seed di catalogo.json", async () => {
  const { execFileSync } = await import("node:child_process");
  const seed = execFileSync(process.execPath, [new URL("../seed_sql.mjs", import.meta.url).pathname], { encoding: "utf8" });
  const migrazione = readFileSync(
    new URL("../../../../migrations/20261101090000_catalogo.sql", import.meta.url), "utf8");
  assert.ok(migrazione.includes(seed), "seed diverso: rigenera con node seed_sql.mjs");
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

test("attivita' e alloggi: dagli id ai testi, i testi vecchi restano", () => {
  assert.deepEqual(testiAttivita(CATALOGO_BASE, ["evenings", "visite in citta"]),
    ["cene al ristorante", "vita notturna", "visite in citta"]);
  assert.deepEqual(testiAttivita(CATALOGO_BASE, ["diving", "sea"]), ["immersioni", "mare"]);
  assert.deepEqual(testiAttivita(CATALOGO_BASE, ["formal_dinner"]), ["cena formale"]);
  assert.equal(testoAlloggio(CATALOGO_BASE, "friends"), "da amici o parenti");
  assert.equal(testoAlloggio(CATALOGO_BASE, "hotel di lusso"), "hotel di lusso");
  assert.equal(testoAlloggio(CATALOGO_BASE, null), null);
  assert.deepEqual(vociDi(CATALOGO_BASE, "activity").map((v) => v.id).includes("cycling"), false);
  assert.deepEqual(vociDi(CATALOGO_BASE, "activity", false).map((v) => v.id).includes("cycling"), true);
});
