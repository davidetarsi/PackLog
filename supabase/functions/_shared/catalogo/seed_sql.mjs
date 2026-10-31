// Le righe del catalogo come INSERT SQL, da catalogo.json, sempre nello stesso
// ordine: e' il seed della migrazione del catalogo.
// Uso: node seed_sql.mjs > seed.sql
import { readFileSync } from "node:fs";

const { entries } = JSON.parse(readFileSync(new URL("catalogo.json", import.meta.url), "utf8"));
const testo = (s) => `'${String(s).replaceAll("'", "''")}'`;
const righe = entries.map((e) =>
  `  (${[testo(e.domain), testo(e.id), e.sort, e.active, testo(e.label.it), testo(e.label.en),
    `${testo(JSON.stringify(e.data))}::jsonb`].join(", ")})`);
process.stdout.write(
  "INSERT INTO public.catalog_entries (domain, id, sort, active, label_it, label_en, data) VALUES\n" +
  righe.join(",\n") + "\nON CONFLICT (domain, id) DO NOTHING;\n");
