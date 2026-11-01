// Misura i posti che il generatore darebbe su un armadio vuoto o a meta': rigioca ogni valigia
// registrata dal bench (esporta_oracolo.py celle), come confronta_celle.ts, ma con l'armadio
// cambiato, poi chiama postiApp e conta. Non e' un test: non ha soglie, stampa numeri.
// Uso: node test/misura_posti.ts ORACOLO.json --armadio vuoto|meta
//   vuoto: righe = []; meta: le righe di indice pari dell'armadio del caso (la prima, la terza...).
//
// Approssimazioni (la misura deve essere realistica, non perfetta):
//  - viaggio: ricavato dallo scenario del bench (c.viaggio.scenario) nella forma che l'app manda:
//    giorni, attivita, bagaglio, alloggio, lavatrice del viaggio, destinazione oppure tappe (legs).
//    Il bench ha una lavatrice sola per viaggio e nessun alloggio per tappa: qui non si ricavano
//    dalle tappe come fa validaViaggio. L'"intensita'" dello scenario non entra (l'app non la manda).
//  - meteo: quello registrato dal bench (c.viaggio.meteo), con _per_tappa per i viaggi a tappe: e'
//    la stessa forma di climaViaggio.
//  - Jev: i voti e i profili registrati (c.args) valgono per i capi dell'armadio pieno; con meta'
//    armadio i capi tolti non contano, gli altri tengono il loro voto. Con l'armadio vuoto non ce ne
//    sono. Il modello non si richiama: la risposta registrata (c.grezzo) e' la stessa per ogni armadio.
//  - salvate (copie per capo): la quantita' della riga, o null se manca.
//  - Saltati tutti gli insiemi che contengono "v4" (set sigillato). L'oracolo di esporta_oracolo.py
//    non li contiene gia' (pool44, holdout30, v2, v3m); il controllo e' una guardia.
//  - Nomi dei posti in italiano, contati dopo aver riportato plurale e singolare alla stessa voce
//    ("Magliette" e "Maglietta" sono lo stesso posto).
//  - Le valigie dell'oracolo sono viaggi x armadi: i viaggi si ripetono per ogni armadio (la colonna
//    "viaggi distinti" li conta). Con l'armadio vuoto lo stesso viaggio rende lo stesso risultato per
//    ogni armadio; con meta' no, perche' le righe pari sono diverse.
//  - Un posto per tipo e' contato una volta per valigia: la tabella dei nomi dice in quante valigie compare.
import { readFileSync } from "node:fs";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { motiviValigia, tagArmadio } from "../motivi.ts";
import { NOMI_CATEGORIA, NOMI_FAMIGLIA, NOMI_SOTTOCATEGORIA, type NomePosto } from "../posti_nomi.ts";
import { postiApp, type PostoApp } from "../posti.ts";
import { strategySlots } from "../slots.ts";
import { strategySlotsMultitappa } from "../tappe.ts";

const file = process.argv[2];
const iArmadio = process.argv.indexOf("--armadio");
const modo = iArmadio > 0 ? process.argv[iArmadio + 1] : undefined;
if (!file || file.startsWith("-") || (modo !== "vuoto" && modo !== "meta")) {
  console.error("uso: node test/misura_posti.ts ORACOLO.json --armadio vuoto|meta");
  process.exit(2);
}
const casi: any[] = JSON.parse(readFileSync(file, "utf8"));
const righeArmadi: Record<string, RigaArmadio[]> = {};
for (const c of JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"))) {
  if (c.f === "carica_armadio") righeArmadi[c.nome + ".json"] = c.args[0];
}

/** Il viaggio come lo manda l'app, dallo scenario del bench. */
function viaggioDa(sc: Record<string, any>): Record<string, any> {
  const v: Record<string, any> = {
    giorni: sc.giorni, data_inizio: sc.data_inizio, attivita: sc.attivita ?? [], bagaglio: sc.bagaglio ?? "",
    alloggio: sc.alloggio ?? "", lavatrice: !!sc.lavatrice,
  };
  if (Array.isArray(sc.legs) && sc.legs.length) {
    v.tappe = sc.legs.map((l: any) => ({ nome: l.destinazione, paese: l.paese ?? "", giorni: l.giorni, attivita: l.attivita ?? [] }));
    v.giorni = sc.legs.reduce((n: number, l: any) => n + Number(l.giorni || 0), 0);
  } else {
    v.destinazione = { nome: sc.destinazione, paese: sc.paese ?? "" };
  }
  return v;
}

// Plurale -> singolare dei nomi in italiano, per contare "Magliette" e "Maglietta" insieme. I nomi
// solo plurali (Pantaloni, Scarpe) restano come sono, con il qualificatore al plurale.
const VOCI = new Map<string, NomePosto>();
for (const t of [NOMI_SOTTOCATEGORIA, NOMI_CATEGORIA, NOMI_FAMIGLIA]) {
  for (const voce of Object.values(t)) VOCI.set(voce.it[1].toLowerCase(), voce);
}
const QUALIFICATORI_SINGOLARI: Record<string, string> = {
  invernali: "invernale", impermeabili: "impermeabile", eleganti: "elegante", caldi: "caldo", calde: "calda",
};
function aSingolare(nome: string): string {
  let n = nome.toLowerCase();
  const prefissi = [...VOCI.keys()].sort((a, b) => b.length - a.length);
  const p = prefissi.find((k) => n === k || n.startsWith(k + " "));
  if (p && !VOCI.get(p)!.soloPlurale) {
    n = VOCI.get(p)!.it[0].toLowerCase() + n.slice(p.length);
    n = n.split(" ").map((w) => QUALIFICATORI_SINGOLARI[w] ?? w).join(" ");
  } else if (p) {
    // solo plurale: il qualificatore sta gia' al plurale; il nome puo' averlo al singolare (copie = 1)
    n = n.split(" ").map((w) => ({ invernale: "invernali", impermeabile: "impermeabili", elegante: "eleganti", caldo: "caldi", calda: "calde" } as Record<string, string>)[w] ?? w).join(" ");
  }
  return n.charAt(0).toUpperCase() + n.slice(1);
}

const mediana = (xs: number[]) => {
  const o = [...xs].sort((a, b) => a - b), m = o.length >> 1;
  return o.length % 2 ? o[m] : (o[m - 1] + o[m]) / 2;
};
const media = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / (xs.length || 1);
const f1 = (x: number) => x.toFixed(1).replace(".", ",");
const pct = (x: number) => `${(100 * x).toFixed(0)}%`;

interface Misura { id: string; viaggio: string; posti: number; importanti: number; nomiImportanti: Set<string>; nomiUtili: Set<string> }
const perInsieme = new Map<string, Misura[]>();
const saltati: Record<string, number> = {};
let errori = 0;
for (const c of casi) {
  if (String(c.insieme).toLowerCase().includes("v4")) { saltati[c.insieme] = (saltati[c.insieme] ?? 0) + 1; continue; }
  const tutte = righeArmadi[c.armadio];
  const righe = modo === "vuoto" ? [] : tutte.filter((_, i) => i % 2 === 0);
  const items = caricaArmadio(righe);
  try {
    const slots = c.tipo === "singola" ? strategySlots(c.grezzo, items, structuredClone(c.args))
      : strategySlotsMultitappa(c.grezzo, items, structuredClone(c.args));
    const { scenario, meteo } = structuredClone(c.viaggio);
    const motivi = motiviValigia({ scenario, meteo, slots }, tagArmadio(righe));
    const salvate = new Map<string, number | null>(righe.map((r: any) => [String(r.id), r.quantity ?? null]));
    const { posti } = postiApp(slots, motivi as any, salvate, { meteo, viaggio: viaggioDa(scenario), armadio: items, lingua: "it" });
    const imp = posti.filter((p: PostoApp) => p.livello === "importante");
    const lista = perInsieme.get(c.insieme) ?? [];
    lista.push({
      id: `${c.insieme}/${c.armadio}/${c.id}`, viaggio: String(c.id), posti: posti.length, importanti: imp.length,
      nomiImportanti: new Set(imp.map((p) => aSingolare(p.nome))),
      nomiUtili: new Set(posti.filter((p) => p.livello === "utile").map((p) => aSingolare(p.nome))),
    });
    perInsieme.set(c.insieme, lista);
  } catch (e) {
    errori++;
    console.error(`${c.insieme}/${c.armadio}/${c.id}: ERRORE ${(e as Error).stack?.split("\n").slice(0, 3).join(" | ")}`);
  }
}

const top = (liste: Set<string>[], n = 15) => {
  const conti = new Map<string, number>();
  for (const s of liste) for (const nome of s) conti.set(nome, (conti.get(nome) ?? 0) + 1);
  return [...conti].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, n);
};

console.log(`Armadio: ${modo}. Valigie rigiocate: ${[...perInsieme.values()].reduce((n, l) => n + l.length, 0)}`
  + `${errori ? `, con errore ${errori}` : ""}${Object.keys(saltati).length ? `; saltate (v4): ${JSON.stringify(saltati)}` : ""}\n`);
console.log("| insieme | valigie | viaggi distinti | posti: media | posti: mediana | importanti: media | importanti: mediana | importanti: max | valigie con piu' di 6 importanti |");
console.log("|---|---|---|---|---|---|---|---|---|");
for (const [ins, l] of [...perInsieme].sort((a, b) => a[0].localeCompare(b[0]))) {
  const imp = l.map((m) => m.importanti);
  console.log(`| ${ins} | ${l.length} | ${new Set(l.map((m) => m.viaggio)).size} | ${f1(media(l.map((m) => m.posti)))} | ${f1(mediana(l.map((m) => m.posti)))} | ${f1(media(imp))}`
    + ` | ${f1(mediana(imp))} | ${Math.max(...imp)} | ${pct(imp.filter((x) => x > 6).length / l.length)} |`);
}
for (const [ins, l] of [...perInsieme].sort((a, b) => a[0].localeCompare(b[0]))) {
  console.log(`\n### ${ins}: i 15 posti importanti e i 15 utili piu' frequenti (in quante valigie su ${l.length})\n`);
  const imp = top(l.map((m) => m.nomiImportanti)), ut = top(l.map((m) => m.nomiUtili));
  console.log("| importanti | valigie | utili | valigie |");
  console.log("|---|---|---|---|");
  for (let i = 0; i < Math.max(imp.length, ut.length); i++) {
    console.log(`| ${imp[i]?.[0] ?? ""} | ${imp[i]?.[1] ?? ""} | ${ut[i]?.[0] ?? ""} | ${ut[i]?.[1] ?? ""} |`);
  }
}
console.log("\n### Valigie con piu' di 8 importanti\n");
for (const [ins, l] of [...perInsieme].sort((a, b) => a[0].localeCompare(b[0]))) {
  const molti = l.filter((m) => m.importanti > 8);
  console.log(`- ${ins}: ${molti.length} su ${l.length}${molti.length ? ": " + molti.map((m) => `${m.id.split("/").slice(1).join("/")} (${m.importanti})`).join(", ") : ""}`);
}
{
  const tutte = [...perInsieme.values()].flat();
  const massimo = Math.max(9, ...tutte.map((m) => m.importanti));
  const colonne = Array.from({ length: massimo + 1 }, (_, i) => i);
  console.log(`\n### Quanti importanti per valigia (tutte le ${tutte.length})\n`);
  console.log(`| importanti | ${colonne.join(" | ")} |`);
  console.log(`|---|${colonne.map(() => "---").join("|")}|`);
  console.log(`| armadio ${modo} | ${colonne.map((n) => tutte.filter((m) => m.importanti === n).length).join(" | ")} |`);
}
process.exitCode = errori ? 1 : 0;
