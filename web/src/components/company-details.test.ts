import { describe, expect, it } from "vitest";

import { registrations, withoutFinalDot } from "@/components/company-details";

describe("company details", () => {
  it("drops one final full stop so a sentence can add its own", () => {
    expect(withoutFinalDot("Tirupa Technologies Pvt. Ltd.")).toBe("Tirupa Technologies Pvt. Ltd");
    expect(withoutFinalDot("Tirupa Technologies")).toBe("Tirupa Technologies");
  });

  it("lists only the registration numbers that are filled in", () => {
    expect(registrations({ gst_number: null, rera_number: null })).toEqual([]);
    expect(registrations({ gst_number: "37ABCDE1234F1Z5", rera_number: null })).toEqual([["GSTIN", "37ABCDE1234F1Z5"]]);
    expect(registrations({ gst_number: "37ABCDE1234F1Z5", rera_number: "P01100001234" })).toEqual([
      ["GSTIN", "37ABCDE1234F1Z5"],
      ["RERA", "P01100001234"],
    ]);
  });
});
