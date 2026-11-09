import { describe, expect, it } from "vitest";

import {
  defaultContent,
  isPlaceholder,
  paragraphs,
  parseContent,
} from "@/lib/content";

describe("website content", () => {
  it("uses the built-in text when nothing is loaded", () => {
    expect(parseContent([])).toEqual(defaultContent);
  });

  it("takes edited text from the database", () => {
    const content = parseContent([
      {
        key: "home.hero",
        value: {
          eyebrow: "New",
          title: "Plots near the airport",
          subtitle: "Clear titles",
          image_path: "content/hero/a.webp",
        },
      },
      {
        key: "home.steps",
        value: { items: [{ title: "Call us", text: "Any time" }] },
      },
      {
        key: "legal.terms",
        value: {
          title: "Terms",
          sections: [{ heading: "One", text: "Text" }],
          final: true,
        },
      },
    ]);
    expect(content.hero.title).toBe("Plots near the airport");
    expect(content.hero.image_path).toBe("content/hero/a.webp");
    expect(content.steps).toEqual([{ title: "Call us", text: "Any time" }]);
    expect(content.legal.terms.final).toBe(true);
    expect(content.legal.privacy.final).toBe(false);
  });

  it("falls back piece by piece when content is malformed", () => {
    const content = parseContent([
      {
        key: "home.hero",
        value: {
          title: "",
          subtitle: 42,
          image_path: "https://evil.example/x.png",
        },
      },
      { key: "home.why_us", value: { items: "not a list" } },
      {
        key: "home.trust_points",
        value: { items: [{ title: "Only title" }, { nope: true }] },
      },
      { key: "about", value: null },
    ]);
    expect(content.hero.title).toBe(defaultContent.hero.title);
    expect(content.hero.subtitle).toBe(defaultContent.hero.subtitle);
    expect(content.hero.image_path).toBeNull();
    expect(content.whyUs).toEqual(defaultContent.whyUs);
    expect(content.trustPoints).toEqual([
      { icon: "badge", title: "Only title", text: "" },
    ]);
    expect(content.about).toEqual(defaultContent.about);
  });

  it("text becomes paragraphs, never HTML", () => {
    expect(paragraphs("First line\n\nSecond <b>bold</b>\n\n\n")).toEqual([
      "First line",
      "Second <b>bold</b>",
    ]);
    expect(isPlaceholder("PLACEHOLDER — write this")).toBe(true);
    expect(isPlaceholder("Real answer")).toBe(false);
  });
});
