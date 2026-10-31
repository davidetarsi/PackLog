// Riallinea catalogo.json alla tabella catalog_entries (spec del 31 ottobre
// 2026, § 6.2): Davide modifica le righe dalla dashboard, il trigger alza la
// versione, e questo script riporta le righe nel file del repo.
//
// Uso (la chiave la passa chi lancia lo script; lo script non legge file di
// credenziali):
//   CATALOGO_URL=https://<progetto>.supabase.co CATALOGO_KEY=<chiave> \
//     node esporta_catalogo.mjs [--bench CARTELLA_DEL_BENCH]
//
// Scrive catalogo.json accanto a questo file e, con --bench, la sua copia nel
// bench (che deve restare identica: l'oracolo scheda la controlla con sha256).
// Non cambia l'ordine delle voci già presenti, così il diff mostra solo i cambi.
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";

const qui = new URL(".", import.meta.url);

/** Le righe di catalog_entries nel formato del file del repo, nell'ordine di
 *  [precedente] per le voci già presenti, poi le nuove nell'ordine della tabella. */
export function alFormatoFile(righe, precedente = []) {
  const chiave = (v) => `${v.domain}\u0000${v.id}`;
  const posto = new Map(precedente.map((v, i) => [chiave(v), i]));
  const voci = righe.map((r) => ({
    domain: r.domain,
    id: r.id,
    sort: Number(r.sort),
    active: r.active !== false,
    label: { it: r.label_it, en: r.label_en },
    data: r.data ?? {},
  }));
  voci.sort((a, b) => {
    const pa = posto.get(chiave(a)), pb = posto.get(chiave(b));
    if (pa !== undefined && pb !== undefined) return pa - pb;
    if (pa !== undefined) return -1;
    if (pb !== undefined) return 1;
    return a.sort - b.sort;
  });
  return JSON.stringify({ entries: voci }, null, 2) + "\n";
}

/** Le righe di catalog_entries con la chiave data (solo lettura). */
async function leggiRighe(url, chiave) {
  const campi = "domain,id,sort,active,label_it,label_en,data";
  const risposta = await fetch(
    `${url}/rest/v1/catalog_entries?select=${campi}&order=domain,sort`,
    { headers: { apikey: chiave, authorization: `Bearer ${chiave}` } },
  );
  if (!risposta.ok) throw new Error(`lettura non riuscita: HTTP ${risposta.status}`);
  return risposta.json();
}

async function main() {
  const url = process.env.CATALOGO_URL;
  const chiave = process.env.CATALOGO_KEY;
  if (!url || !chiave) throw new Error("servono CATALOGO_URL e CATALOGO_KEY");
  const percorso = fileURLToPath(new URL("catalogo.json", qui));
  const precedente = JSON.parse(readFileSync(percorso, "utf8")).entries;
  const testo = alFormatoFile(await leggiRighe(url, chiave), precedente);
  writeFileSync(percorso, testo);
  const bench = process.argv.indexOf("--bench");
  if (bench > 0) writeFileSync(new URL(`${process.argv[bench + 1]}/catalogo.json`, `file://${process.cwd()}/`), testo);
  const sha = createHash("sha256").update(testo).digest("hex");
  console.log(`catalogo.json: ${JSON.parse(testo).entries.length} voci, sha256 ${sha}`);
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
