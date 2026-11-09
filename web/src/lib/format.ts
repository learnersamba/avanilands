/** Display helpers shared by every page. Indian number formats throughout. */

export type AreaUnit = "sq_ft" | "sq_yd" | "sq_m" | "cent" | "gunta" | "acre";

const areaLabels: Record<AreaUnit, { one: string; many: string }> = {
  sq_ft: { one: "sq ft", many: "sq ft" },
  sq_yd: { one: "sq yd", many: "sq yd" },
  sq_m: { one: "sq m", many: "sq m" },
  cent: { one: "cent", many: "cents" },
  gunta: { one: "gunta", many: "guntas" },
  acre: { one: "acre", many: "acres" },
};

const indian = new Intl.NumberFormat("en-IN", { maximumFractionDigits: 2 });
const indianWhole = new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 });

export function formatNumber(value: number): string {
  return indian.format(value);
}

/** "25 cents", "1 acre", "200 sq yd". */
export function formatArea(value: number | null, unit: AreaUnit): string {
  if (value == null) return "—";
  const label = value === 1 ? areaLabels[unit].one : areaLabels[unit].many;
  return `${indian.format(value)} ${label}`;
}

/** "10,890 sq ft" — shown next to other units so land can be compared. */
export function formatSqft(value: number | null): string | null {
  return value == null ? null : `${indianWhole.format(Math.round(value))} sq ft`;
}

export function unitLabel(unit: AreaUnit): string {
  return areaLabels[unit].one;
}

/** ₹45,00,000 */
export function formatRupees(value: number): string {
  return `₹${indianWhole.format(Math.round(value))}`;
}

/** ₹45 L · ₹1.2 Cr · ₹85,000 — the short form used on cards. */
export function formatRupeesShort(value: number): string {
  const trim = (n: number) => n.toFixed(2).replace(/\.?0+$/, "");
  if (value >= 1_00_00_000) return `₹${trim(value / 1_00_00_000)} Cr`;
  if (value >= 1_00_000) return `₹${trim(value / 1_00_000)} L`;
  return formatRupees(value);
}

export const facingLabels: Record<string, string> = {
  north: "North",
  south: "South",
  east: "East",
  west: "West",
  north_east: "North-east",
  north_west: "North-west",
  south_east: "South-east",
  south_west: "South-west",
};

export const approvalLabels: Record<string, string> = {
  dtcp: "DTCP approved",
  vmrda: "VMRDA approved",
  hmda: "HMDA approved",
  apcrda: "APCRDA approved",
  panchayat: "Panchayat approved",
  rera: "RERA registered",
  other: "Approved",
  not_applicable: "Not applicable",
};

export const availabilityLabels = {
  available: "Available",
  reserved: "Reserved",
  sold: "Sold",
} as const;

export type Availability = keyof typeof availabilityLabels;

/** Digits only, for tel: and wa.me links. */
export function digits(value: string): string {
  return value.replace(/\D/g, "");
}

export function whatsappLink(number: string, message?: string): string {
  const text = message ? `?text=${encodeURIComponent(message)}` : "";
  return `https://wa.me/${digits(number)}${text}`;
}

/** "512 KB", "1.5 MB". */
export function formatBytes(bytes: number): string {
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1).replace(/\.0$/, "")} MB`;
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}
