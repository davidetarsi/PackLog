// Il file canonico del catalogo (catalogo.json): forma, e valori uguali a
// quelli di oggi della tassonomia e della scheda dei capi.
// Uso: node --test test/catalogo.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as tassonomia from "../../valigia/tassonomia.ts";
import * as scheda from "../../capi/scheda.ts";

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
