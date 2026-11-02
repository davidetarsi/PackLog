// Le righe del catalogo come INSERT SQL, sempre nello stesso ordine: e' il seed
// della migrazione del catalogo. Parte da catalogo_seed_iniziale.json, la
// fotografia congelata del 31 ottobre 2026 (non da catalogo.json, che segue la
// tabella): il seed della migrazione e' solo iniziale.
// Uso: node seed_sql.mjs [file.json] > seed.sql
import { readFileSync } from "node:fs";

const file = process.argv[2] ? new URL(process.argv[2], `file://${process.cwd()}/`) : new URL("catalogo_seed_iniziale.json", import.meta.url);
const { entries } = JSON.parse(readFileSync(file, "utf8"));
const testo = (s) => `'${String(s).replaceAll("'", "''")}'`;
const righe = entries.map((e) =>
  `  (${[testo(e.domain), testo(e.id), e.sort, e.active, testo(e.label.it), testo(e.label.en),
    `${testo(JSON.stringify(e.data))}::jsonb`].join(", ")})`);
process.stdout.write(
  "INSERT INTO public.catalog_entries (domain, id, sort, active, label_it, label_en, data) VALUES\n" +
  righe.join(",\n") + "\nON CONFLICT (domain, id) DO NOTHING;\n");
