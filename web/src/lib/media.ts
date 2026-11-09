import { env } from "@/lib/env";

/** Public URL of a file in a public Storage bucket. */
export function storageUrl(bucket: "property-media" | "site-assets", path: string): string {
  return `${env.supabaseUrl}/storage/v1/object/public/${bucket}/${path
    .split("/")
    .map(encodeURIComponent)
    .join("/")}`;
}

export function mediaUrl(path: string): string {
  return storageUrl("property-media", path);
}

/** srcSet for the three photo sizes (400 / 1200 / 2000 px wide for 4:3 photos). */
export function photoSrcSet(photo: { thumb: string; medium: string; large: string }): string {
  return `${mediaUrl(photo.thumb)} 400w, ${mediaUrl(photo.medium)} 1200w, ${mediaUrl(photo.large)} 2000w`;
}
