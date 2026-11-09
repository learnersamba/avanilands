/**
 * Enquiry emails: one to the sales team, one to the customer (only when they
 * gave an email). Plain functions so they can be unit-tested.
 */

export type EnquiryEmailData = {
  reference: string;
  name: string;
  phone: string; // 10 digits
  email: string | null;
  preferredContact: "phone" | "whatsapp" | "email";
  message: string | null;
  property: { code: string; title: string; url: string } | null;
  companyName: string;
  companyPhone: string | null;
  adminUrl: string | null;
};

export type Email = { subject: string; text: string; html: string };

const contactLabel = { phone: "Phone call", whatsapp: "WhatsApp", email: "Email" } as const;

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function layout(title: string, body: string): string {
  return `<!doctype html><html><body style="margin:0;background:#faf8f3;font-family:Arial,Helvetica,sans-serif;color:#1e2422">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border:1px solid #e4dfd3;border-radius:12px">
<tr><td style="background:#1f4d3a;color:#ffffff;padding:18px 24px;border-radius:12px 12px 0 0;font-size:18px">${escapeHtml(title)}</td></tr>
<tr><td style="padding:24px;font-size:15px;line-height:1.6">${body}</td></tr>
</table></td></tr></table></body></html>`;
}

export function row(label: string, value: string): string {
  return `<tr><td style="padding:4px 12px 4px 0;color:#5b6770;vertical-align:top">${escapeHtml(label)}</td><td style="padding:4px 0">${value}</td></tr>`;
}

export function salesEnquiryEmail(d: EnquiryEmailData): Email {
  const about = d.property ? `${d.property.code} · ${d.property.title}` : "General enquiry";
  const subject = `New enquiry ${d.reference} — ${d.property?.code ?? "general"} — ${d.name}`;
  const phone = `+91 ${d.phone.slice(0, 5)} ${d.phone.slice(5)}`;
  const text = [
    `New enquiry ${d.reference}`,
    `About: ${about}`,
    `Name: ${d.name}`,
    `Phone: ${phone}`,
    d.email ? `Email: ${d.email}` : null,
    `Prefers: ${contactLabel[d.preferredContact]}`,
    d.message ? `Message: ${d.message}` : null,
    d.property ? `Property page: ${d.property.url}` : null,
    d.adminUrl ? `Open in admin: ${d.adminUrl}/enquiries` : null,
  ]
    .filter(Boolean)
    .join("\n");
  const html = layout(
    `New enquiry ${d.reference}`,
    `<table role="presentation" cellpadding="0" cellspacing="0">
${row("About", d.property ? `<a href="${escapeHtml(d.property.url)}">${escapeHtml(about)}</a>` : "General enquiry")}
${row("Name", `<strong>${escapeHtml(d.name)}</strong>`)}
${row("Phone", `<a href="tel:+91${d.phone}">${phone}</a> · <a href="https://wa.me/91${d.phone}">WhatsApp</a>`)}
${d.email ? row("Email", `<a href="mailto:${escapeHtml(d.email)}">${escapeHtml(d.email)}</a>`) : ""}
${row("Prefers", contactLabel[d.preferredContact])}
${d.message ? row("Message", escapeHtml(d.message).replace(/\n/g, "<br>")) : ""}
</table>
${d.adminUrl ? `<p style="margin-top:20px"><a href="${escapeHtml(d.adminUrl)}/enquiries" style="background:#1f4d3a;color:#ffffff;padding:10px 18px;border-radius:8px;text-decoration:none">Open in the admin panel</a></p>` : ""}`,
  );
  return { subject, text, html };
}

export function customerEnquiryEmail(d: EnquiryEmailData): Email {
  const about = d.property ? `${d.property.title} (${d.property.code})` : "your enquiry";
  const subject = `We received your enquiry ${d.reference} — ${d.companyName}`;
  const callUs = d.companyPhone ? ` If it's urgent, call us on ${d.companyPhone}.` : "";
  const text = [
    `Dear ${d.name},`,
    "",
    `Thank you for asking about ${about}. Your reference is ${d.reference}.`,
    `Our team will contact you soon by ${contactLabel[d.preferredContact].toLowerCase()}.${callUs}`,
    d.property ? `\nProperty page: ${d.property.url}` : null,
    "",
    `— ${d.companyName}`,
  ]
    .filter((line) => line !== null)
    .join("\n");
  const html = layout(
    "Thank you for your enquiry",
    `<p>Dear ${escapeHtml(d.name)},</p>
<p>Thank you for asking about ${d.property ? `<a href="${escapeHtml(d.property.url)}">${escapeHtml(about)}</a>` : "our land"}.
Your reference is <strong>${escapeHtml(d.reference)}</strong>.</p>
<p>Our team will contact you soon by ${escapeHtml(contactLabel[d.preferredContact].toLowerCase())}.${escapeHtml(callUs)}</p>
<p>— ${escapeHtml(d.companyName)}</p>`,
  );
  return { subject, text, html };
}
