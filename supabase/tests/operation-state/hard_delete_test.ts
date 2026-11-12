import { assertEquals } from "./support.ts";

type State = {
  userId: string;
  failAt?: string;
  calls: string[];
  deleted: Set<string>;
  authDeleted: boolean;
};
const state: State = {
  userId: "owner-1",
  calls: [],
  deleted: new Set(),
  authDeleted: false,
};
(globalThis as any).__operationState = state;
(Deno as any).env.set("SUPABASE_URL", "http://fake.invalid");
(Deno as any).env.set("SUPABASE_SERVICE_ROLE_KEY", "fake-service-key");
let handler: (request: Request) => Promise<Response>;
(Deno as any).serve = (fn: typeof handler) => {
  handler = fn;
};
await import("../../functions/hard-delete-account/index.ts");

const post = (token = "valid") =>
  new Request("http://local/hard-delete-account", {
    method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });

Deno.test("JWT determina il proprietario; un token invalido non avvia cancellazioni", async () => {
  state.calls = [];
  state.deleted.clear();
  state.authDeleted = false;
  const response = await handler(post("other"));
  assertEquals(response.status, 401);
  assertEquals(state.calls, []);
});

Deno.test("errore su public.users è ignorato; deleteAuth completa e retry riparte", async () => {
  state.calls = [];
  state.deleted.clear();
  state.authDeleted = false;
  state.failAt = "delete:users";
  const first = await handler(post());
  assertEquals(first.status, 200); // Il codice attuale ignora l'errore di public.users.
  assertEquals(state.authDeleted, true);
  assertEquals(
    state.calls.filter((call) => call.startsWith("filter:")).every((call) =>
      call.endsWith(":owner-1")
    ),
    true,
  );
  assertEquals(
    state.calls.filter((call) => call.startsWith("filter:")).length,
    7,
  );
  state.failAt = "delete:trips";
  state.calls = [];
  state.deleted.clear();
  state.authDeleted = false;
  const interrupted = await handler(post());
  assertEquals(interrupted.status, 500);
  assertEquals(state.authDeleted, false);
  assertEquals(state.deleted.has("items"), true);
  assertEquals(state.deleted.has("trips"), false);
  state.failAt = undefined;
  const retry = await handler(post());
  assertEquals(retry.status, 200);
  assertEquals(state.authDeleted, true);
});

Deno.test("errore auth dopo le tabelle lascia dati cancellati e retry non è idempotente sul risultato", async () => {
  state.failAt = "auth:delete";
  state.calls = [];
  state.deleted.clear();
  state.authDeleted = false;
  const first = await handler(post());
  assertEquals(first.status, 500);
  assertEquals(state.deleted.has("users"), true);
  assertEquals(state.authDeleted, false);
  state.failAt = undefined;
  state.calls = [];
  state.deleted.clear();
  const retry = await handler(post());
  assertEquals(retry.status, 200);
  assertEquals(state.authDeleted, true);
  assertEquals((await handler(post())).status, 401); // Il fake Auth revoca il JWT dopo deleteUser.
});

Deno.test("interruzione a ogni DELETE dati lascia il prefisso già cancellato e auth intatto", async () => {
  const ordered = [
    "items",
    "spaces",
    "luggages",
    "valigia_modifiche",
    "trips",
    "houses",
  ];
  for (const [index, table] of ordered.entries()) {
    state.failAt = `delete:${table}`;
    state.calls = [];
    state.deleted.clear();
    state.authDeleted = false;
    const response = await handler(post());
    assertEquals(response.status, 500);
    assertEquals([...state.deleted], ordered.slice(0, index));
    assertEquals(state.authDeleted, false);
  }
});
