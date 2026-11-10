export function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `atteso ${JSON.stringify(expected)}, ricevuto ${JSON.stringify(actual)}`,
    );
  }
}
