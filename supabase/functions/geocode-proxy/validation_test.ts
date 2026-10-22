import { strict as assert } from "node:assert";
import { isValidGeocodeBias } from "./validation.ts";

Deno.test("accetta prossimità valide, coordinate zero e il client precedente", () => {
  for (
    const bias of [
      "countrycode:none",
      "proximity:12.4964,41.9028",
      "proximity:-58.38,-34.6",
      "proximity:0,0",
      "proximity:-180,-90",
      "proximity:180,90",
      "proximity:1e-7,0",
    ]
  ) {
    assert.equal(isValidGeocodeBias(bias), true, bias);
  }
});

Deno.test("rifiuta coordinate mancanti, malformate e fuori intervallo", () => {
  for (
    const bias of [
      "",
      "proximity:",
      "proximity:12",
      "proximity:,41",
      "proximity:12,",
      "proximity:181,41",
      "proximity:-181,41",
      "proximity:12,91",
      "proximity:12,-91",
      "proximity:NaN,41",
      "proximity:12,Infinity",
      "proximity:1e999,0",
      "proximity:12,41,0",
      "proximity:0x12,41",
      "proximity: ,41",
      "proximity:12,41|countrycode:it",
      "proximity:12,41\n",
      "countrycode:it",
      "ip:1.2.3.4",
    ]
  ) {
    assert.equal(isValidGeocodeBias(bias), false, bias);
  }
});
