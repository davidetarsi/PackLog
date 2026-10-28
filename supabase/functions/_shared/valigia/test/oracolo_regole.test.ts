// Il porting deve rispondere come il bench Python: ogni caso dell'oracolo
// (scritto da esporta_oracolo.py nel bench) e' una chiamata con la risposta
// attesa. Gira con Node 24 (`node --test`) e con Deno (`deno test`).
import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";
import * as rc from "../regole_capi.ts";
import * as tx from "../tassonomia.ts";

type Caso = { f: string; args: unknown[]; out: unknown };
const casi: Caso[] = JSON.parse(readFileSync(new URL("./oracolo_regole.json", import.meta.url), "utf8"));

// nome Python -> funzione TypeScript
const FUNZIONI: Record<string, (...a: any[]) => unknown> = {
  capo_estivo: rc.capoEstivo,
  estivo_vietato: rc.estivoVietato,
  culto_leggero: rc.cultoLeggero,
  caldo_un_capo_al_giorno: rc.caldoUnCapoAlGiorno,
  capo_sopra_leggero: rc.capoSopraLeggero,
  capi_leggeri_col_caldo: rc.capiLeggeriColCaldo,
  pigiami_per_viaggio: rc.pigiamiPerViaggio,
  costumi_per_giorni_di_mare: rc.costumiPerGiorniDiMare,
  minimo_giorni_di_mare: rc.minimoGiorniDiMare,
  conta_come_capospalla: rc.contaComeCapospalla,
  ruolo_scarpa: rc.ruoloScarpa,
  ruolo_capospalla: rc.ruoloCapospalla,
  presentabili_richiesti: rc.presentabiliRichiesti,
  occasione_formale: rc.occasioneFormale,
  felpa_sera_estiva: rc.felpaSeraEstiva,
  strati_medi_massimi: rc.stratiMediMassimi,
  fascia_caldo: rc.fasciaCaldo,
  pantaloni_per_clima: rc.pantaloniPerClima,
  cammino_a_piedi: rc.camminoAPiedi,
  "tassonomia.per_il_generatore": tx.perIlGeneratore,
  "tassonomia.categoria_di": tx.categoriaDi,
  "tassonomia.testo_per_prompt": tx.testoPerPrompt,
};

test("le regole rispondono come il bench Python", () => {
  const sbagliati: string[] = [];
  let diversi = 0;
  const perFunzione: Record<string, number> = {};
  for (const c of casi) {
    const fn = FUNZIONI[c.f];
    assert.ok(fn, `funzione non portata: ${c.f}`);
    const ottenuto = fn(...c.args) ?? null;
    perFunzione[c.f] = (perFunzione[c.f] ?? 0) + 1;
    try {
      assert.deepStrictEqual(ottenuto, c.out);
    } catch {
      diversi++;
      if (sbagliati.length < 20) {
        sbagliati.push(`${c.f}(${JSON.stringify(c.args)}) = ${JSON.stringify(ottenuto)}, atteso ${JSON.stringify(c.out)}`);
      }
    }
  }
  assert.equal(diversi, 0, `${diversi} risposte diverse su ${casi.length}:\n` + sbagliati.join("\n"));
  assert.equal(Object.keys(perFunzione).length, Object.keys(FUNZIONI).length, "ogni funzione ha i suoi casi");
});
