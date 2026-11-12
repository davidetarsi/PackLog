import { assertEquals } from "./support.ts";

const state: any = {
  userId: "owner-1",
  calls: [],
  deleted: new Set(),
  authDeleted: false,
  rpcResults: {
    consume_ai_credit: { data: { source: "monthly" }, error: null },
  },
  queryResults: {
    items: {
      data: [{
        id: "item-1",
        name: "maglia",
        category: "vestiti",
        quantity: 1,
      }],
      error: null,
    },
  },
};
(globalThis as any).__operationState = state;
for (
  const [key, value] of Object.entries({
    SUPABASE_URL: "http://fake.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "fake-service-key",
    ANTHROPIC_API_KEY: "fake-model-key",
  })
) {
  (Deno as any).env.set(key, value);
}
(Deno as any).env.set("TYPESAFE_API_KEY", "fake-jev-key");
let handler: (request: Request) => Promise<Response>;
(Deno as any).serve = (fn: typeof handler) => {
  handler = fn;
};
await import("../../functions/pack-trip/index.ts");

Deno.test("trip non valido viene rifiutato prima del consumo", async () => {
  state.calls = [];
  const response = await handler(
    new Request("http://local/pack-trip", {
      method: "POST",
      headers: {
        Authorization: "Bearer valid",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        house_id: "00000000-0000-0000-0000-000000000001",
        lang: "it",
        trip: {},
      }),
    }),
  );
  assertEquals(response.status, 400);
  assertEquals(
    state.calls.some((call: string) => call.includes("consume_ai_credit")),
    false,
  );
});

Deno.test("query profili Jev che fallisce dopo consume fa rigettare handler senza refund", async () => {
  state.calls = [];
  state.creditsConsumed = 0;
  state.failAt = "select:item_jev_profiles";
  const request = new Request("http://local/pack-trip", {
    method: "POST",
    headers: {
      Authorization: "Bearer valid",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      house_id: "00000000-0000-0000-0000-000000000001",
      lang: "it",
      trip: {
        data_inizio: "2026-11-11",
        giorni: 1,
        destinazione: { nome: "Roma", paese: "Italia", lat: 41.9, lon: 12.5 },
        attivita: [],
        bagaglio: "zaino",
        alloggio: "hotel",
        lavatrice: false,
      },
    }),
  });
  let rejected = false;
  try {
    await handler(request);
  } catch {
    rejected = true;
  }
  assertEquals(rejected, true);
  assertEquals(state.creditsConsumed, 1);
  assertEquals(
    state.calls.some((call: string) => call.includes("refund_ai_credit")),
    false,
  );
  state.failAt = undefined;
});
