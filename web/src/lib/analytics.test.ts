import { describe, expect, it } from "vitest";

import { deviceOf, isBot, pageKey, referrerHost, searchFilters, trackablePath } from "@/lib/analytics";

const chrome = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";
const android = "Mozilla/5.0 (Linux; Android 14; SM-A156E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36";
const iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1";
const tablet = "Mozilla/5.0 (Linux; Android 13; SM-X200) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";

describe("who is counted", () => {
  it("counts people's browsers", () => {
    for (const ua of [chrome, android, iphone, tablet]) expect(isBot(ua)).toBe(false);
  });

  it("skips bots, link previews and scripts", () => {
    for (const ua of [
      "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
      "facebookexternalhit/1.1",
      "WhatsApp/2.23.20.0",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/141.0.0.0 Safari/537.36",
      "curl/8.5.0",
      "",
      null,
    ]) {
      expect(isBot(ua)).toBe(true);
    }
  });

  it("tells phones, tablets and computers apart", () => {
    expect(deviceOf(android)).toBe("mobile");
    expect(deviceOf(iphone)).toBe("mobile");
    expect(deviceOf(tablet)).toBe("tablet");
    expect(deviceOf("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)")).toBe("tablet");
    expect(deviceOf(chrome)).toBe("desktop");
  });
});

describe("where a visit came from", () => {
  const own = ["avanilands.in", "localhost:3100"];

  it("keeps only the domain", () => {
    expect(referrerHost("https://www.google.co.in/search?q=plots+vizag", own)).toBe("www.google.co.in");
    expect(referrerHost("https://l.facebook.com/l.php?u=secret", own)).toBe("l.facebook.com");
  });

  it("ignores our own pages, nothing and junk", () => {
    expect(referrerHost("https://avanilands.in/land", own)).toBeNull();
    expect(referrerHost("http://localhost:3100/", own)).toBeNull();
    expect(referrerHost("", own)).toBeNull();
    expect(referrerHost(null, own)).toBeNull();
    expect(referrerHost("not a url", own)).toBeNull();
    expect(referrerHost("javascript:alert(1)", own)).toBeNull();
  });

  it("recognises the WhatsApp app", () => {
    expect(referrerHost("android-app://com.whatsapp/", own)).toBe("whatsapp.com");
  });
});

describe("which pages are counted", () => {
  it("keeps the address without the query", () => {
    expect(trackablePath("/land/plot-in-vizag?utm=x#photos")).toBe("/land/plot-in-vizag");
    expect(trackablePath("/about/")).toBe("/about");
    expect(trackablePath("/")).toBe("/");
  });

  it("skips previews, API calls and odd input", () => {
    expect(trackablePath("/preview/home")).toBeNull();
    expect(trackablePath("/api/track")).toBeNull();
    expect(trackablePath("//evil.example")).toBeNull();
    expect(trackablePath("https://evil.example/")).toBeNull();
    expect(trackablePath(42)).toBeNull();
    expect(trackablePath(`/${"a".repeat(400)}`)).toBeNull();
  });

  it("reads searched places and land types (both list styles)", () => {
    expect(searchFilters("city=vizianagaram,visakhapatnam&type=plots&type=farm-land&min=100")).toEqual({
      cities: ["visakhapatnam", "vizianagaram"],
      types: ["farm-land", "plots"],
    });
    expect(searchFilters("city=<script>")).toEqual({ cities: [], types: [] });
    expect(searchFilters(null)).toEqual({ cities: [], types: [] });
  });

  it("counts a new search, not paging or sorting", () => {
    const a = pageKey("/land", "city=visakhapatnam&sort=price_asc");
    expect(pageKey("/land", "city=visakhapatnam&page=2")).toBe(a);
    expect(pageKey("/land", "city=anakapalli")).not.toBe(a);
    expect(pageKey("/about", "x=1")).toBe("/about");
  });
});
