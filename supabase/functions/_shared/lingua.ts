// La lingua dell'app, per i testi che le funzioni scrivono per l'utente. I
// prompt e i testi interni restano in italiano.
export type Lingua = "it" | "en";

/** Il campo `lang` del corpo: assente = italiano (le versioni vecchie dell'app),
 *  null se non e' una lingua ammessa. */
export function linguaDa(v: unknown): Lingua | null {
  if (v === undefined) return "it";
  return v === "it" || v === "en" ? v : null;
}
