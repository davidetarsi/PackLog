// Strati 5 e 6: prompt mandato al modello, motivi e scheda "Perche' queste
// scelte", confrontati con quelli del bench (esporta_oracolo.py celle).
// Uso: node test/confronta_motivi.ts [ORACOLO.json]
import { readFileSync } from "node:fs";
import type { RigaArmadio } from "../capo.ts";
import { motiviValigia, percheValigia, tagArmadio } from "../motivi.ts";
import { promptValigia } from "../prompt.ts";

const file = process.argv[2] ?? new URL("./oracolo_celle_campione.json", import.meta.url).pathname;
const casi: any[] = JSON.parse(readFileSync(file, "utf8"));
const tag: Record<string, Record<string, string[]>> = {};
for (const c of JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"))) {
  if (c.f === "carica_armadio") tag[c.nome + ".json"] = tagArmadio(c.args[0] as RigaArmadio[]);
}

function prima(a: unknown, b: unknown, via = ""): string | null {
  if (JSON.stringify(a) === JSON.stringify(b)) return null;
  if (Array.isArray(a) && Array.isArray(b) && a.length === b.length) {
    for (let i = 0; i < a.length; i++) { const d = prima(a[i], b[i], `${via}[${i}]`); if (d) return d; }
  }
  if (a && b && typeof a === "object" && typeof b === "object" && !Array.isArray(a)) {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      const d = prima((a as any)[k], (b as any)[k], `${via}.${k}`);
      if (d) return d;
    }
  }
  return `${via}: ${JSON.stringify(a)?.slice(0, 200)} invece di ${JSON.stringify(b)?.slice(0, 200)}`;
}

function primaRiga(a: string, b: string): string {
  const ra = a.split("\n"), rb = b.split("\n");
  for (let i = 0; i < Math.max(ra.length, rb.length); i++) {
    if (ra[i] !== rb[i]) return `riga ${i + 1}: ${JSON.stringify(ra[i])} invece di ${JSON.stringify(rb[i])}`;
  }
  return "?";
}

const conti = { prompt: 0, motivi: 0, perche: 0 };
const esempi: string[] = [];
for (const c of casi) {
  const { scenario, geo, meteo } = c.viaggio;
  const nome = `${c.insieme}/${c.armadio}/${c.id}`;
  const p = promptValigia(structuredClone(scenario), structuredClone(geo), structuredClone(meteo));
  if (p === c.prompt[0]) conti.prompt++;
  else if (esempi.length < 10) esempi.push(`${nome} prompt ${primaRiga(p, c.prompt[0])}`);
  const v = { scenario, meteo, slots: c.atteso };
  const m = JSON.parse(JSON.stringify(motiviValigia(v, tag[c.armadio])));
  const d = prima(m, c.motivi);
  if (!d) conti.motivi++;
  else if (esempi.length < 10) esempi.push(`${nome} motivi${d}`);
  const s = JSON.parse(JSON.stringify(percheValigia(v, tag[c.armadio])));
  const e = prima(s, c.perche);
  if (!e) conti.perche++;
  else if (esempi.length < 10) esempi.push(`${nome} perche${e}`);
}
console.log(`su ${casi.length} valigie identiche: prompt ${conti.prompt}, motivi ${conti.motivi}, scheda ${conti.perche}`);
for (const e of esempi) console.log("  " + e);
process.exitCode = conti.prompt === casi.length && conti.motivi === casi.length && conti.perche === casi.length ? 0 : 1;
