import { describe, expect, it } from "vitest";

import { bookingStatusLabel } from "@/lib/account/status";
import { type BookingEmailData, type BookingEvent, customerBookingEmail, salesBookingEmail } from "@/lib/booking-emails";

const data: BookingEmailData = {
  reference: "BKG-000003",
  name: "<b>Vani</b>",
  phone: "9876500011",
  email: "vani@example.com",
  message: "Visited on Saturday",
  agreedPrice: 4_500_000,
  bookingAmount: 100_000,
  amountReceived: 100_000,
  receivedOn: "2026-11-09",
  cancelledReason: "Loan not approved",
  property: { code: "AL-0002", title: "25 Cent Plot", url: "https://x/land/plot" },
  companyName: "Avanilands",
  companyPhone: "+91 90000 00000",
  adminUrl: "https://admin.x",
};

describe("booking emails", () => {
  it("sales get the request with ways to call back", () => {
    const email = salesBookingEmail(data);
    expect(email.subject).toBe("Booking request BKG-000003 — AL-0002 — <b>Vani</b>");
    expect(email.html).toContain("https://wa.me/919876500011");
    expect(email.html).not.toContain("<b>Vani</b>");
  });

  it("every customer step carries the payment-safety warning and no payment details", () => {
    const customerSteps: BookingEvent[] = ["requested", "approved", "payment_pending", "reserved", "completed", "cancelled"];
    for (const step of customerSteps) {
      const email = customerBookingEmail(data, step)!;
      expect(email.text).toContain("never send bank or payment details");
      expect(email.text.toLowerCase()).not.toMatch(/ifsc|account number|upi id/);
    }
  });

  it("each step says the right thing", () => {
    expect(customerBookingEmail(data, "approved")!.text).toContain("now reserved for you");
    expect(customerBookingEmail(data, "approved")!.text).toContain("₹45,00,000");
    expect(customerBookingEmail(data, "payment_pending")!.text).toContain("₹1,00,000");
    expect(customerBookingEmail(data, "reserved")!.text).toContain("on 9 Nov 2026");
    expect(customerBookingEmail(data, "cancelled")!.text).toContain("Reason: Loan not approved");
    expect(customerBookingEmail(data, "pending_approval")).toBeNull();
  });

  it("customers see plain status words", () => {
    expect(bookingStatusLabel("approved").label).toBe("Approved — reserved for you");
    expect(bookingStatusLabel("payment_pending").next).toContain("Never pay into a personal account");
    expect(bookingStatusLabel("cancelled").tone).toBe("closed");
  });
});
