import { createAdminClient } from "@/lib/supabase/admin";
import { createPublicClient } from "@/lib/supabase/public";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Public document download (decision 19). Documents live in a private
 * bucket; this sends a visitor to a link that works for 5 minutes, but only
 * for documents the admin made public on a published property.
 */
export async function GET(_request: Request, context: RouteContext<"/api/documents/[id]">) {
  const { id } = await context.params;
  const notFound = () => new Response("Document not found", { status: 404, headers: { "Cache-Control": "no-store" } });
  if (!uuid.test(id)) return notFound();

  // The public view only lists public documents of published properties.
  const { data: listed } = await createPublicClient()
    .from("public_property_documents")
    .select("id, title")
    .eq("id", id)
    .maybeSingle();
  if (!listed) return notFound();

  const admin = createAdminClient();
  const { data: document } = await admin
    .from("property_documents")
    .select("storage_path, mime_type")
    .eq("id", id)
    .single();
  if (!document) return notFound();

  const extension = document.mime_type === "application/pdf" ? "pdf" : document.mime_type.split("/")[1];
  const fileName = `${listed.title.replace(/[^\w\- ]+/g, "").trim() || "document"}.${extension}`;
  const { data: signed, error } = await admin.storage
    .from("property-documents")
    .createSignedUrl(document.storage_path, 300, { download: fileName });
  if (error || !signed) return new Response("Could not prepare the download", { status: 502 });

  return new Response(null, {
    status: 302,
    headers: { Location: signed.signedUrl, "Cache-Control": "no-store", "X-Robots-Tag": "noindex" },
  });
}
