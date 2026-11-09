// Cancello di qualita': le valigie dell'app, giudicate dal valutatore del bench.
//
// Un solo comando. Per le celle registrate del bench (stesse risposte del modello,
// stessi guardaroba, stesso clima) fa tre cose:
//   1. chiede al bench gli ingressi esatti di ogni cella (esporta_oracolo.py);
//   2. rigioca ogni cella con il generatore TypeScript dell'app e scrive le
//      valigie nel formato dei risultati del bench;
//   3. lancia packlog_accuracy.py con ogni insieme di asserzioni e stampa, per
//      insieme, le valigie corrette e le asserzioni fallite.
// Il v4 e' SIGILLATO: ne escono solo i totali (solo_aggregati.py), mai i viaggi.
//
// Uso:  node valuta_con_banco.ts [--banco CARTELLA] [--python PYTHON]
//         [--insiemi pool44,holdout30,v2,v3,v3m,v4,v4m] [--ripetizioni 1,2,3]
//         [--confronta CARTELLA_PRECEDENTE] [--salva CARTELLA] [--oracolo FILE]
// Il banco e' anche in PACKLOG_BANCO (default ../checklist-script-packlog rispetto
// alla radice del repo); l'interprete Python in PACKLOG_PYTHON (default
// <banco>/.venv/bin/python, altrimenti python3). Vedi VALUTA_CON_BANCO.md.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { strategySlots } from "../slots.ts";
import { strategySlotsMultitappa } from "../tappe.ts";

const SIGILLATI = new Set(["v4", "v4m"]);
const qui = fileURLToPath(new URL(".", import.meta.url));
const radice = resolve(qui, "../../../../..");

function opzione(nome: string, env?: string, def?: string): string | undefined {
  const i = process.argv.indexOf(`--${nome}`);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return (env ? process.env[env] : undefined) ?? def;
}

const banco = resolve(opzione("banco", "PACKLOG_BANCO", resolve(radice, "../checklist-script-packlog"))!);
if (!existsSync(join(banco, "packlog_accuracy.py"))) {
  console.error(`Banco non trovato in ${banco}: passa --banco o PACKLOG_BANCO.`);
  process.exit(2);
}
const python = opzione("python", "PACKLOG_PYTHON",
  existsSync(join(banco, ".venv/bin/python")) ? join(banco, ".venv/bin/python") : "python3")!;
const insiemi = (opzione("insiemi", undefined, "pool44,holdout30,v2,v3,v3m,v4,v4m")!).split(",");
const ripetizioni = (opzione("ripetizioni", undefined, "1,2,3")!).split(",").map(Number);
const precedente = opzione("confronta");
const salva = opzione("salva");

function esegui(cmd: string, args: string[], cwd = banco) {
  const r = spawnSync(cmd, args, { cwd, encoding: "utf8", maxBuffer: 1 << 30 });
  if (r.status !== 0) {
    console.error(`Errore in: ${cmd} ${args.slice(0, 3).join(" ")}\n${r.stderr.slice(-1500)}${r.stdout.slice(-500)}`);
    process.exit(2);
  }
  return r.stdout;
}

const lavoro = mkdtempSync(join(tmpdir(), "valuta-banco-"));
try {
  // 1. Gli ingressi del bench. Gli insiemi con le stesse celle e asserzioni diverse
  //    (v3/v3m, v4/v4m) condividono le valigie: si esporta una volta sola.
  const mappa = join(lavoro, "insiemi.json");
  const oracolo = opzione("oracolo") ?? join(lavoro, "oracolo.json");
  esegui(python, ["-c", `
import json, sys
sys.path.insert(0, ".")
import misura_sviluppo as ms
ins = ${JSON.stringify(insiemi)}
rip = ${JSON.stringify(ripetizioni)}
chiave = lambda n: (ms.INSIEMI[n]["prefisso"], tuple(ms.INSIEMI[n]["guardaroba"]), tuple(sorted(ms.INSIEMI[n]["rigenerati"])))
base = {}
for n in ins:
    base.setdefault(chiave(n), n)
mappa = {n: {"celle": base[chiave(n)], "asserzioni": ms.INSIEMI[n]["asserzioni"]} for n in ins}
json.dump(mappa, open(${JSON.stringify(mappa)}, "w"))
if ${opzione("oracolo") ? "False" : "True"}:
    import esporta_oracolo as eo
    celle = eo.casi_celle(insiemi=tuple(sorted(set(base.values()))), ripetizioni=tuple(rip), con_femminile=False)
    json.dump(celle, open(${JSON.stringify(oracolo)}, "w"), ensure_ascii=False)
`]);
  const insiemiMappa: Record<string, { celle: string; asserzioni: string }> = JSON.parse(readFileSync(mappa, "utf8"));

  // 2. Le valigie dell'app, nel formato dei risultati del bench.
  const righe: Record<string, RigaArmadio[]> = {};
  for (const c of JSON.parse(readFileSync(join(qui, "oracolo_quantita.json"), "utf8"))) {
    if (c.f === "carica_armadio") righe[c.nome + ".json"] = c.args[0];
  }
  const perFile: Record<string, any[]> = {};
  let errori = 0, celle = 0;
  for (const c of JSON.parse(readFileSync(oracolo, "utf8")) as any[]) {
    celle++;
    try {
      const items = caricaArmadio(righe[c.armadio]);
      const slots = JSON.parse(JSON.stringify(c.tipo === "singola"
        ? strategySlots(c.grezzo, items, c.args)
        : strategySlotsMultitappa(c.grezzo, items, structuredClone(c.args))));
      const k = `${c.insieme}__${c.armadio.replace(".json", "")}`;
      (perFile[k] ??= []).push({ ...c.viaggio, inventario: c.armadio, runs: { "gpt-4o-mini": { slots } } });
    } catch (e) {
      errori++;
      console.error(`ERRORE ${c.insieme}/${c.armadio}/${c.id}: ${(e as Error).message}`);
    }
  }
  const cartellaValigie = join(lavoro, "valigie");
  mkdirSync(cartellaValigie);
  for (const [k, v] of Object.entries(perFile)) writeFileSync(join(cartellaValigie, `${k}.json`), JSON.stringify(v));
  console.log(`Valigie dell'app: ${celle - errori}/${celle} celle rigiocate (banco: ${banco})\n`);
  if (errori) { console.error("Celle in errore: il cancello non e' valido."); process.exitCode = 1; }

  // 3. Il valutatore del bench, un insieme di asserzioni alla volta.
  const file = (cella: string) => readdirSync(cartellaValigie).filter((f) => f.startsWith(`${cella}__`))
    .map((f) => join(cartellaValigie, f));
  const uscita = salva ? resolve(salva) : null;
  if (uscita) mkdirSync(uscita, { recursive: true });
  const nuove: string[] = [];
  console.log("insieme      valigie corrette      asserzioni fallite");
  for (const nome of insiemi) {
    const { celle: cella, asserzioni } = insiemiMappa[nome];
    const files = file(cella);
    if (SIGILLATI.has(nome)) {
      // Solo i totali: mai le singole asserzioni o i viaggi.
      const out = esegui(python, ["holdout_v4/solo_aggregati.py", asserzioni, ...files]);
      const t = out.split("\n").find((l) => l.startsWith("totale"))?.match(/(\d+)\/(\d+)/);
      console.log(`${nome.padEnd(12)} ${t ? `${t[1]}/${t[2]}`.padEnd(21) : "?".padEnd(21)} (sigillato: solo il totale)`);
      continue;
    }
    const out = esegui(python, ["packlog_accuracy.py", "--model", "gpt-4o-mini", "--dettaglio",
      "--assertions", asserzioni, ...files]);
    const m = out.match(/gpt-4o-mini\s+(\d+)\s+(\d+)\s+[\d.]+%/);
    const fallite: string[] = [];
    let cellaCorrente = "";
    for (const l of out.slice(out.indexOf("FALLIMENTI NEL DETTAGLIO")).split("\n")) {
      const h = l.match(/^\s+gpt-4o-mini — (.+)$/);
      if (h) cellaCorrente = h[1];
      const f = l.match(/^\s+✗ (.+)$/);
      if (f) fallite.push(`${cellaCorrente} ✗ ${f[1]}`);
    }
    console.log(`${nome.padEnd(12)} ${m ? `${m[1]}/${m[2]}`.padEnd(21) : "?".padEnd(21)} ${fallite.length}`);
    fallite.sort();
    const testo = fallite.join("\n") + "\n";
    if (uscita) writeFileSync(join(uscita, `fallite_${nome}.txt`), testo);
    if (precedente) {
      const p = join(resolve(precedente), `fallite_${nome}.txt`);
      if (!existsSync(p)) { console.error(`  manca ${p}: niente confronto per ${nome}`); continue; }
      const vecchie = new Set(readFileSync(p, "utf8").split("\n"));
      for (const f of fallite) if (!vecchie.has(f)) nuove.push(`${nome}: ${f}`);
    }
  }
  if (precedente) {
    console.log(`\nAsserzioni che falliscono ora e prima no: ${nuove.length}`);
    for (const n of nuove) console.log("  " + n);
    if (nuove.length) {
      console.log("\nNON UNIRE: servono la decisione scritta di Davide per ognuna.");
      process.exitCode = 1;
    }
  }
} finally {
  rmSync(lavoro, { recursive: true, force: true });
}
