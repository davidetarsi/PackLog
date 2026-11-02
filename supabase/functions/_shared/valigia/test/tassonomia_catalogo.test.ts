// Tassonomia e scheda dei capi dal catalogo: una voce nuova o disattivata nel
// catalogo cambia prompt e pulizia senza toccare il codice.
// Uso: node --test test/tassonomia_catalogo.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { CATALOGO_BASE, type Catalogo } from "../../catalogo/catalogo.ts";
import { applicaCatalogo } from "../../catalogo/applica.ts";
import * as tassonomia from "../tassonomia.ts";
import { normalizza, promptScan } from "../../capi/scheda.ts";

function con(modifica: (c: Catalogo) => void): Catalogo {
  const c: Catalogo = structuredClone(CATALOGO_BASE);
  modifica(c);
  return c;
}

test("un tipo nuovo con un genitore: categoria, generatore e prompt", (t) => {
  t.after(() => applicaCatalogo(CATALOGO_BASE));
  applicaCatalogo(con((c) => c.voci.push({ domain: "clothing_type", id: "Gilet imbottito", sort: 5000, active: true,
    label: { it: "Gilet imbottito", en: "Padded gilet" },
    data: { group: "Outerwear", parent: "Down Jacket", isNew: true, hint: "smanicato imbottito" } })));
  assert.equal(tassonomia.categoriaDi("Gilet imbottito"), "Outerwear");
  assert.equal(tassonomia.perIlGeneratore("Gilet imbottito"), "Down Jacket");
  assert.match(promptScan(), /"Gilet imbottito" \(smanicato imbottito\)/);
  assert.equal(tassonomia.SOTTOCATEGORIE.Outerwear.at(-1), tassonomia.ALTRO);
});

test("un uso disattivato non si propone, ma la pulizia lo tiene", (t) => {
  t.after(() => applicaCatalogo(CATALOGO_BASE));
  applicaCatalogo(con((c) => { c.voci.find((v) => v.domain === "use" && v.id === "Lounge")!.active = false; }));
  const prompt = promptScan();
  assert.doesNotMatch(prompt, /"Lounge"/);
  assert.match(prompt, /ONLY from: \["Everyday", "Office", "Beach", "Swimming", "Hiking", "Sport", "Formal"\]/);
  const z = normalizza({ category: "Upper Body", subCategory: "Hoodie", activityTags: ["Lounge", "Everyday"] });
  assert.deepEqual(z.metadata.activityTags, ["Lounge", "Everyday"]);
});

test("un tipo disattivato sparisce dal prompt ma resta leggibile", (t) => {
  t.after(() => applicaCatalogo(CATALOGO_BASE));
  applicaCatalogo(con((c) => { c.voci.find((v) => v.domain === "clothing_type" && v.id === "Crop Top")!.active = false; }));
  assert.doesNotMatch(promptScan(), /"Crop Top"/);
  assert.equal(tassonomia.categoriaDi("Crop Top"), "Upper Body");
});

test("di nuovo il catalogo di base: prompt di prima", () => {
  const prima = promptScan();
  applicaCatalogo(con(() => {}));
  applicaCatalogo(CATALOGO_BASE);
  assert.equal(promptScan(), prima);
});
