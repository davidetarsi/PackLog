// Costanti proprie dell'app (non generate dal banco: per quelle vedi costanti.ts).

/** Versione del generatore: data dell'ultima modifica alle regole che cambiano la valigia.
 *  Va nella risposta di pack-trip, fuori dalla valigia, perche' l'app sappia con quale
 *  versione e' stata generata. */
export const VERSIONE_GENERATORE = "2026-11-08";

/** Il campo della risposta di pack-trip che porta la versione. Sta accanto alla valigia,
 *  non dentro: il confronto col banco non lo vede. */
export function campoVersione(): { versione_generatore: string } {
  return { versione_generatore: VERSIONE_GENERATORE };
}
