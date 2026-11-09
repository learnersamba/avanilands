import { TrackedLink } from "@/components/enquiry/tracked-link";
import { getSiteSettings } from "@/lib/data";
import { whatsappLink } from "@/lib/format";

/** Floating WhatsApp button, bottom right on every page. */
export async function WhatsAppButton() {
  const settings = await getSiteSettings();
  if (!settings.whatsapp) return null;
  return (
    <TrackedLink
      channel="whatsapp"
      href={whatsappLink(settings.whatsapp, "Hello, I'd like to know about your land.")}
      target="_blank"
      rel="noopener"
      aria-label="Chat with us on WhatsApp"
      className="whatsapp-float fixed bottom-5 right-5 z-40 flex h-14 w-14 items-center justify-center rounded-full bg-[#25D366] text-white shadow-lg transition-transform hover:scale-105"
    >
      <svg viewBox="0 0 32 32" className="h-7 w-7 fill-current" aria-hidden>
        <path d="M16.04 3C9 3 3.3 8.7 3.3 15.74c0 2.25.59 4.45 1.71 6.38L3 29l7.06-1.85a12.7 12.7 0 0 0 5.98 1.52h.01c7.03 0 12.74-5.71 12.74-12.75C28.79 8.7 23.08 3 16.04 3Zm0 23.3h-.01a10.6 10.6 0 0 1-5.4-1.48l-.39-.23-4.19 1.1 1.12-4.08-.25-.42a10.56 10.56 0 0 1-1.62-5.65c0-5.86 4.77-10.62 10.64-10.62 2.84 0 5.5 1.1 7.51 3.12a10.55 10.55 0 0 1 3.11 7.51c0 5.86-4.77 10.63-10.62 10.63Zm5.83-7.96c-.32-.16-1.89-.93-2.18-1.04-.29-.1-.5-.16-.72.16-.21.32-.82 1.04-1 1.25-.19.21-.37.24-.69.08-.32-.16-1.35-.5-2.57-1.59-.95-.85-1.59-1.9-1.78-2.22-.19-.32-.02-.49.14-.65.14-.14.32-.37.48-.56.16-.18.21-.32.32-.53.1-.21.05-.4-.03-.56-.08-.16-.72-1.73-.98-2.37-.26-.62-.52-.54-.72-.55h-.61c-.21 0-.56.08-.85.4-.29.32-1.11 1.09-1.11 2.65s1.14 3.08 1.3 3.29c.16.21 2.24 3.42 5.43 4.8.76.33 1.35.52 1.81.67.76.24 1.45.21 2 .13.61-.09 1.89-.77 2.15-1.52.27-.75.27-1.39.19-1.52-.08-.13-.29-.21-.61-.37Z" />
      </svg>
    </TrackedLink>
  );
}
