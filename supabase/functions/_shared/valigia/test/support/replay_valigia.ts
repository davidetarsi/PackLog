// Riproduce gli output pubblici su input registrati, senza rete o nuove risposte AI.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { caricaArmadio, type RigaArmadio } from "../../capo.ts";
import { strategySlots } from "../../slots.ts";
import { strategySlotsMultitappa } from "../../tappe.ts";
import { motiviValigia, percheValigia, tagArmadio } from "../../motivi.ts";
import { postiApp } from "../../posti.ts";
import { promptValigia } from "../../prompt.ts";
import { uscitaApp } from "../../uscita.ts";

export type CasoReplay = Record<string, any>;
export type ModoArmadio = "vuoto" | "parziale" | "completo";
export const modiArmadio: ModoArmadio[] = ["vuoto", "parziale", "completo"];
export const righeArmadi: Record<string, RigaArmadio[]> = Object.fromEntries(
  JSON.parse(readFileSync(new URL("../oracolo_quantita.json", import.meta.url), "utf8"))
    .filter((c: any) => c.f === "carica_armadio").map((c: any) => [c.nome + ".json", c.args[0]]),
);

// Ordine delle proprieta' irrilevante; ordine dei capi e assegnazioni conservato.
function ordinato(v: any): any {
  if (Array.isArray(v)) return v.map(ordinato);
  if (v && typeof v === "object") return Object.fromEntries(Object.keys(v).sort().map((k) => [k, ordinato(v[k])]));
  return v;
}
export const impronta = (v: unknown): string => createHash("sha256").update(JSON.stringify(ordinato(v))).digest("hex");
export const chiaveCaso = (c: CasoReplay, modo: ModoArmadio): string => `${c.insieme}/${c.id}/${c.armadio}/${modo}`;

export function riproduciCaso(originale: CasoReplay, modo: ModoArmadio): Record<string, any> {
  if (String(originale.insieme).toLowerCase().includes("v4")) throw new Error("Set sigillato escluso");
  const c = structuredClone(originale), tutte = righeArmadi[c.armadio];
  if (!tutte) throw new Error(`Armadio sconosciuto: ${c.armadio}`);
  const righe = modo === "vuoto" ? [] : modo === "parziale" ? tutte.filter((_, i) => i % 2 === 0) : tutte;
  const items = caricaArmadio(righe);
  const valigia = c.tipo === "singola" ? strategySlots(c.grezzo, items, c.args)
    : strategySlotsMultitappa(c.grezzo, items, c.args);
  const { scenario: sc, meteo, geo } = c.viaggio;
  const viaggio = { ...sc, ...(sc.legs?.length ? {
    tappe: sc.legs.map((l: any) => ({ nome: l.destinazione, giorni: l.giorni, attivita: l.attivita })),
  } : { destinazione: { nome: sc.destinazione } }) };
  const v = { scenario: sc, meteo, slots: valigia }, tag = tagArmadio(righe);
  const motivi = motiviValigia(v, tag);
  const salvate = new Map(righe.map((r) => [String(r.id), r.quantity ?? null]));
  const uscita = uscitaApp(valigia, motivi as any, salvate, {
    viaggio, meteo, armadio: items.flatMap((g) => [g.sub_fine, g.sub_category]),
  });
  const prima = impronta(valigia);
  const proposte = postiApp(valigia, motivi as any, salvate, { viaggio, meteo, armadio: items });
  if (impronta(valigia) !== prima) throw new Error("Le proposte modificano la valigia");
  return { valigia, motivi, perche: percheValigia(v, tag), uscita, proposte,
    prompt: promptValigia(sc, geo, meteo) };
}
