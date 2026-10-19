// Strato 2 del porting: lettura dell'armadio, quantita', giorni di mare ed
// essenziali rispondono come il bench (oracolo scritto da esporta_oracolo.py).
import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as q from "../quantita.ts";
import { caricaArmadio, eSempreInValigia, radiceSempre, type Capo } from "../capo.ts";

type Caso = { f: string; nome?: string; args: any[]; out: unknown };
const casi: Caso[] = JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"));
const armadi: Record<string, Capo[]> = {};

const FUNZIONI: Record<string, (...a: any[]) => unknown> = {
  carica_armadio: caricaArmadio,
  giorni_di_mare: q.giorniDiMare,
  e_attivita_acqua: q.eAttivitaAcqua,
  norm_intensita: q.normIntensita,
  radice_sempre: radiceSempre,
  e_sempre_in_valigia: eSempreInValigia,
  quantity_for: q.quantityFor,
  essenziali_per_viaggio: (nome: string, giorni: number, lav: boolean, tmax: number | null = null) =>
    q.essenzialiPerViaggio(armadi[nome], giorni, lav, tmax),
};

test("quantita', mare ed essenziali rispondono come il bench Python", () => {
  let diversi = 0;
  const esempi: string[] = [];
  const viste = new Set<string>();
  for (const c of casi) {
    const fn = FUNZIONI[c.f];
    assert.ok(fn, `funzione non portata: ${c.f}`);
    viste.add(c.f);
    const ottenuto = fn(...c.args) ?? null;
    if (c.f === "carica_armadio") armadi[c.nome!] = ottenuto as Capo[];
    try {
      assert.deepStrictEqual(ottenuto, c.out);
    } catch {
      diversi++;
      if (esempi.length < 15) {
        const a = JSON.stringify(c.args).slice(0, 200);
        esempi.push(`${c.f}(${a}) = ${JSON.stringify(ottenuto).slice(0, 300)}, atteso ${JSON.stringify(c.out).slice(0, 300)}`);
      }
    }
  }
  assert.equal(diversi, 0, `${diversi} risposte diverse su ${casi.length}:\n` + esempi.join("\n"));
  assert.equal(viste.size, Object.keys(FUNZIONI).length, "ogni funzione ha i suoi casi");
});
