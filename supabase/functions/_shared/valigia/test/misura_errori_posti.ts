// Conta gli errori dei suggerimenti sulle celle del bench (regole_posti.ts), con armadio vuoto e a meta'.
// Non e' un test: stampa la tabella delle violazioni, con qualche esempio.
// Uso: node test/misura_errori_posti.ts ORACOLO.json [--esempi N]
import { caricaCelle, rigiocaCella, violazioni } from "./regole_posti.ts";

const file = process.argv[2];
if (!file || file.startsWith("-")) {
  console.error("uso: node test/misura_errori_posti.ts ORACOLO.json [--esempi N]");
  process.exit(2);
}
const iEsempi = process.argv.indexOf("--esempi");
const nEsempi = iEsempi > 0 ? Number(process.argv[iEsempi + 1]) : 2;
const celle = caricaCelle(file);
for (const armadio of ["vuoto", "medio"] as const) {
  const conti = new Map<string, { n: number; esempi: string[] }>();
  let errori = 0;
  for (const c of celle) {
    try {
      const r = rigiocaCella(c, armadio);
      for (const v of violazioni(r)) {
        const voce = conti.get(v.regola) ?? { n: 0, esempi: [] };
        voce.n++;
        if (voce.esempi.length < nEsempi) voce.esempi.push(`${r.id}: ${v.posto}`);
        conti.set(v.regola, voce);
      }
    } catch (e) {
      errori++;
      console.error(`${c.insieme}/${c.id}/${c.armadio}: ERRORE ${(e as Error).message}`);
    }
  }
  console.log(`\nArmadio ${armadio}: ${celle.length} celle (v4 escluso), ${errori} con errore`);
  if (!conti.size) console.log("  nessuna violazione");
  for (const [regola, v] of [...conti].sort((a, b) => b[1].n - a[1].n)) {
    console.log(`${String(v.n).padStart(5)}  ${regola}${v.esempi.length ? "   es: " + v.esempi.join(" | ") : ""}`);
  }
}
