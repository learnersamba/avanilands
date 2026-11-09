/** Where to go after signing in: only paths on this site (never "//evil.com"). */
export function safeNext(
  value: string | null | undefined,
  fallback = "/account",
): string {
  return value &&
    value.startsWith("/") &&
    !value.startsWith("//") &&
    !value.startsWith("/\\")
    ? value
    : fallback;
}
