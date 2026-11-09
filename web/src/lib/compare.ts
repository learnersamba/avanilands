/**
 * Property comparison rules (Phase 12). Plain functions so they can be
 * unit-tested; the page and the compare tray share them.
 */
export const maxCompare = 3;

/** "al-0001,AL-0003,junk,AL-0001" → ["AL-0001", "AL-0003"] (at most 3, no repeats). */
export function parseCodes(
  value: string | string[] | undefined | null,
): string[] {
  const raw = (Array.isArray(value) ? value.join(",") : (value ?? "")).split(
    ",",
  );
  const codes: string[] = [];
  for (const item of raw) {
    const code = item.trim().toUpperCase();
    if (/^AL-\d{4,}$/.test(code) && !codes.includes(code)) codes.push(code);
    if (codes.length === maxCompare) break;
  }
  return codes;
}

export function compareHref(codes: string[]): string {
  return codes.length ? `/compare?codes=${codes.join(",")}` : "/compare";
}

type Priced = {
  price_type: string;
  price: number | null;
  area_sqft: number | null;
};

/** Rupees per sq ft, so plots in cents, acres and sq yd compare fairly. */
export function pricePerSqft(p: Priced): number | null {
  if (
    p.price_type !== "total" ||
    p.price == null ||
    p.area_sqft == null ||
    p.area_sqft <= 0
  )
    return null;
  return p.price / p.area_sqft;
}

/**
 * Which columns hold the best value in a row ("min" = lowest is best).
 * Nothing is marked when fewer than two have a value or all are equal.
 */
export function bestIndexes(
  values: (number | null)[],
  mode: "min" | "max",
): Set<number> {
  const known = values.filter((v): v is number => v != null);
  if (known.length < 2 || known.every((v) => v === known[0])) return new Set();
  const best = mode === "min" ? Math.min(...known) : Math.max(...known);
  return new Set(values.flatMap((v, i) => (v === best ? [i] : [])));
}

/** True when every column shows the same thing (the row can be hidden). */
export function allSame(values: string[]): boolean {
  return values.every((v) => v === values[0]);
}

type Located = { latitude: number | null; longitude: number | null };

/** Straight-line distance in km, or null without coordinates. */
export function distanceKm(a: Located, b: Located): number | null {
  if (
    a.latitude == null ||
    a.longitude == null ||
    b.latitude == null ||
    b.longitude == null
  )
    return null;
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.latitude)) *
      Math.cos(rad(b.latitude)) *
      Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

/** "about 12 km", "under 1 km" */
export function formatDistance(km: number): string {
  if (km < 1) return "under 1 km";
  return `about ${km < 10 ? km.toFixed(1).replace(/\.0$/, "") : Math.round(km)} km`;
}
