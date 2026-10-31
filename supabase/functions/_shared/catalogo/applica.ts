// Il catalogo della richiesta dentro tassonomia e scheda dei capi. Lo stato e'
// GLOBALE per istanza, non per richiesta; si ricostruisce solo quando il
// catalogo e' un altro oggetto (leggiCatalogo restituisce lo stesso finche' la
// versione non cambia). Dopo questo punto la richiesta NON e' sincrona (pack-trip
// aspetta Jev, il meteo e il modello): se la versione cambia mentre una richiesta
// e' in corso, questa finisce con il catalogo nuovo. E' innocuo: entrambi i
// cataloghi sono validi, e impostaTassonomia e impostaScheda riempiono lo stato
// sul posto, senza attese in mezzo.
import type { Catalogo } from "./catalogo.ts";
import { impostaTassonomia } from "../valigia/tassonomia.ts";
import { impostaScheda } from "../capi/scheda.ts";

let ultimo: Catalogo | null = null;

export function applicaCatalogo(c: Catalogo): void {
  if (c === ultimo) return;
  impostaTassonomia(c);
  impostaScheda(c);
  ultimo = c;
}
