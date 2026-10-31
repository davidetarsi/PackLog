// Il catalogo della richiesta dentro tassonomia e scheda dei capi. Lo stato e'
// per istanza; si ricostruisce solo quando il catalogo e' un altro oggetto
// (leggiCatalogo restituisce lo stesso finche' la versione non cambia).
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
