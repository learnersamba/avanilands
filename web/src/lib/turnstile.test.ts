import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { verifyTurnstile } from "@/lib/turnstile";

function cloudflareSays(success: boolean) {
  const fetchMock = vi.fn(async () => Response.json({ success }));
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

describe("bot check", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it("refuses a missing token without asking Cloudflare", async () => {
    vi.stubEnv("TURNSTILE_SECRET_KEY", "secret");
    const fetchMock = cloudflareSays(true);
    expect(await verifyTurnstile(null, "1.2.3.4")).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("refuses a token Cloudflare rejects", async () => {
    vi.stubEnv("TURNSTILE_SECRET_KEY", "secret");
    cloudflareSays(false);
    expect(await verifyTurnstile("forged", null)).toBe(false);
  });

  it("accepts a token Cloudflare confirms, sending the visitor IP", async () => {
    vi.stubEnv("TURNSTILE_SECRET_KEY", "secret");
    const fetchMock = cloudflareSays(true);
    expect(await verifyTurnstile("good", "1.2.3.4")).toBe(true);
    const body = (
      fetchMock.mock.calls[0] as unknown as [string, RequestInit]
    )[1].body as URLSearchParams;
    expect(body.get("remoteip")).toBe("1.2.3.4");
  });

  it("refuses when Cloudflare can't be reached", async () => {
    vi.stubEnv("TURNSTILE_SECRET_KEY", "secret");
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new Error("offline");
      }),
    );
    vi.spyOn(console, "error").mockImplementation(() => {});
    expect(await verifyTurnstile("good", null)).toBe(false);
  });

  it("refuses everything in production when the secret is missing", async () => {
    vi.stubEnv("TURNSTILE_SECRET_KEY", "");
    vi.stubEnv("NODE_ENV", "production");
    vi.spyOn(console, "error").mockImplementation(() => {});
    expect(await verifyTurnstile("good", null)).toBe(false);
  });
});
