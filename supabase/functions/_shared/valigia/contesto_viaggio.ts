// Il contesto del viaggio comune ai capi posseduti e ai bisogni residui.
import type { Luogo, Tappa } from "../clima/meteo.ts";
import * as K from "./costanti.ts";
import { lavanderiaPresunta } from "./dopo.ts";
import { eTrekking, type Record_ } from "./inject.ts";
import { ordina } from "./py.ts";
import { camminoAPiedi } from "./regole_capi.ts";

export function normalizzaQuantitaViaggio(a: {
  giorni: number; lavatrice: boolean; attivita?: string[] | null; bagaglio?: string;
  lavatrice_essenziali?: boolean | null;
}): { giorni: number; lavatrice: boolean; lavatriceEssenziali: boolean } {
  const giorni = a.lavatrice_essenziali == null && lavanderiaPresunta(a.giorni, a.lavatrice)
    ? K.GIORNI_LAVANDERIA : a.giorni;
  let lavatrice = a.lavatrice;
  if (K.CAMMINO_LAVA_A_MANO && camminoAPiedi(a.attivita, a.bagaglio ?? "", giorni)) lavatrice = true;
  return { giorni, lavatrice, lavatriceEssenziali: a.lavatrice_essenziali == null ? a.lavatrice : a.lavatrice_essenziali };
}

export function ordinaTappe(perTappa: Record_[]): Record_[] {
  perTappa.forEach((t, i) => { if (!("_ordine" in t)) t._ordine = i; });
  return ordina(perTappa, (t) => [
    -(t.meteo.temp_max_media != null ? t.meteo.temp_max_media : -99.0),
    -(t.giorni || 0), t._ordine,
  ]);
}

export function preparaContestoTappe(sc: Record_, perTappa: Record_[], bagaglio = "") {
  const giorni = perTappa.reduce((n, t) => n + Math.trunc(Number(t.giorni || 1)), 0);
  const ordinate = ordinaTappe(perTappa), base = ordinate[0];
  let attivitaBase: string[] = [...(sc.attivita || []), ...(base.attivita || [])];
  const trekkingDiTappa = K.SLOT_TREKKING && perTappa.length > 1 && !eTrekking(sc.attivita) && eTrekking(base.attivita);
  if (trekkingDiTappa) attivitaBase = attivitaBase.filter((x) => !eTrekking([x]));
  const lavatriceEssenziali = Boolean(sc.lavatrice);
  const lavatriceTappe = normalizzaQuantitaViaggio({ giorni, lavatrice: lavatriceEssenziali,
    attivita: sc.attivita, bagaglio, lavatrice_essenziali: lavatriceEssenziali }).lavatrice;
  const lavatriceBase = normalizzaQuantitaViaggio({ giorni, lavatrice: lavatriceTappe,
    attivita: attivitaBase, bagaglio, lavatrice_essenziali: lavatriceEssenziali }).lavatrice;
  return { giorni, ordinate, base, attivitaBase, trekkingDiTappa,
    lavatriceEssenziali, lavatriceTappe, lavatriceBase };
}

/** Il viaggio come lo manda l'app. */
export interface ViaggioApp {
  /** "AAAA-MM-GG" */
  data_inizio: string;
  giorni: number;
  /** Una sola destinazione... */
  destinazione?: Luogo | null;
  /** ...oppure piu' tappe in fila, ognuna con i suoi giorni e le sue attivita'. */
  tappe?: Tappa[] | null;
  attivita?: string[] | null;
  /** Testo libero come nel bench: "trolley medio", "zaino da 40 litri", "borsa a tracolla". */
  bagaglio?: string | null;
  alloggio?: string | null;
  lavatrice?: boolean | null;
}

/** Lo scenario nella forma del bench, da cui partono prompt, Jev e matcher. */
export function scenarioDaApp(v: ViaggioApp): Record_ {
  const sc: Record_ = {
    data_inizio: v.data_inizio,
    giorni: v.giorni,
    attivita: [...(v.attivita ?? [])],
    bagaglio: v.bagaglio ?? "",
    alloggio: v.alloggio ?? "",
    lavatrice: !!v.lavatrice,
  };
  if (v.tappe?.length) {
    sc.legs = v.tappe.map((t) => ({ destinazione: t.nome, giorni: t.giorni, attivita: [...(t.attivita ?? [])] }));
  } else if (v.destinazione) {
    sc.destinazione = v.destinazione.nome;
    sc.paese = v.destinazione.paese ?? "";
  }
  return sc;
}

