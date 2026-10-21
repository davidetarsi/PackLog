// Confronto Claude Haiku 5.5 / GPT-6 Luna sulle due chiamate che costano:
// lo scan di una foto (prompt di item-metadata) e la valigia (pack-trip, senza
// Jev, che e' uguale per tutti e due). Per ogni chiamata: token, costo, tempo e
// risposta, per confrontare anche la qualita'. COSTA (pochi centesimi): le
// chiavi arrivano dall'ambiente, mai stampate.
//
// Uso (dalla radice del repo):
//   ANTHROPIC_API_KEY=... OPENAI_KEY=... deno run --allow-net --allow-read --allow-write --allow-env \
//     --config supabase/functions/item-metadata/deno.json \
//     supabase/functions/_shared/test/confronto_modelli.ts \
//     --foto CARTELLA_JPG --armadio ARMADIO.json --uscita confronto.json [--luna gpt-6-luna] [--ripeti 1]
//
// ARMADIO.json: la lista dei capi come la legge pack-trip, [{ id, name, category, ai_metadata }, ...].
import { parseArgs } from "node:util";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { extname, join } from "node:path";
import { claudeHttp, MODELLO as MODELLO_CLAUDE } from "../claude.ts";
import { bloccoImmagine } from "../immagine.ts";
import { leggiJson, promptScan } from "../capi/scheda.ts";
import { MAX_TOKENS_FOTO } from "../capi/analisi.ts";
import { climaViaggio, type Servizi } from "../clima/meteo.ts";
import { generaValigia, MAX_TOKENS_VALIGIA, scenarioDaApp } from "../valigia/genera.ts";
import { validaViaggio } from "../valigia/ingresso.ts";
import type { RigaArmadio } from "../valigia/capo.ts";

const { values: arg } = parseArgs({
  options: {
    foto: { type: "string" },
    armadio: { type: "string" },
    uscita: { type: "string", default: "confronto.json" },
    luna: { type: "string", default: "gpt-6-luna" },
    ripeti: { type: "string", default: "1" },
  },
});
const chiaveClaude = Deno.env.get("ANTHROPIC_API_KEY"), chiaveOpenai = Deno.env.get("OPENAI_KEY");
if (!chiaveClaude || !chiaveOpenai) throw new Error("ANTHROPIC_API_KEY e OPENAI_KEY nell'ambiente");
if (!arg.foto && !arg.armadio) throw new Error("serve --foto, --armadio o tutti e due");

// $ per milione di token (listino ottobre 2026, prompt sotto 100k): da
// ricontrollare sulle pagine dei prezzi prima di trarre conclusioni.
const PREZZI: Record<string, { in: number; out: number }> = {
  [MODELLO_CLAUDE]: { in: 0.10, out: 0.50 },
  [arg.luna!]: { in: 0.10, out: 0.50 },
};

interface Chiamata {
  modello: string;
  testo: string;
  ingresso: number;
  uscita: number;
  ms: number;
  errore?: string;
}
type Contenuto = { testo: string } | { testo: string; immagineBase64: string };
type Chiedi = (c: Contenuto, maxTokens: number) => Promise<Chiamata>;

const claude = claudeHttp(chiaveClaude);
const chiediClaude: Chiedi = async (c, maxTokens) => {
  const t0 = Date.now();
  const contenuto = "immagineBase64" in c
    ? [bloccoImmagine(c.immagineBase64), { type: "text" as const, text: c.testo }]
    : c.testo;
  const r = await claude(contenuto, maxTokens);
  return {
    modello: MODELLO_CLAUDE, testo: r.testo, ms: Date.now() - t0,
    ingresso: Number(r.uso.input_tokens ?? 0), uscita: Number(r.uso.output_tokens ?? 0),
  };
};

// Luna con lo stesso compito: ragionamento basso come effort "low" di Claude,
// immagine in dettaglio alto come lo scan di oggi.
const chiediLuna: Chiedi = async (c, maxTokens) => {
  const t0 = Date.now();
  const content = "immagineBase64" in c
    ? [
      { type: "text", text: c.testo },
      { type: "image_url", image_url: { url: `data:${bloccoImmagine(c.immagineBase64).source.media_type};base64,${c.immagineBase64}`, detail: "high" } },
    ]
    : c.testo;
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${chiaveOpenai}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: arg.luna, messages: [{ role: "user", content }],
      max_completion_tokens: maxTokens, reasoning_effort: "low",
    }),
    signal: AbortSignal.timeout(120000),
  });
  if (r.status >= 400) throw new Error(`${arg.luna}: ${r.status} ${(await r.text()).slice(0, 300)}`);
  const d = await r.json();
  return {
    modello: arg.luna!, testo: d.choices[0].message.content ?? "", ms: Date.now() - t0,
    ingresso: d.usage?.prompt_tokens ?? 0, uscita: d.usage?.completion_tokens ?? 0,
  };
};

const MODELLI: Chiedi[] = [chiediClaude, chiediLuna];
const costo = (c: Chiamata) => (c.ingresso * PREZZI[c.modello].in + c.uscita * PREZZI[c.modello].out) / 1e6;

async function prova(chiedi: Chiedi, c: Contenuto, maxTokens: number, nome: string): Promise<Chiamata> {
  try {
    return await chiedi(c, maxTokens);
  } catch (e) {
    return { modello: nome, testo: "", ingresso: 0, uscita: 0, ms: 0, errore: (e as Error).message };
  }
}

// ── Foto ────────────────────────────────────────────────────────────────────
const foto: unknown[] = [];
if (arg.foto) {
  const file = readdirSync(arg.foto).filter((f) => [".jpg", ".jpeg", ".png", ".webp"].includes(extname(f).toLowerCase()));
  for (const f of file) {
    const immagineBase64 = btoa(Array.from(readFileSync(join(arg.foto, f)), (b) => String.fromCharCode(b)).join(""));
    for (let i = 0; i < Number(arg.ripeti); i++) {
      for (const [n, chiedi] of MODELLI.entries()) {
        const nome = n === 0 ? MODELLO_CLAUDE : arg.luna!;
        const r = await prova(chiedi, { testo: promptScan(), immagineBase64 }, MAX_TOKENS_FOTO, nome);
        const capi = leggiJson(r.testo);
        foto.push({ file: f, ...r, costo: costo(r), capi: Array.isArray(capi) ? capi.length : capi ? 1 : 0, risposta: capi ?? r.testo });
        console.log(`foto ${f} ${nome}: ${r.errore ?? `${r.ingresso}+${r.uscita} token, ${r.ms} ms`}`);
      }
    }
  }
}

// ── Valigie ─────────────────────────────────────────────────────────────────
const cache = new Map<string, any>();
const meteo: Servizi = {
  async scarica(url, params) {
    const u = new URL(url);
    for (const [k, v] of Object.entries(params)) u.searchParams.set(k, String(v));
    const r = await fetch(u, { signal: AbortSignal.timeout(30000) });
    return { status: r.status, json: () => r.json() };
  },
  async leggiCache(k) { return cache.has(k) ? structuredClone(cache.get(k)) : null; },
  async scriviCache(k, v) { cache.set(k, structuredClone(v)); },
  oggiUtc: () => new Date().toISOString().slice(0, 10),
  oggi: () => new Date().toISOString().slice(0, 10),
  attendi: (t) => new Promise<void>((r) => setTimeout(r, 1000 * (t + 1))),
};

// Gli stessi viaggi della prova dal vivo del generatore, nel futuro.
const tra = (giorni: number) => new Date(Date.now() + giorni * 86400000).toISOString().slice(0, 10);
const VIAGGI: [string, unknown][] = [
  ["lisbona_citta", { data_inizio: tra(5), giorni: 4,
    destinazione: { nome: "Lisbona", paese: "Portogallo", lat: 38.7223, lon: -9.1393 },
    attivita: ["visite in citta", "cene al ristorante"], bagaglio: "trolley medio", alloggio: "hotel" }],
  ["milano_lavoro", { data_inizio: tra(8), giorni: 3,
    destinazione: { nome: "Milano", paese: "Italia", lat: 45.4642, lon: 9.19 },
    attivita: ["riunioni di lavoro", "cena elegante"], bagaglio: "borsa a tracolla", alloggio: "hotel" }],
  ["cortina_trekking", { data_inizio: tra(60), giorni: 5,
    destinazione: { nome: "Cortina d'Ampezzo", paese: "Italia", lat: 46.5369, lon: 12.13903 },
    attivita: ["trekking", "cene al ristorante"], bagaglio: "zaino da 40 litri", alloggio: "rifugio" }],
  ["bali_mare", { data_inizio: tra(90), giorni: 10,
    destinazione: { nome: "Ubud", paese: "Indonesia", lat: -8.5069, lon: 115.2625 },
    attivita: ["mare", "visita ai templi", "snorkeling", "cene informali"], bagaglio: "valigia grande",
    alloggio: "villa", lavatrice: true }],
  ["islanda_olanda", { data_inizio: tra(120), tappe: [
    { nome: "Reykjavik", paese: "Islanda", lat: 64.1355, lon: -21.8954, giorni: 5,
      attivita: ["aurora boreale", "terme geotermali", "escursioni leggere"] },
    { nome: "Amsterdam", paese: "Paesi Bassi", lat: 52.3676, lon: 4.9041, giorni: 4,
      attivita: ["visite in citta", "musei", "cene informali"] }],
    bagaglio: "valigia grande", alloggio: "hotel" }],
];

const valigie: unknown[] = [];
if (arg.armadio) {
  const righe: RigaArmadio[] = JSON.parse(readFileSync(arg.armadio, "utf8"));
  for (const [id, corpo] of VIAGGI) {
    const v = validaViaggio(corpo, new Date().toISOString().slice(0, 10));
    for (let i = 0; i < Number(arg.ripeti); i++) {
      for (const [n, chiedi] of MODELLI.entries()) {
        const nome = n === 0 ? MODELLO_CLAUDE : arg.luna!;
        let chiamata: Chiamata | undefined;
        try {
          const r = await generaValigia(scenarioDaApp(v), righe, {
            clima: () => climaViaggio(v.data_inizio, v.giorni, v.destinazione ?? null, v.tappe ?? null, meteo),
            modello: async (prompt) => {
              chiamata = await chiedi({ testo: prompt }, MAX_TOKENS_VALIGIA);
              return { testo: chiamata.testo };
            },
            jev: null,
          });
          const s = r.valigia;
          const nomi = (xs: any[] = []) => xs.map((x) => x?.name ?? x?.nome ?? x);
          valigie.push({ viaggio: id, ...chiamata, costo: costo(chiamata!), ideali: nomi(s.ideali),
            ripieghi: nomi(s.ripieghi), essenziali: nomi(s.essenziali), mancanti: nomi(s.mancanti) });
          console.log(`valigia ${id} ${nome}: ${chiamata!.ingresso}+${chiamata!.uscita} token, ${chiamata!.ms} ms, `
            + `${s.ideali.length} ideali, ${(s.mancanti ?? []).length} mancanti`);
        } catch (e) {
          valigie.push({ viaggio: id, modello: nome, errore: (e as Error).message, ...(chiamata ?? {}) });
          console.log(`valigia ${id} ${nome}: ERRORE ${(e as Error).message}`);
        }
      }
    }
  }
}

// ── Riepilogo ───────────────────────────────────────────────────────────────
function riepilogo(righe: any[]) {
  const per: Record<string, any> = {};
  for (const m of [MODELLO_CLAUDE, arg.luna!]) {
    const ok = righe.filter((r) => r.modello === m && !r.errore);
    const media = (k: string) => ok.length ? ok.reduce((a, r) => a + r[k], 0) / ok.length : 0;
    per[m] = {
      chiamate: righe.filter((r) => r.modello === m).length, errori: righe.filter((r) => r.modello === m && r.errore).length,
      token_ingresso_medi: Math.round(media("ingresso")), token_uscita_medi: Math.round(media("uscita")),
      costo_medio_usd: Number(media("costo").toFixed(6)), ms_medi: Math.round(media("ms")),
    };
  }
  return per;
}
const esito = { data: new Date().toISOString(), prezzi: PREZZI, riepilogo: { foto: riepilogo(foto), valigie: riepilogo(valigie) }, foto, valigie };
writeFileSync(arg.uscita!, JSON.stringify(esito, null, 1));
console.log(JSON.stringify(esito.riepilogo, null, 1));
console.log(`dettaglio in ${arg.uscita}`);
