/**
 * Recently viewed properties, kept in this browser only (nothing is sent to
 * the server). Newest first, at most 12.
 */
const key = "bk-recently-viewed";
const max = 12;

export function readRecent(): string[] {
  try {
    const value = JSON.parse(localStorage.getItem(key) ?? "[]");
    return Array.isArray(value)
      ? value.filter((id): id is string => typeof id === "string").slice(0, max)
      : [];
  } catch {
    return [];
  }
}

export function addRecent(propertyId: string): void {
  try {
    localStorage.setItem(
      key,
      JSON.stringify(
        [propertyId, ...readRecent().filter((id) => id !== propertyId)].slice(
          0,
          max,
        ),
      ),
    );
  } catch {
    // Private mode or storage blocked: simply not remembered.
  }
}

export function clearRecent(): void {
  try {
    localStorage.removeItem(key);
  } catch {}
}
