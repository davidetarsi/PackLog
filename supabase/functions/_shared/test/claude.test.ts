// claude.ts con un fetch finto: cosa si manda ad Anthropic, cosa torna.
// Uso: deno test --config ../item-metadata/deno.json --allow-env test/claude.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { claudeHttp, ErroreModello, MODELLO } from "../claude.ts";
import { bloccoImmagine } from "../immagine.ts";

function fetchFinto(status: number, corpo: unknown, inviati: unknown[]): typeof fetch {
  return async (_url, init) => {
    inviati.push(JSON.parse(String(init?.body)));
    return new Response(JSON.stringify(corpo), { status, headers: { "content-type": "application/json" } });
  };
}

const messaggio = (content: unknown[], stop_reason = "end_turn") => ({
  id: "msg_1", type: "message", role: "assistant", model: MODELLO, content, stop_reason,
  usage: { input_tokens: 10, output_tokens: 5 },
});

test("niente temperature, effort basso, il testo senza il ragionamento", async () => {
  const inviati: unknown[] = [];
  const chiedi = claudeHttp("k", fetchFinto(200, messaggio([
    { type: "thinking", thinking: "", signature: "s" },
    { type: "text", text: "[1," },
    { type: "text", text: "2]" },
  ]), inviati));
  const r = await chiedi("ciao", 2000);
  assert.equal(r.testo, "[1,2]");
  assert.equal(r.uso.input_tokens, 10);
  assert.deepEqual(inviati, [{
    model: "claude-haiku-5-5", max_tokens: 2000, output_config: { effort: "low" },
    messages: [{ role: "user", content: "ciao" }],
  }]);
});

test("senza ragionamento: thinking disabilitato nella richiesta", async () => {
  const inviati: unknown[] = [];
  await claudeHttp("k", fetchFinto(200, messaggio([{ type: "text", text: "ok" }]), inviati), 1000, false)("x", 10);
  assert.deepEqual((inviati[0] as Record<string, unknown>).thinking, { type: "disabled" });
});

test("rifiuto, risposta vuota ed errore HTTP diventano ErroreModello", async () => {
  await assert.rejects(claudeHttp("k", fetchFinto(200, messaggio([], "refusal"), []))("x", 10), ErroreModello);
  await assert.rejects(claudeHttp("k", fetchFinto(200, messaggio([], "max_tokens"), []))("x", 10), /nessun testo/);
  await assert.rejects(
    claudeHttp("k", fetchFinto(400, { type: "error", error: { type: "invalid_request_error", message: "no" } }, []))(
      "x", 10),
    (e: unknown) => e instanceof ErroreModello && e.status === 400,
  );
});

test("il tipo dell'immagine dai primi byte", () => {
  assert.equal(bloccoImmagine("/9j/4AAQ").source.media_type, "image/jpeg");
  assert.equal(bloccoImmagine("iVBORw0K").source.media_type, "image/png");
  assert.equal(bloccoImmagine("UklGRiQA").source.media_type, "image/webp");
});
