type FakeState = {
  userId?: string;
  failAt?: string;
  calls: string[];
  deleted: Set<string>;
  authDeleted: boolean;
  queryResults?: Record<string, { data: unknown; error: unknown }>;
  creditsConsumed?: number;
};

const state = (): FakeState => (globalThis as any).__operationState;

class Query implements PromiseLike<any> {
  table: string;
  action = "select";
  constructor(table: string) {
    this.table = table;
  }
  select() {
    return this;
  }
  maybeSingle() {
    return Promise.resolve({ data: null, error: null });
  }
  order() {
    return this;
  }
  limit() {
    return this;
  }
  in() {
    return this;
  }
  upsert() {
    return this;
  }
  delete() {
    this.action = "delete";
    return this;
  }
  eq(column: string, value: string) {
    if (column === "user_id" || column === "id") {
      state().calls.push(`filter:${this.table}:${column}:${value}`);
    }
    return this;
  }
  then(
    resolve: (value: any) => unknown,
    reject?: (reason: unknown) => unknown,
  ) {
    const s = state();
    const key = `${this.action}:${this.table}`;
    s.calls.push(key);
    if (s.failAt === key || s.failAt === `${this.action}:${this.table}`) {
      return Promise.reject(new Error("simulated query failure")).then(
        resolve,
        reject,
      );
    }
    if (this.action === "delete") s.deleted.add(this.table);
    const result = s.queryResults?.[this.table] ?? { data: null, error: null };
    return Promise.resolve({ ...result, count: 1 }).then(resolve, reject);
  }
}

export function createClient() {
  return {
    from: (table: string) => new Query(table),
    auth: {
      getUser: async (token: string) =>
        token === "valid" && state().userId && !state().authDeleted
          ? { data: { user: { id: state().userId } }, error: null }
          : { data: { user: null }, error: { message: "invalid" } },
      admin: {
        deleteUser: async (id: string) => {
          state().calls.push(`auth:delete:${id}`);
          if (state().failAt === "auth:delete") {
            return {
              error: { message: "simulated failure" },
            };
          }
          state().authDeleted = true;
          return { error: null };
        },
      },
    },
    rpc: async (name: string, args: unknown) => {
      state().calls.push(`rpc:${name}:${JSON.stringify(args)}`);
      const s = state() as any;
      const results = s.rpcResults ?? {};
      const result = results[name] ?? { data: null, error: null };
      if (name === "consume_ai_credit" && !result.error && result.data) {
        s.creditsConsumed = (s.creditsConsumed ?? 0) + 1;
      }
      if (name === "refund_ai_credit" && !result.error) {
        s.creditsConsumed = Math.max(0, (s.creditsConsumed ?? 0) - 1);
      }
      return result;
    },
  };
}
