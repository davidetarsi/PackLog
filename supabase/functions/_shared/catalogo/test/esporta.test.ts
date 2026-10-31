// esporta_catalogo.mjs: un risultato vuoto, ridotto o senza domini non
// sostituisce il file canonico (revisione finale, I4).
// Uso: node --test _shared/catalogo/test/esporta.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
// @ts-ignore: modulo .mjs senza tipi
import { alFormatoFile, DOMINI_ESSENZIALI, problemiDelRisultato } from "../esporta_catalogo.mjs";

const precedente = JSON.parse(readFileSync(new URL("../catalogo.json", import.meta.url), "utf8")).entries;
const comeRighe = (voci: any[]) => voci.map((v) => ({ domain: v.domain, id: v.id, sort: v.sort, active: v.active,
  label_it: v.label.it, label_en: v.label.en, data: v.data }));

test("la tabella intera dello stato attuale va bene, e riproduce il file", () => {
  const righe = comeRighe(precedente);
  assert.deepEqual(problemiDelRisultato(righe, precedente), []);
  assert.equal(alFormatoFile(righe, precedente), readFileSync(new URL("../catalogo.json", import.meta.url), "utf8"));
});

test("un risultato vuoto si rifiuta sempre, anche con --accetta-meno", () => {
  assert.equal(problemiDelRisultato([], precedente).length, 1);
  assert.equal(problemiDelRisultato([], precedente, true).length, 1);
  assert.equal(problemiDelRisultato(null, precedente).length, 1);
});

test("meno voci del file precedente: rifiutato, salvo --accetta-meno", () => {
  const righe = comeRighe(precedente).filter((r) => !(r.domain === "activity" && r.id === "spa"));
  const problemi = problemiDelRisultato(righe, precedente);
  assert.equal(problemi.length, 1);
  assert.match(problemi[0], /meno delle/);
  assert.deepEqual(problemiDelRisultato(righe, precedente, true), []);
});

test("un dominio mancante: rifiutato, anche se le voci sono altrettante", () => {
  const senza = comeRighe(precedente).filter((r) => r.domain !== "color");
  const doppie = [...senza, ...comeRighe(precedente).filter((r) => r.domain === "use").map((r) => ({ ...r, id: r.id + "2" }))];
  const problemi = problemiDelRisultato(doppie, precedente);
  assert.ok(problemi.some((p) => p.includes("domini mancanti: color")), problemi.join("|"));
  assert.deepEqual(problemiDelRisultato(doppie, precedente, true), []);
});

test("i domini essenziali valgono anche con un file precedente piccolo", () => {
  const righe = [{ domain: "use", id: "x", sort: 1, active: true, label_it: "x", label_en: "x", data: {} }];
  const problemi = problemiDelRisultato(righe, []);
  for (const d of DOMINI_ESSENZIALI.filter((d: string) => d !== "use")) assert.ok(problemi[0].includes(d), d);
});

test("lo script non scrive nulla se il risultato e' vuoto (server finto)", async () => {
  const { createServer } = await import("node:http");
  const { execFile } = await import("node:child_process");
  const { mkdtempSync, copyFileSync, rmSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const server = createServer((_, res) => { res.setHeader("content-type", "application/json"); res.end("[]"); });
  await new Promise<void>((ok) => server.listen(0, "127.0.0.1", ok));
  const porta = (server.address() as any).port;
  const dir = mkdtempSync(`${tmpdir()}/esporta-`);
  copyFileSync(new URL("../esporta_catalogo.mjs", import.meta.url), `${dir}/esporta_catalogo.mjs`);
  copyFileSync(new URL("../catalogo.json", import.meta.url), `${dir}/catalogo.json`);
  const prima = readFileSync(`${dir}/catalogo.json`, "utf8");
  const esito = await new Promise<{ codice: number | null; err: string }>((ok) => {
    execFile(process.execPath, [`${dir}/esporta_catalogo.mjs`, "--accetta-meno"], {
      env: { ...process.env, CATALOGO_URL: `http://127.0.0.1:${porta}`, CATALOGO_KEY: "chiave-finta" },
    }, (e, _o, err) => ok({ codice: e ? (e as any).code : 0, err }));
  });
  server.close();
  const dopo = readFileSync(`${dir}/catalogo.json`, "utf8");
  rmSync(dir, { recursive: true, force: true });
  assert.equal(esito.codice, 1);
  assert.match(esito.err, /export rifiutato/);
  assert.equal(dopo, prima);
});
