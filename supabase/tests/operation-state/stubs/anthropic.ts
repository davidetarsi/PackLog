export default class Anthropic {
  static APIError = class extends Error {};
  messages = {
    create: async () => {
      const response = (globalThis as any).__anthropicResponse;
      if (response) return response;
      throw new Error("fake upstream unavailable");
    },
  };
  constructor(_options: unknown) {}
}
