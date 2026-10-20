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

/** Verita' di Python: vuoti (null, false, 0, "", [], {}, Set/Map vuoti) sono falsi. */
export function vero(x: unknown): boolean {
  if (x == null || x === false || x === 0 || x === "" || Number.isNaN(x)) return false;
  if (Array.isArray(x)) return x.length > 0;
  if (x instanceof Set || x instanceof Map) return x.size > 0;
  if (typeof x === "object") return Object.keys(x as object).length > 0;
  return true;
}

/** `a or b` di Python. */
export function o<T, U>(a: T, b: U): T | U {
  return vero(a) ? a : b;
}

type Chiave = number | string | boolean | null | undefined | Chiave[];

/** Confronto fra chiavi come le tuple di Python (booleani come 0/1). */
export function confronta(a: Chiave, b: Chiave): number {
  if (Array.isArray(a) && Array.isArray(b)) {
    const n = Math.min(a.length, b.length);
    for (let i = 0; i < n; i++) {
      const c = confronta(a[i], b[i]);
      if (c !== 0) return c;
    }
    return a.length - b.length;
  }
  const na = typeof a === "boolean" ? Number(a) : a;
  const nb = typeof b === "boolean" ? Number(b) : b;
  if (typeof na === "string" && typeof nb === "string") return na < nb ? -1 : na > nb ? 1 : 0;
  if (typeof na === "number" && typeof nb === "number") return na - nb;
  throw new Error(`confronto fra tipi diversi: ${JSON.stringify(a)} e ${JSON.stringify(b)}`);
}

/** sorted(xs, key=f, reverse=r): stabile come Python (anche con reverse). */
export function ordina<T>(xs: Iterable<T>, f: (x: T) => Chiave = (x) => x as unknown as Chiave, reverse = false): T[] {
  const a = [...xs].map((x, i) => ({ x, i, k: f(x) }));
  a.sort((p, q) => {
    const c = confronta(p.k, q.k);
    return c !== 0 ? (reverse ? -c : c) : p.i - q.i;
  });
  return a.map((p) => p.x);
}

/** min(xs, key=f): il primo dei minimi, come Python. */
export function minimo<T>(xs: Iterable<T>, f: (x: T) => Chiave): T | undefined {
  let best: T | undefined, bk: Chiave, primo = true;
  for (const x of xs) {
    const k = f(x);
    if (primo || confronta(k, bk) < 0) { best = x; bk = k; primo = false; }
  }
  return best;
}

/** max(xs, key=f): il primo dei massimi, come Python. */
export function massimo<T>(xs: Iterable<T>, f: (x: T) => Chiave): T | undefined {
  let best: T | undefined, bk: Chiave, primo = true;
  for (const x of xs) {
    const k = f(x);
    if (primo || confronta(k, bk) > 0) { best = x; bk = k; primo = false; }
  }
  return best;
}

/** Un float di Python come stringa (f"{x}"): 5.0 -> "5.0", -3.8 -> "-3.8", None -> "None".
 *  I valori del meteo nel bench sono sempre float, anche quando sono interi. */
export function pf(x: number | null | undefined): string {
  if (x == null) return "None";
  if (Object.is(x, -0)) return "-0.0";
  if (Number.isInteger(x) && Math.abs(x) < 1e16) return x.toFixed(1);
  return String(x);
}

/** Un valore qualunque come lo stampa f"{x}" di Python (int, float, str, None). */
export function ps(x: unknown, float = false): string {
  if (x == null) return "None";
  if (typeof x === "number") return float ? pf(x) : String(x);
  if (typeof x === "boolean") return x ? "True" : "False";
  return String(x);
}

/** sum() di Python 3.12 sui float: somma compensata di Neumaier, non la somma
 *  semplice di JavaScript (le medie del meteo cambierebbero all'ultima cifra). */
export function pySum(xs: Iterable<number>): number {
  let s = 0, c = 0;
  for (const x of xs) {
    const t = s + x;
    c += Math.abs(s) >= Math.abs(x) ? (s - t) + x : (x - t) + s;
    s = t;
  }
  return c && Number.isFinite(c) ? s + c : s;
}
