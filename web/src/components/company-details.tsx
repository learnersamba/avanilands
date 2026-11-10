import type { SiteSettings } from "@/lib/data";

/** "Tirupa Technologies Pvt. Ltd." → no trailing full stop, so a sentence can add its own. */
export function withoutFinalDot(text: string) {
  return text.replace(/\.$/, "");
}

/** The registration numbers that are filled in, e.g. [["GSTIN", "37ABC…"], ["RERA", "P0110…"]]. */
export function registrations(settings: Pick<SiteSettings, "gst_number" | "rera_number">) {
  return [
    ["GSTIN", settings.gst_number],
    ["RERA", settings.rera_number],
  ].filter((entry): entry is [string, string] => Boolean(entry[1]));
}

/** Who owns the brand: legal name, registered office and registration numbers. */
export function CompanyDetails({
  settings,
  className = "",
}: {
  settings: SiteSettings;
  className?: string;
}) {
  const numbers = registrations(settings);
  return (
    <div className={`space-y-1 text-sm leading-relaxed ${className}`}>
      <p>
        <span className="font-semibold">{settings.company_name}</span> is a brand of{" "}
        <span className="font-semibold">{withoutFinalDot(settings.legal_name)}</span>.
      </p>
      {settings.registered_address && <p>Registered office: {settings.registered_address}</p>}
      {numbers.length > 0 && (
        <p>{numbers.map(([label, value]) => `${label}: ${value}`).join(" · ")}</p>
      )}
    </div>
  );
}
