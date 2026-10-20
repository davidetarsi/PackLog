// Prova dal vivo di item-metadata (dal nome) con GPT e Jev veri: registra le
// risposte grezze dei servizi e la scheda che ne esce, per rigiocarle nel
// bench (scheda_capo.py) e vedere che danno la stessa cosa. COSTA: solo con
// l'ok di Davide. Le chiavi arrivano nell'ambiente (prova_dal_vivo_app.py del bench).
// Uso: python prova_dal_vivo_app.py .../capi/test/prova_dal_vivo.ts OUT.json nome1 nome2 ...
import { writeFileSync } from "node:fs";
import { type ChiediGpt, openaiScheda, schedaDaNome } from "../analisi.ts";
import { type ChiediJev, jevHttp } from "../../valigia/jev.ts";

const [out, ...nomi] = process.argv.slice(2);
const chiaveOpenai = process.env.OPENAI_KEY, chiaveJev = process.env.TYPESAFE_API_KEY;
if (!out || !nomi.length || !chiaveOpenai || !chiaveJev) throw new Error("uso: OUT.json nome...; chiavi nell'ambiente");

const prove = [];
for (const nome of nomi) {
  const grezzo: { gpt: string[]; jev: unknown } = { gpt: [], jev: null };
  const gpt0 = openaiScheda(chiaveOpenai), jev0 = jevHttp(chiaveJev);
  const gpt: ChiediGpt = async (c, o) => {
    const t = await gpt0(c, o);
    grezzo.gpt.push(t);
    return t;
  };
  const jev: ChiediJev = async (s, d) => {
    const r = await jev0(s, d);
    grezzo.jev = r.answers;
    return r;
  };
  const t0 = Date.now();
  const r = await schedaDaNome(nome, { gpt, jev });
  prove.push({ nome, ms: Date.now() - t0, grezzo, risultato: r });
  console.log(`${nome}: ${r.items[0].metadata.category} / ${r.items[0].metadata.subCategory}, `
    + `dubbi ${r.items[0].dubbi.map((d) => d.campo).join(", ") || "-"} (${Date.now() - t0} ms)`);
}
writeFileSync(out, JSON.stringify(prove, null, 1));
