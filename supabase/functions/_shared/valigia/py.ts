// Piccole funzioni che riproducono il comportamento di Python dove JavaScript
// fa diversamente. Il porting deve rispondere come il bench: un arrotondamento
// diverso sposta una quantita' di un pezzo.

/** round() di Python: alla pari arrotonda al numero pari (2.5 -> 2, 3.5 -> 4). */
export function pyRound(x: number): number {
  const f = Math.floor(x);
  const d = x - f;
  if (d > 0.5) return f + 1;
  if (d < 0.5) return f;
  return f % 2 === 0 ? f : f + 1;
}

/** Divisione intera di Python (a // b) per interi: arrotonda verso -infinito. */
export function floorDiv(a: number, b: number): number {
  return Math.floor(a / b);
}

/** Toglie gli accenti come unicodedata.normalize("NFD") + categoria "Mn". */
export function senzaAccenti(t: string): string {
  return t.normalize("NFD").replace(/\p{Mn}/gu, "");
}
