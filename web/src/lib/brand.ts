/** "Avanilands" → ["AVANI", "LANDS"]: the wordmark sets the last part in gold. */
export function splitBrandName(name: string): [string, string] {
  const upper = name.toUpperCase();
  return upper.endsWith("LANDS") && upper.length > 5 ? [upper.slice(0, -5), "LANDS"] : [upper, ""];
}
