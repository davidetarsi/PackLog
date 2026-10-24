// L'uscita per l'app: i capi come li vede l'utente (uno per capo, con la quantita'
// da portare), il tetto sulle quantita' che ha davvero nell'armadio, e gli avvisi
// su cio' che manca. Non tocca la scelta dei capi: lavora sul risultato del generatore.
import { vero } from "./py.ts";

type Record_ = Record<string, any>;

export const CODICE_POCHI = "pochi_pezzi";

export interface CapoApp {
  item_id: string;
  quantita: number;
  in_partenza: boolean;
  motivo: { codice: string; etichetta: string; frase: string };
}

export interface AvvisoApp {
  id: string;
  codice: string;
  livello: "importante" | "utile";
  titolo: string;
  perche: string;
  cerca: string | null;
}

const maiuscola = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

/** Capi (uniti per item_id, quantita' sommata, tetto dell'armadio) e avvisi della valigia. */
export function uscitaApp(valigia: Record_, motivi: { capi: Record_[]; essenziali: Record_[] },
  salvate: Map<string, number | null>): { capi: CapoApp[]; avvisi: AvvisoApp[] } {
  // Lo stesso capo puo' stare in piu' tappe, come ideale e ripiego, o tra gli essenziali:
  // una riga sola, con la quantita' di tutti i posti in cui serve.
  const uniti = new Map<string, { item: string; quantita: number; in_partenza: boolean; motivo: Record_ }>();
  for (const x of [...motivi.capi, ...motivi.essenziali]) {
    const id = String(x.item_id);
    const quantita = Number(x.quantita ?? 1);
    const corrente = uniti.get(id);
    if (corrente) {
      corrente.quantita += quantita;
      corrente.in_partenza = corrente.in_partenza || vero(x.in_partenza);
    } else {
      uniti.set(id, { item: String(x.item ?? ""), quantita, in_partenza: vero(x.in_partenza), motivo: x.motivo });
    }
  }

  const capi: CapoApp[] = [];
  const avvisi: Omit<AvvisoApp, "id">[] = [];
  for (const [id, c] of uniti) {
    const tetto = salvate.get(id) ?? 1;
    const quantita = Math.min(c.quantita, tetto);
    capi.push({
      item_id: id, quantita, in_partenza: c.in_partenza,
      motivo: { codice: c.motivo.codice, etichetta: c.motivo.etichetta, frase: c.motivo.frase },
    });
    if (quantita < c.quantita) {
      avvisi.push({
        codice: CODICE_POCHI,
        livello: c.motivo.codice === "essenziale" ? "importante" : "utile",
        titolo: `Pochi ${c.item} per questo viaggio`,
        perche: `Ne servirebbero ${c.quantita}, nell'armadio ne hai ${tetto}.`,
        cerca: c.item,
      });
    }
  }

  for (const g of (valigia.mancanti_canonici ?? []) as Record_[]) {
    avvisi.push({
      codice: String(g.tipo),
      livello: g.priorita === "necessario" ? "importante" : "utile",
      titolo: maiuscola(String(g.slot ?? "")),
      perche: String(g.reason ?? ""),
      cerca: null,
    });
  }

  // Prima gli importanti; a parita' di livello l'ordine di sopra (sort e' stabile).
  const ordinati = avvisi
    .sort((a, b) => Number(b.livello === "importante") - Number(a.livello === "importante"))
    .map((a, i) => ({ id: `${a.codice}:${i}`, ...a }));
  return { capi, avvisi: ordinati };
}
