/**
 * Saved-land update emails (Phase 15). The text comes from the database
 * notification (title + body); this adds the greeting, link and how to stop.
 */
import { type Email, escapeHtml, layout } from "@/lib/email-templates";

export type SavedLandEmailData = {
  name: string;
  title: string;
  body: string | null;
  link: string | null; // website path, e.g. /land/…
  siteUrl: string;
  companyName: string;
  companyPhone: string | null;
};

export function savedLandEmail(d: SavedLandEmailData): Email {
  const url = d.link ? `${d.siteUrl}${d.link}` : null;
  const settings = `${d.siteUrl}/account`;
  const greeting = d.name.trim() ? `Dear ${d.name.trim()},` : "Hello,";
  const stop = `You get this because you saved this land on our website. To stop these emails, switch off "Email me when saved land changes" in My account: ${settings}`;
  const callUs = d.companyPhone
    ? `Questions? Call us on ${d.companyPhone}.`
    : "";
  const subject = `${d.title} — ${d.companyName}`;
  const text = [
    greeting,
    "",
    d.title,
    d.body ?? "",
    url ? `See the property: ${url}` : "",
    "",
    callUs,
    `— ${d.companyName}`,
    "",
    stop,
  ]
    .filter((line, i, all) => line !== "" || all[i - 1] !== "")
    .join("\n");
  const html = layout(
    d.title,
    `<p>${escapeHtml(greeting)}</p>
${d.body ? `<p>${escapeHtml(d.body)}</p>` : ""}
${url ? `<p><a href="${escapeHtml(url)}" style="color:#1f4d3a;font-weight:bold">See the property</a></p>` : ""}
${callUs ? `<p>${escapeHtml(callUs)}</p>` : ""}
<p>— ${escapeHtml(d.companyName)}</p>
<p style="color:#5b6770;font-size:12px">You get this because you saved this land on our website.
<a href="${escapeHtml(settings)}" style="color:#5b6770">Stop these emails in My account</a>.</p>`,
  );
  return { subject, text, html };
}
