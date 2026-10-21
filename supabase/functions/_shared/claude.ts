// Il modello delle Edge Functions AI (item-metadata, pack-trip, openai-proxy):
// Claude Haiku 5.5, con la chiave lato server. Qui l'unica chiamata vera; il
// resto del codice riceve una funzione `(contenuto, max_tokens) -> testo`, cosi'
// i test girano con un modello finto.
//
// Haiku 5.5 rifiuta temperature/top_p diversi dal predefinito (400) e pensa
// prima di rispondere: effort "low" tiene corto il ragionamento, e i token del
// ragionamento rientrano in max_tokens, per questo i tetti sono larghi.
import Anthropic from "@anthropic-ai/sdk";

export const MODELLO = "claude-haiku-5-5";
export const EFFORT = "low";

/** Il messaggio dell'utente: testo, oppure blocchi (testo + immagine). */
export type Contenuto = string | Anthropic.ContentBlockParam[];

export interface Risposta {
  testo: string;
  uso: Record<string, unknown>;
}

export type ChiediClaude = (contenuto: Contenuto, maxTokens: number) => Promise<Risposta>;

/** Errore del modello; `status` e' quello HTTP di Anthropic, se c'e'. */
export class ErroreModello extends Error {
  constructor(messaggio: string, readonly status?: number) {
    super(messaggio);
  }
}

/** Con `ragiona` false il modello risponde senza ragionare prima (thinking
 *  disabilitato, ammesso a effort basso): meno token in uscita. */
export function claudeHttp(chiave: string, fetchFn?: typeof fetch, timeoutMs = 120000, ragiona = true): ChiediClaude {
  const client = new Anthropic({ apiKey: chiave, fetch: fetchFn, timeout: timeoutMs, maxRetries: 1 });
  return async (contenuto, maxTokens) => {
    let m: Anthropic.Message;
    try {
      m = await client.messages.create({
        model: MODELLO,
        max_tokens: maxTokens,
        output_config: { effort: EFFORT },
        ...(ragiona ? {} : { thinking: { type: "disabled" as const } }),
        messages: [{ role: "user", content: contenuto }],
      });
    } catch (e) {
      if (e instanceof Anthropic.APIError) {
        throw new ErroreModello(`${MODELLO}: ${e.message.slice(0, 300)}`, e.status);
      }
      throw e;
    }
    const uso = { ...m.usage, model: MODELLO, stop_reason: m.stop_reason };
    // Per misurare il costo vero di ogni chiamata (log delle Edge Functions).
    console.log("[claude] uso", JSON.stringify(uso));
    if (m.stop_reason === "refusal") throw new ErroreModello(`${MODELLO}: refusal`);
    const testo = m.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
    if (!testo) throw new ErroreModello(`${MODELLO}: nessun testo (stop_reason ${m.stop_reason})`);
    return { testo, uso };
  };
}
