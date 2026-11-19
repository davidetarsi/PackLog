import { assertEquals } from "./support.ts";
import {
  consumaCreditoAi,
  restituisciCreditoAi,
} from "../../functions/_shared/servizi.ts";

Deno.test("consumo usa una RPC priva di operation ID e ripete la RPC a ogni tentativo", async () => {
  const calls: { name: string; args: Record<string, unknown> }[] = [];
  const db = {
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      return { data: { source: "monthly" }, error: null };
    },
  };
  const first = await consumaCreditoAi(db, "user-fake");
  const retry = await consumaCreditoAi(db, "user-fake");
  assertEquals(first, { source: "monthly" });
  assertEquals(retry, { source: "monthly" });
  assertEquals(calls.length, 2);
  assertEquals(Object.keys(calls[0].args).sort(), ["p_now", "p_user_id"]);
  assertEquals(Object.keys(calls[1].args).sort(), ["p_now", "p_user_id"]);
});

Deno.test("timeout RPC dopo commit ambiguo: retry identico fa un secondo consumo nel fake", async () => {
  let creditsConsumed = 0;
  let firstCall = true;
  const db = {
    rpc: async (_name: string, _args: Record<string, unknown>) => {
      creditsConsumed += 1; // Il commit nel fake avviene prima della risposta RPC.
      if (firstCall) {
        firstCall = false;
        return {
          data: null,
          error: { message: "simulated response timeout after commit" },
        };
      }
      return { data: { source: "monthly" }, error: null };
    },
  };
  const first = await consumaCreditoAi(db, "user-fake");
  assertEquals(first instanceof Response && first.status, 500);
  const retry = await consumaCreditoAi(db, "user-fake");
  assertEquals(retry, { source: "monthly" });
  assertEquals(creditsConsumed, 2);
});

Deno.test("errore consume diventa 500; refund fallito è solo log e retry invia compensazione uguale", async () => {
  const calls: { name: string; args: Record<string, unknown> }[] = [];
  let failRefund = true;
  const db = {
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      if (name === "consume_ai_credit") {
        return {
          data: null,
          error: { message: "simulated" },
        };
      }
      return {
        data: null,
        error: failRefund ? { message: "simulated refund failure" } : null,
      };
    },
  };
  const consumption = await consumaCreditoAi(db, "user-fake");
  assertEquals(consumption instanceof Response && consumption.status, 500);
  const grant = { source: "bonus" as const, grant_id: "grant-fake" };
  await restituisciCreditoAi(db, "user-fake", grant);
  failRefund = false;
  await restituisciCreditoAi(db, "user-fake", grant);
  await restituisciCreditoAi(db, "user-fake", grant);
  assertEquals(calls.map((x) => x.name), [
    "consume_ai_credit",
    "refund_ai_credit",
    "refund_ai_credit",
    "refund_ai_credit",
  ]);
  assertEquals(calls[1].args, calls[2].args);
  assertEquals(calls[2].args, calls[3].args);
});
