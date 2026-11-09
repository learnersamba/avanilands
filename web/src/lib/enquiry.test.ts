import { describe, expect, it } from "vitest";

import {
  customerEnquiryEmail,
  escapeHtml,
  salesEnquiryEmail,
} from "@/lib/email-templates";
import {
  enquirySchema,
  explainSubmitError,
  normalizeIndianMobile,
} from "@/lib/enquiry";

const valid = {
  name: "  Suresh Babu ",
  phone: "+91 90123 45678",
  email: "Suresh@Example.com",
  preferredContact: "phone",
  message: "",
  propertyId: "10000000-0000-4000-a000-000000000002",
  source: "property_page",
  idempotencyKey: "50000000-0000-4000-a000-000000000001",
};

describe("mobile numbers", () => {
  it("accepts common ways of writing an Indian mobile", () => {
    for (const input of [
      "9012345678",
      "+91 90123 45678",
      "091-2345-678".replace(/^0/, "9"),
      "09012345678",
      "919012345678",
    ]) {
      expect(normalizeIndianMobile(input)).toMatch(/^[6-9]\d{9}$/);
    }
    expect(normalizeIndianMobile("+91 90123 45678")).toBe("9012345678");
  });

  it("refuses landlines, short numbers and foreign numbers", () => {
    for (const input of [
      "12345",
      "5012345678",
      "+1 415 555 0100",
      "",
      "abcdefghij",
    ]) {
      expect(normalizeIndianMobile(input)).toBeNull();
    }
  });
});

describe("enquiry form rules", () => {
  it("cleans valid input", () => {
    const result = enquirySchema.parse(valid);
    expect(result).toMatchObject({
      name: "Suresh Babu",
      phone: "9012345678",
      email: "suresh@example.com",
      message: null,
    });
  });

  it("explains each problem", () => {
    const result = enquirySchema.safeParse({
      ...valid,
      name: "S",
      phone: "123",
      email: "nope",
    });
    expect(result.success).toBe(false);
    const fields = result.error!.issues.map((issue) => issue.path[0]);
    expect(fields).toEqual(expect.arrayContaining(["name", "phone", "email"]));
  });

  it("needs an email when email is the chosen contact method", () => {
    const result = enquirySchema.safeParse({
      ...valid,
      email: "",
      preferredContact: "email",
    });
    expect(result.success).toBe(false);
    expect(result.error!.issues[0].path).toEqual(["email"]);
  });

  it("general enquiries have no property", () => {
    expect(
      enquirySchema.parse({ ...valid, propertyId: "", source: "contact_page" })
        .propertyId,
    ).toBeNull();
  });

  it("refuses a missing double-submit key and unknown sources", () => {
    expect(
      enquirySchema.safeParse({ ...valid, idempotencyKey: "" }).success,
    ).toBe(false);
    expect(enquirySchema.safeParse({ ...valid, source: "spam" }).success).toBe(
      false,
    );
  });

  it("caps the message", () => {
    expect(
      enquirySchema.safeParse({ ...valid, message: "x".repeat(1001) }).success,
    ).toBe(false);
  });

  it("explains database refusals", () => {
    expect(explainSubmitError("rate_limited").message).toContain(
      "several enquiries",
    );
    expect(explainSubmitError("property_unavailable").message).toContain(
      "sold",
    );
    expect(explainSubmitError("invalid_phone").field).toBe("phone");
    expect(explainSubmitError("something else").message).toContain("try again");
  });
});

describe("emails", () => {
  const data = {
    reference: "ENQ-000011",
    name: "<b>Suresh</b>",
    phone: "9012345678",
    email: "suresh@example.com",
    preferredContact: "whatsapp" as const,
    message: "Call me\nafter 6",
    property: {
      code: "AL-0002",
      title: "25 Cent Plot",
      url: "https://x/land/plot",
    },
    companyName: "Avanilands",
    companyPhone: "+91 90000 00000",
    adminUrl: "https://admin.x",
  };

  it("sales email has everything needed to call back", () => {
    const email = salesEnquiryEmail(data);
    expect(email.subject).toBe(
      "New enquiry ENQ-000011 — AL-0002 — <b>Suresh</b>",
    );
    expect(email.text).toContain("+91 90123 45678");
    expect(email.html).toContain("https://wa.me/919012345678");
    expect(email.html).toContain("https://admin.x/enquiries");
  });

  it("customer email gives the reference", () => {
    const email = customerEnquiryEmail(data);
    expect(email.text).toContain("ENQ-000011");
    expect(email.text).toContain("by whatsapp");
  });

  it("visitor text cannot inject HTML", () => {
    expect(salesEnquiryEmail(data).html).not.toContain("<b>Suresh</b>");
    expect(escapeHtml(`"><script>`)).toBe("&quot;&gt;&lt;script&gt;");
  });
});
