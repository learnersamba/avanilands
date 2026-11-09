import { describe, expect, it } from "vitest";

import { savedLandEmail } from "@/lib/notification-emails";

const base = {
  name: "Vani",
  title: "Price lowered: AL-0002",
  body: "25 Cent Plot: ₹45,00,000 → ₹42,00,000.",
  link: "/land/plot",
  siteUrl: "https://x.example",
  companyName: "Avanilands",
  companyPhone: "+91 90000 00000",
};

describe("saved-land email", () => {
  it("says what changed, links to the property and how to stop", () => {
    const email = savedLandEmail(base);
    expect(email.subject).toBe("Price lowered: AL-0002 — Avanilands");
    expect(email.text).toContain("₹45,00,000 → ₹42,00,000");
    expect(email.text).toContain("https://x.example/land/plot");
    expect(email.text).toContain("https://x.example/account");
    expect(email.html).toContain("Stop these emails");
  });

  it("works without a name or a page (taken off the website)", () => {
    const email = savedLandEmail({
      ...base,
      name: "",
      link: null,
      title: "AL-0003 is no longer on the website",
    });
    expect(email.text.startsWith("Hello,")).toBe(true);
    expect(email.text).not.toContain("See the property");
  });

  it("escapes anything that looks like HTML", () => {
    expect(
      savedLandEmail({ ...base, body: "<script>x</script>" }).html,
    ).not.toContain("<script>");
  });
});
