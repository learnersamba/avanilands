/**
 * Site visit emails: to sales when a visit is requested, and to the customer
 * when it is requested, confirmed, moved, cancelled, and the day before.
 * Plain functions so they can be unit-tested.
 */
import { type Email, escapeHtml, layout, row } from "@/lib/email-templates";
import { formatSlot, formatVisitDate, googleCalendarLink } from "@/lib/site-visit";

export type SiteVisitEmailData = {
  reference: string;
  name: string;
  phone: string; // 10 digits
  email: string | null;
  visitors: number;
  visitDate: string; // YYYY-MM-DD
  slot: string; // HH:MM
  message: string | null;
  property: { code: string; title: string; url: string; place: string | null; mapsUrl: string | null };
  companyName: string;
  companyPhone: string | null;
  adminUrl: string | null;
};

export type CustomerVisitEvent = "requested" | "confirmed" | "rescheduled" | "cancelled" | "reminder";

const when = (d: SiteVisitEmailData) => `${formatVisitDate(d.visitDate, true)}, ${formatSlot(d.slot)}`;
const people = (n: number) => `${n} ${n === 1 ? "person" : "people"}`;
const mobile = (phone: string) => `+91 ${phone.slice(0, 5)} ${phone.slice(5)}`;

export function salesSiteVisitEmail(d: SiteVisitEmailData): Email {
  const subject = `Site visit request ${d.reference} — ${d.property.code} — ${formatVisitDate(d.visitDate)} ${formatSlot(d.slot)} — ${d.name}`;
  const text = [
    `New site visit request ${d.reference}`,
    `Property: ${d.property.code} · ${d.property.title}`,
    `When: ${when(d)} (${people(d.visitors)})`,
    `Name: ${d.name}`,
    `Phone: ${mobile(d.phone)}`,
    d.email ? `Email: ${d.email}` : null,
    d.message ? `Message: ${d.message}` : null,
    "Call the customer to confirm, then confirm it in the admin panel (they get an email).",
    d.adminUrl ? `Open in admin: ${d.adminUrl}/site-visits` : null,
  ]
    .filter(Boolean)
    .join("\n");
  const html = layout(
    `Site visit request ${d.reference}`,
    `<table role="presentation" cellpadding="0" cellspacing="0">
${row("Property", `<a href="${escapeHtml(d.property.url)}">${escapeHtml(`${d.property.code} · ${d.property.title}`)}</a>`)}
${row("When", `<strong>${escapeHtml(when(d))}</strong> · ${escapeHtml(people(d.visitors))}`)}
${row("Name", escapeHtml(d.name))}
${row("Phone", `<a href="tel:+91${d.phone}">${escapeHtml(mobile(d.phone))}</a> · <a href="https://wa.me/91${d.phone}">WhatsApp</a>`)}
${d.email ? row("Email", `<a href="mailto:${escapeHtml(d.email)}">${escapeHtml(d.email)}</a>`) : ""}
${d.message ? row("Message", escapeHtml(d.message).replace(/\n/g, "<br>")) : ""}
</table>
<p>Call the customer to confirm, then confirm it in the admin panel (they get an email).</p>
${d.adminUrl ? `<p><a href="${escapeHtml(d.adminUrl)}/site-visits" style="color:#1f4d3a;font-weight:bold">Open site visits</a></p>` : ""}`,
  );
  return { subject, text, html };
}

const customerCopy: Record<CustomerVisitEvent, { subject: string; title: string; lead: string }> = {
  requested: {
    subject: "We received your site visit request",
    title: "Site visit requested",
    lead: "Thank you for asking to visit. Our team will call you to confirm the time.",
  },
  confirmed: {
    subject: "Your site visit is confirmed",
    title: "Site visit confirmed",
    lead: "Your visit is confirmed. Our team member will meet you at the property.",
  },
  rescheduled: {
    subject: "Your site visit has a new time",
    title: "New time for your site visit",
    lead: "As agreed, your visit has moved to the time below.",
  },
  cancelled: {
    subject: "Your site visit is cancelled",
    title: "Site visit cancelled",
    lead: "Your site visit has been cancelled. If this is a mistake or you'd like a new time, just reply or call us.",
  },
  reminder: {
    subject: "Reminder: your site visit is tomorrow",
    title: "See you tomorrow",
    lead: "A reminder of your site visit tomorrow. If you can't make it, please let us know.",
  },
};

export function customerSiteVisitEmail(d: SiteVisitEmailData, event: CustomerVisitEvent): Email {
  const copy = customerCopy[event];
  const subject = `${copy.subject} — ${d.reference} — ${d.companyName}`;
  const active = event !== "cancelled";
  const calendar = active
    ? googleCalendarLink({
        date: d.visitDate,
        slot: d.slot,
        title: `Site visit: ${d.property.title} (${d.companyName})`,
        details: `Reference ${d.reference}. ${d.property.url}${d.companyPhone ? ` · Call ${d.companyPhone}` : ""}`,
        location: d.property.place,
      })
    : null;
  const callUs = d.companyPhone ? `Questions? Call us on ${d.companyPhone}.` : "Questions? Just reply to this email.";
  const text = [
    `Dear ${d.name},`,
    "",
    copy.lead,
    "",
    `Property: ${d.property.title} (${d.property.code})`,
    `${active ? "When" : "Was"}: ${when(d)}`,
    `Reference: ${d.reference}`,
    active && d.property.mapsUrl ? `Directions: ${d.property.mapsUrl}` : null,
    calendar ? `Add to Google Calendar: ${calendar}` : null,
    `Property page: ${d.property.url}`,
    "",
    callUs,
    `— ${d.companyName}`,
  ]
    .filter((line) => line !== null)
    .join("\n");
  const html = layout(
    copy.title,
    `<p>Dear ${escapeHtml(d.name)},</p>
<p>${escapeHtml(copy.lead)}</p>
<table role="presentation" cellpadding="0" cellspacing="0">
${row("Property", `<a href="${escapeHtml(d.property.url)}">${escapeHtml(`${d.property.title} (${d.property.code})`)}</a>`)}
${row(active ? "When" : "Was", `<strong>${escapeHtml(when(d))}</strong>`)}
${row("Reference", escapeHtml(d.reference))}
</table>
${active && d.property.mapsUrl ? `<p><a href="${escapeHtml(d.property.mapsUrl)}" style="color:#1f4d3a;font-weight:bold">Get directions</a></p>` : ""}
${calendar ? `<p><a href="${escapeHtml(calendar)}" style="color:#1f4d3a">Add to Google Calendar</a></p>` : ""}
<p>${escapeHtml(callUs)}</p>
<p>— ${escapeHtml(d.companyName)}</p>`,
  );
  return { subject, text, html };
}
