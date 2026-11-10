import { assertEquals } from "./support.ts";

const state: any = {
  userId: "owner-1",
  calls: [],
  deleted: new Set(),
  authDeleted: false,
  rpcResults: {
    consume_ai_credit: { data: { source: "monthly" }, error: null },
    refund_ai_credit: { data: null, error: null },
  },
};
(globalThis as any).__operationState = state;
(Deno as any).env.set("SUPABASE_URL", "http://fake.invalid");
(Deno as any).env.set("SUPABASE_SERVICE_ROLE_KEY", "fake-service-key");
(Deno as any).env.set("ANTHROPIC_API_KEY", "fake-model-key");
let handler: (request: Request) => Promise<Response>;
(Deno as any).serve = (fn: typeof handler) => {
  handler = fn;
};
await import("../../functions/item-metadata/index.ts");

Deno.test("errore upstream dopo consume tenta refund; un fallimento refund non è recuperato dall'handler", async () => {
  state.calls = [];
  const response = await handler(
    new Request("http://local/item-metadata", {
      method: "POST",
      headers: {
        Authorization: "Bearer valid",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ image_base64: "AA", lang: "it" }),
    }),
  );
  assertEquals(response.status, 502);
  assertEquals(
    state.calls.filter((call: string) => call.includes("rpc:")).map((
      call: string,
    ) => call.split(":")[1]),
    [
      "consume_ai_credit",
      "refund_ai_credit",
    ],
  );
  state.rpcResults.refund_ai_credit = {
    data: null,
    error: { message: "fake refund outage" },
  };
  state.calls = [];
  const failedRefundResponse = await handler(
    new Request("http://local/item-metadata", {
      method: "POST",
      headers: {
        Authorization: "Bearer valid",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ image_base64: "AA", lang: "it" }),
    }),
  );
  assertEquals(failedRefundResponse.status, 502);
  assertEquals(
    state.calls.filter((call: string) => call.includes("refund_ai_credit"))
      .length,
    1,
  );
});

Deno.test("risposta 200 scartata e retry identico applicano due consume nel fake", async () => {
  state.calls = [];
  state.creditsConsumed = 0;
  (globalThis as any).__anthropicResponse = {
    content: [{ type: "text", text: "null" }],
    usage: { input_tokens: 1, output_tokens: 1 },
    stop_reason: "end_turn",
  };
  const makeRequest = () =>
    new Request("http://local/item-metadata", {
      method: "POST",
      headers: {
        Authorization: "Bearer valid",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ image_base64: "AA", lang: "it" }),
    });
  const first = await handler(makeRequest());
  assertEquals(first.status, 200);
  await first.text(); // Il test client scarta il contenuto: il 200 è perso per l'applicazione.
  const retried = await handler(makeRequest());
  assertEquals(retried.status, 200);
  assertEquals(state.creditsConsumed, 2);
  assertEquals(
    state.calls.filter((call: string) => call.includes("consume_ai_credit"))
      .length,
    2,
  );
  assertEquals(
    state.calls.some((call: string) => call.includes("refund_ai_credit")),
    false,
  );
  delete (globalThis as any).__anthropicResponse;
});
