// Rigioca nel porting le valigie registrate dal bench (esporta_oracolo.py celle)
// e le confronta con la valigia del Python, campo per campo.
// Uso: node test/confronta_celle.ts [ORACOLO.json] [-v]
import { readFileSync } from "node:fs";
import { caricaArmadio, type Capo, type RigaArmadio } from "../capo.ts";
import { strategySlots } from "../slots.ts";
import { strategySlotsMultitappa } from "../tappe.ts";

const file = process.argv[2] && !process.argv[2].startsWith("-")
  ? process.argv[2] : new URL("./oracolo_celle_campione.json", import.meta.url).pathname;
const verboso = process.argv.includes("-v");
const casi: any[] = JSON.parse(readFileSync(file, "utf8"));
const righe: Record<string, RigaArmadio[]> = {};
for (const c of JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"))) {
  if (c.f === "carica_armadio") righe[c.nome + ".json"] = c.args[0];
}

function prima(a: unknown, b: unknown, via = ""): string | null {
  if (JSON.stringify(a) === JSON.stringify(b)) return null;
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return `${via}: lunghezza ${a.length} invece di ${b.length}`;
    for (let i = 0; i < a.length; i++) { const d = prima(a[i], b[i], `${via}[${i}]`); if (d) return d; }
  }
  if (a && b && typeof a === "object" && typeof b === "object" && !Array.isArray(a)) {
    const ka = Object.keys(a as object), kb = Object.keys(b as object);
    for (const k of new Set([...ka, ...kb])) {
      const d = prima((a as any)[k], (b as any)[k], `${via}.${k}`);
      if (d) return d;
    }
    if (ka.join() !== kb.join()) return `${via}: ordine delle chiavi ${ka} invece di ${kb}`;
  }
  return `${via}: ${JSON.stringify(a)?.slice(0, 160)} invece di ${JSON.stringify(b)?.slice(0, 160)}`;
}

function normalizzaNumeri(x: unknown): unknown {
  return JSON.parse(JSON.stringify(x), (_k, v) => typeof v === "string" ? v.replace(/(\d)\.0\b/g, "$1") : v);
}

let ok = 0, ko = 0;
const perTipo: Record<string, [number, number]> = { singola: [0, 0], tappe: [0, 0] };
const perCampo: Record<string, number> = {};
const esempi: string[] = [];
for (const c of casi) {
  perTipo[c.tipo][1]++;
  const items: Capo[] = caricaArmadio(righe[c.armadio]);
  let out: unknown;
  try {
    const r = c.tipo === "singola" ? strategySlots(c.grezzo, items, c.args)
      : strategySlotsMultitappa(c.grezzo, items, structuredClone(c.args));
    out = JSON.parse(JSON.stringify(r));
  } catch (e) {
    ko++; perCampo["(errore)"] = (perCampo["(errore)"] ?? 0) + 1;
    if (esempi.length < 8) esempi.push(`${c.insieme}/${c.armadio}/${c.id}: ERRORE ${(e as Error).stack?.split("\n").slice(0, 3).join(" | ")}`);
    continue;
  }
  // I numeri interi del meteo: Python scrive 2 o 2.0 secondo da dove viene il
  // dato (previsione o clima storico), il JSON letto non lo distingue piu'.
  // Nei testi interni (reason) "2.0" e "2" valgono uguale.
  const d = prima(normalizzaNumeri(out), normalizzaNumeri(c.atteso));
  if (d == null) { ok++; perTipo[c.tipo][0]++; continue; }
  ko++;
  const campo = d.split(/[.:[]/)[1] ?? d;
  perCampo[campo] = (perCampo[campo] ?? 0) + 1;
  if (esempi.length < (verboso ? 40 : 8)) esempi.push(`${c.insieme}/${c.armadio}/${c.id}: ${d}`);
}
console.log(`valigie: ${ok} identiche, ${ko} diverse; a una destinazione ${perTipo.singola[0]}/${perTipo.singola[1]}, a tappe ${perTipo.tappe[0]}/${perTipo.tappe[1]}`);
console.log("prima differenza per campo:", perCampo);
for (const e of esempi) console.log("  " + e);
process.exitCode = ko ? 1 : 0;
