import "server-only";

/**
 * Cloudflare Turnstile bot check (decision 14). Returns true when the token
 * is valid. Without a secret key the check is skipped in development only;
 * in production a missing key refuses everything rather than letting bots in.
 */
export async function verifyTurnstile(token: string | null, ip: string | null): Promise<boolean> {
  const secret = process.env.TURNSTILE_SECRET_KEY;
  if (!secret) {
    if (process.env.NODE_ENV === "production") {
      console.error("TURNSTILE_SECRET_KEY is missing: enquiries are refused.");
      return false;
    }
    return true;
  }
  if (!token) return false;
  try {
    const body = new URLSearchParams({ secret, response: token, ...(ip && { remoteip: ip }) });
    const response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      body,
      signal: AbortSignal.timeout(8_000),
    });
    const result = (await response.json()) as { success?: boolean };
    return result.success === true;
  } catch (error) {
    console.error("Turnstile check failed", error);
    return false;
  }
}
