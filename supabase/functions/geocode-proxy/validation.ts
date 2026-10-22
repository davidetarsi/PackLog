/** Accetta il vecchio client senza bias e una singola prossimità lon,lat. */
export function isValidGeocodeBias(bias: string): boolean {
  if (bias === "countrycode:none") return true;
  if (bias.length > 100) return false;
  const match =
    /^proximity:([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?),([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)$/i
      .exec(bias);
  if (!match) return false;
  const lon = Number(match[1]);
  const lat = Number(match[2]);
  return Number.isFinite(lon) && Number.isFinite(lat) &&
    lon >= -180 && lon <= 180 && lat >= -90 && lat <= 90;
}
