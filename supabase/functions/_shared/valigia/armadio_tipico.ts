// L'armadio tipico: un armadio virtuale con un capo per ogni genere di cosa che si porta in valigia.
// Serve ai posti (posti.ts): quando il generatore ha un mancante, il nome del posto lo sceglie il
// generatore stesso, rifacendo il suo abbinamento (slots.ts) su questi capi invece che sull'armadio
// dell'utente. Non entra mai nella scelta dei capi veri.
//
// I 75 capi sono quelli che Davide ha inserito sull'ambiente DEV col Rapid Fire dell'app; i metadati
// (ai_metadata) sono quelli della funzione di scan di produzione (Haiku + Jev), tali e quali, tranne
// cinque righe in cui lo scan ha sbagliato in modo evidente. Sono bug dello scan da correggere; qui
// sono corrette a mano nel file armadio_tipico.json (campo "correzione" della riga):
//  - Costume: lo scan lo mette in Essentials/Other; e' Lower Body/Swimwear.
//  - Muta sub: lo scan non l'ha classificata (Not Classified, nessun metadato); e' Lower Body/Wetsuit,
//    calore 3, impermeabilita' 2. Formalita', attivita', volume e copertura sono scelti a mano.
//  - Tuta sci: lo scan la mette in Full Body/Other; il catalogo ha Ski Suit, e la mette in Outerwear.
//  - Pile leggero: lo scan lo mette in Outerwear/Casual Jacket; e' Upper Body/Fleece, calore 3.
//  - Calzini: lo scan da' calore 3; sono calzini corti, 1 nella scala dello scan.
import { caricaArmadio, type Capo, type RigaArmadio } from "./capo.ts";
import righe from "./armadio_tipico.json" with { type: "json" };

/** I capi dell'armadio tipico, nuovi a ogni chiamata: il generatore ne segna alcuni (solo_neve). */
export function armadioTipico(): Capo[] {
  return caricaArmadio(righe as unknown as RigaArmadio[]);
}
