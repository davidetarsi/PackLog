// pack-trip: gli id di attivita' e alloggi diventano i testi del generatore prima
// della validazione. Le app vecchie mandano gia' i testi: restano come sono.
// Uso: node --test _shared/catalogo/test/traduci.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { CATALOGO_BASE, traduciViaggio } from "../catalogo.ts";
import { IngressoNonValido, validaViaggio } from "../../valigia/ingresso.ts";

const OGGI = "2026-10-19";
const islanda = { nome: "Islanda", paese: "Islanda", lat: 64.14, lon: -21.9 };
const olanda = { nome: "Olanda", paese: "Paesi Bassi", lat: 52.37, lon: 4.9 };

test("gli id di attivita' e alloggio di una tappa diventano testi", () => {
  const v = validaViaggio(traduciViaggio({
    data_inizio: "2027-02-20",
    tappe: [{ ...islanda, giorni: 3, attivita: ["city", "evenings"], alloggio: "friends" }],
  }, CATALOGO_BASE), OGGI);
  assert.deepEqual(v.tappe![0].attivita, ["visite in citta", "cene al ristorante", "vita notturna"]);
  assert.equal(v.alloggio, "da amici o parenti");
});

test("a piu' tappe l'alloggio del viaggio unisce gli alloggi gia' tradotti", () => {
  const v = validaViaggio(traduciViaggio({
    data_inizio: "2027-02-20",
    tappe: [
      { ...islanda, giorni: 3, alloggio: "hotel", attivita: ["walks"] },
      { ...olanda, giorni: 2, alloggio: "friends", attivita: ["cycling"] },
    ],
  }, CATALOGO_BASE), OGGI);
  assert.equal(v.alloggio, "hotel (Islanda), da amici o parenti (Olanda)");
  assert.deepEqual(v.tappe![0].attivita, ["escursioni leggere"]);
  // una voce disattivata si traduce comunque (la bicicletta resta leggibile)
  assert.deepEqual(v.tappe![1].attivita, ["bicicletta"]);
});

test("attivita e alloggio del viaggio (formato a tappe vecchio) si traducono", () => {
  const v = validaViaggio(traduciViaggio({
    data_inizio: "2026-11-02", giorni: 5, destinazione: islanda,
    attivita: ["diving", "high_mountain"], alloggio: "friends",
  }, CATALOGO_BASE), OGGI);
  assert.deepEqual(v.attivita, ["immersioni", "mare", "escursioni in quota"]);
  assert.equal(v.alloggio, "da amici o parenti");
});

test("il formato vecchio (testi gia' tradotti) resta invariato", () => {
  const vecchio = {
    data_inizio: "2026-11-02", giorni: 5, destinazione: islanda,
    attivita: ["visite in citta", "escursioni leggere"], alloggio: "hotel",
    bagaglio: "trolley medio", lavatrice: true,
  };
  assert.deepEqual(traduciViaggio(vecchio, CATALOGO_BASE), vecchio);
  assert.deepEqual(validaViaggio(traduciViaggio(vecchio, CATALOGO_BASE), OGGI),
    validaViaggio(vecchio, OGGI));
});

test("il viaggio ricevuto non si modifica", () => {
  const ricevuto = { data_inizio: "2027-02-20", tappe: [{ ...islanda, giorni: 3, attivita: ["city"], alloggio: "hotel" }] };
  const copia = structuredClone(ricevuto);
  traduciViaggio(ricevuto, CATALOGO_BASE);
  assert.deepEqual(ricevuto, copia);
});

test("un valore che non e' un testo o un elenco resta, e lo rifiuta la validazione", () => {
  const conNumero = traduciViaggio({ data_inizio: "2026-11-02", giorni: 2, destinazione: islanda, attivita: [5] }, CATALOGO_BASE);
  assert.throws(() => validaViaggio(conNumero, OGGI), IngressoNonValido);
  const conStringa = traduciViaggio({ data_inizio: "2026-11-02", giorni: 2, destinazione: islanda, attivita: "city" }, CATALOGO_BASE);
  assert.throws(() => validaViaggio(conStringa, OGGI), /deve essere un elenco/);
  const senzaViaggio = traduciViaggio(null, CATALOGO_BASE);
  assert.equal(senzaViaggio, null);
});
