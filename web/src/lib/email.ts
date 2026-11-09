import "server-only";

import type { Email } from "@/lib/email-templates";

/**
 * Sends an email. Production: Resend (RESEND_API_KEY). Development: the
 * local Supabase mailbox, Mailpit (DEV_MAILPIT_URL, http://127.0.0.1:56424).
 * Never throws: a failed email must not fail the enquiry (it is already saved).
 */
export async function sendEmail(to: string[], email: Email, replyTo?: string | null): Promise<boolean> {
  if (to.length === 0) return false;
  const from = process.env.EMAIL_FROM ?? "Avanilands <enquiries@example.com>";
  try {
    if (process.env.RESEND_API_KEY) {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from, to, subject: email.subject, html: email.html, text: email.text, ...(replyTo && { reply_to: replyTo }) }),
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) console.error("Email (Resend) failed", response.status, await response.text());
      return response.ok;
    }
    if (process.env.DEV_MAILPIT_URL) {
      const [, name, address] = /^(.*?)\s*<(.+)>$/.exec(from) ?? [null, "", from];
      const response = await fetch(`${process.env.DEV_MAILPIT_URL}/api/v1/send`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          From: { Email: address, Name: name },
          To: to.map((Email) => ({ Email })),
          ...(replyTo && { ReplyTo: [{ Email: replyTo }] }),
          Subject: email.subject,
          Text: email.text,
          HTML: email.html,
        }),
        signal: AbortSignal.timeout(5_000),
      });
      return response.ok;
    }
    console.warn(`Email not sent (no RESEND_API_KEY or DEV_MAILPIT_URL): ${email.subject}`);
    return false;
  } catch (error) {
    console.error("Email failed", error);
    return false;
  }
}
