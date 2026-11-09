import { describe, expect, it } from "vitest";

import { safeNext } from "@/lib/account/paths";
import { readRecent } from "@/lib/account/recent";
import { enquiryStatusLabel, visitStatusLabel } from "@/lib/account/status";

describe("after signing in", () => {
  it("only returns to pages on this site", () => {
    expect(safeNext("/land/some-plot#visit")).toBe("/land/some-plot#visit");
    expect(safeNext("//evil.example")).toBe("/account");
    expect(safeNext("/\\evil.example")).toBe("/account");
    expect(safeNext("https://evil.example")).toBe("/account");
    expect(safeNext(null)).toBe("/account");
  });
});

describe("statuses customers see", () => {
  it("uses plain words and never staff jargon", () => {
    expect(enquiryStatusLabel("new").label).toBe("Received");
    expect(enquiryStatusLabel("follow_up").label).toBe("We're in touch");
    expect(enquiryStatusLabel("not_interested").label).toBe("Closed");
    expect(visitStatusLabel("requested").label).toBe("Waiting for confirmation");
    expect(visitStatusLabel("no_show").label).toBe("Missed");
  });
});

describe("recently viewed", () => {
  it("is simply empty where browser storage isn't available", () => {
    expect(readRecent()).toEqual([]);
  });
});
