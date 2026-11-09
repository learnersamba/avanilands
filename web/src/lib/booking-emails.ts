/**
 * Booking emails: sales when a customer asks to book, and the customer at
 * each step. Payment details are NEVER put in an email (fraud protection);
 * every customer email says so.
 */
import { type Email, escapeHtml, layout, row } from "@/lib/email-templates";
import { formatRupees } from "@/lib/format";

/** "2026-11-09" → "9 Nov 2026" */
const formatDay = (date: string) =>
  new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${date}T00:00:00Z`));

export type BookingEvent =
  | "requested"
  | "pending_approval"
  | "approved"
  | "payment_pending"
  | "reserved"
  | "completed"
  | "cancelled";

export type BookingEmailData = {
  reference: string;
  name: string;
  phone: string;
  email: string | null;
  message: string | null;
  agreedPrice: number | null;
  bookingAmount: number | null;
  amountReceived: number | null;
  receivedOn: string | null; // YYYY-MM-DD
  cancelledReason: string | null;
  property: { code: string; title: string; url: string };
  companyName: string;
  companyPhone: string | null;
  adminUrl: string | null;
};

const mobile = (phone: string) => `+91 ${phone.slice(0, 5)} ${phone.slice(5)}`;

export function salesBookingEmail(d: BookingEmailData): Email {
  const subject = `Booking request ${d.reference} — ${d.property.code} — ${d.name}`;
  const text = [
    `New booking request ${d.reference} from the website`,
    `Property: ${d.property.code} · ${d.property.title}`,
    `Name: ${d.name}`,
    `Phone: ${mobile(d.phone)}`,
    d.email ? `Email: ${d.email}` : null,
    d.message ? `Message: ${d.message}` : null,
    "Call the customer, then send it for approval in the admin panel.",
    d.adminUrl ? `Open in admin: ${d.adminUrl}/bookings` : null,
  ]
    .filter(Boolean)
    .join("\n");
  const html = layout(
    `Booking request ${d.reference}`,
    `<table role="presentation" cellpadding="0" cellspacing="0">
${row("Property", `<a href="${escapeHtml(d.property.url)}">${escapeHtml(`${d.property.code} · ${d.property.title}`)}</a>`)}
${row("Name", escapeHtml(d.name))}
${row("Phone", `<a href="tel:+91${d.phone}">${escapeHtml(mobile(d.phone))}</a> · <a href="https://wa.me/91${d.phone}">WhatsApp</a>`)}
${d.email ? row("Email", `<a href="mailto:${escapeHtml(d.email)}">${escapeHtml(d.email)}</a>`) : ""}
${d.message ? row("Message", escapeHtml(d.message).replace(/\n/g, "<br>")) : ""}
</table>
<p>Call the customer, then send it for approval in the admin panel.</p>
${d.adminUrl ? `<p><a href="${escapeHtml(d.adminUrl)}/bookings" style="color:#1f4d3a;font-weight:bold">Open bookings</a></p>` : ""}`,
  );
  return { subject, text, html };
}

/** Customer emails, by step. Null for steps the customer isn't emailed about. */
export function customerBookingEmail(
  d: BookingEmailData,
  event: BookingEvent,
): Email | null {
  const money = (value: number | null) =>
    value == null ? "" : formatRupees(value);
  const copy: Partial<
    Record<BookingEvent, { subject: string; title: string; lines: string[] }>
  > = {
    requested: {
      subject: "We received your booking request",
      title: "Booking request received",
      lines: [
        `Thank you for choosing ${d.property.title}. Your booking request ${d.reference} is with our team.`,
        "We'll call you to go over the price and the next steps. The property is reserved for you only once we approve the booking.",
      ],
    },
    approved: {
      subject: "Your booking is approved — the property is reserved for you",
      title: "Booking approved",
      lines: [
        `Good news: your booking ${d.reference} is approved and ${d.property.title} (${d.property.code}) is now reserved for you.`,
        d.agreedPrice ? `Agreed price: ${money(d.agreedPrice)}.` : "",
        "Our team will call you about the booking amount.",
      ],
    },
    payment_pending: {
      subject: "Booking amount for your property",
      title: "Booking amount",
      lines: [
        `To keep ${d.property.code} reserved, the booking amount is ${money(d.bookingAmount)}.`,
        "Our team will call you from our official number to share how to pay.",
      ],
    },
    reserved: {
      subject: "Payment received — thank you",
      title: "Payment received",
      lines: [
        `We received ${money(d.amountReceived)}${d.receivedOn ? ` on ${formatDay(d.receivedOn)}` : ""} for booking ${d.reference}. Thank you!`,
        `${d.property.title} (${d.property.code}) stays reserved for you. Next we'll prepare the documents for registration.`,
      ],
    },
    completed: {
      subject: "Congratulations on your new land",
      title: "Sale completed",
      lines: [
        `Congratulations! The sale of ${d.property.title} (${d.property.code}) is complete.`,
        "Thank you for buying with us. Keep this email with your documents.",
      ],
    },
    cancelled: {
      subject: "Your booking is cancelled",
      title: "Booking cancelled",
      lines: [
        `Your booking ${d.reference} for ${d.property.title} (${d.property.code}) has been cancelled.`,
        d.cancelledReason ? `Reason: ${d.cancelledReason}` : "",
        "If you have questions, please call us.",
      ],
    },
  };
  const step = copy[event];
  if (!step) return null;
  const safety =
    "For your safety: we never send bank or payment details by email or SMS, and never ask you to pay into a personal account. If anyone does, call us before paying.";
  const callUs = d.companyPhone
    ? `Questions? Call us on ${d.companyPhone}.`
    : "Questions? Reply to this email.";
  const lines = step.lines.filter(Boolean);
  const subject = `${step.subject} — ${d.reference} — ${d.companyName}`;
  const text = [
    `Dear ${d.name},`,
    "",
    ...lines,
    "",
    `Property page: ${d.property.url}`,
    "",
    safety,
    callUs,
    `— ${d.companyName}`,
  ].join("\n");
  const html = layout(
    step.title,
    `<p>Dear ${escapeHtml(d.name)},</p>
${lines.map((line) => `<p>${escapeHtml(line)}</p>`).join("\n")}
<p><a href="${escapeHtml(d.property.url)}" style="color:#1f4d3a">View the property</a></p>
<p style="padding:12px;background:#fff7e6;border-radius:8px;font-size:13px">${escapeHtml(safety)}</p>
<p>${escapeHtml(callUs)}</p>
<p>— ${escapeHtml(d.companyName)}</p>`,
  );
  return { subject, text, html };
}
