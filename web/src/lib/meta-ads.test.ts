import { describe, expect, it } from "vitest";

import { attributionFromUrl, browserId, clickId, parseAttribution } from "@/lib/attribution";
import { adsAllowed, consentCookieValue, parseConsent, readCookie } from "@/lib/consent";
import { metaPhone, metaUserData, sha256 } from "@/lib/meta-events";

describe("consent", () => {
  it("reads only the current version", () => {
    expect(parseConsent(consentCookieValue("granted"))).toBe("granted");
    expect(parseConsent("denied.1")).toBe("denied");
    expect(parseConsent("granted.0")).toBeNull();
    expect(parseConsent("yes")).toBeNull();
    expect(parseConsent(undefined)).toBeNull();
  });

  it("allows ads only with a yes and no Global Privacy Control", () => {
    expect(adsAllowed("granted.1", false)).toBe(true);
    expect(adsAllowed("granted.1", true)).toBe(false);
    expect(adsAllowed("denied.1", false)).toBe(false);
    expect(adsAllowed(null, false)).toBe(false);
  });

  it("reads a cookie from a header", () => {
    expect(readCookie("a=1; al_consent=granted.1; _fbp=x", "al_consent")).toBe("granted.1");
    expect(readCookie("a=1", "al_consent")).toBeNull();
  });
});

describe("attribution", () => {
  const now = 1_764_000_000_000;

  it("keeps campaign tags and the click id from a landing address", () => {
    const url = new URL(
      "https://avanilands.in/land/x?utm_source=facebook&utm_campaign=vizag%20plots&fbclid=IwAR0abcdefghijk&name=Ravi",
    );
    expect(attributionFromUrl(url, now)).toEqual({
      utm_source: "facebook",
      utm_campaign: "vizag plots",
      fbclid: "IwAR0abcdefghijk",
      fbclid_at: now,
      landing_path: "/land/x",
    });
  });

  it("ignores addresses without campaign details", () => {
    expect(attributionFromUrl(new URL("https://avanilands.in/land?city=vizag"), now)).toBeUndefined();
  });

  it("accepts only known, limited fields from the form", () => {
    const parsed = parseAttribution(
      JSON.stringify({ utm_source: "x".repeat(500), phone: "9876543210", landing_path: "https://evil", fbclid: "<script>" }),
    );
    expect(parsed).toEqual({ utm_source: "x".repeat(100) });
    expect(parseAttribution("not json")).toEqual({});
    expect(parseAttribution(null)).toEqual({});
  });

  it("builds Meta's click id, preferring the cookie, and drops old clicks", () => {
    expect(clickId("fb.1.1700000000000.IwAR0abcdefghijk", {}, now)).toBe("fb.1.1700000000000.IwAR0abcdefghijk");
    expect(clickId(null, { fbclid: "IwAR0abcdefghijk", fbclid_at: now - 1000 }, now)).toBe(
      `fb.1.${now - 1000}.IwAR0abcdefghijk`,
    );
    expect(clickId(null, { fbclid: "IwAR0abcdefghijk", fbclid_at: now - 91 * 86_400_000 }, now)).toBeNull();
    expect(clickId("junk", {}, now)).toBeNull();
    expect(browserId("fb.1.1700000000000.123456789")).toBe("fb.1.1700000000000.123456789");
    expect(browserId("junk")).toBeNull();
  });
});

describe("Conversions API user data", () => {
  it("adds the country code to Indian mobiles", () => {
    expect(metaPhone("9876543210")).toBe("919876543210");
    expect(metaPhone("+91 98765 43210")).toBe("919876543210");
    expect(metaPhone("12345")).toBeNull();
  });

  it("hashes phone, email and country and never sends them in plain text", () => {
    const data = metaUserData({ phone: "9876543210", email: " Buyer@Example.com ", ip: "1.2.3.4", fbp: "fb.1.1.2" });
    expect(data.ph).toEqual([sha256("919876543210")]);
    expect(data.em).toEqual([sha256("buyer@example.com")]);
    expect(data.country).toEqual([sha256("in")]);
    expect(data.client_ip_address).toBe("1.2.3.4");
    expect(JSON.stringify(data)).not.toMatch(/9876543210|buyer@example/i);
  });
});
