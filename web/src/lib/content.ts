/**
 * Website content edited in the admin panel (Phase 14). The database is
 * checked when saving; here every value is read defensively and anything
 * missing or malformed falls back to the built-in text (content/site.ts),
 * so a content problem can never break a page.
 */
import {
  about,
  buyingSteps,
  faqs,
  hero,
  legal,
  trustPoints,
  verificationChecks,
  whyChooseUs,
} from "@/content/site";

export type IconItem = { icon: string; title: string; text: string };
export type TitledText = { title: string; text: string };
export type LegalKey = "terms" | "privacy" | "disclaimer";
export type LegalContent = {
  title: string;
  sections: { heading: string; text: string }[];
  final: boolean;
};

export type SiteContent = {
  hero: {
    eyebrow: string;
    title: string;
    subtitle: string;
    image_path: string | null;
  };
  trustPoints: IconItem[];
  whyUs: IconItem[];
  verification: string[];
  steps: TitledText[];
  about: {
    intro: string;
    mission: string;
    vision: string;
    values: TitledText[];
    image_path: string | null;
  };
  legal: Record<LegalKey, LegalContent>;
};

export type Faq = {
  id: string;
  question: string;
  answer: string;
  show_on_home: boolean;
  is_published?: boolean;
};
export type Testimonial = {
  id: string;
  name: string;
  place: string | null;
  quote: string;
  rating: number | null;
  photo_path: string | null;
  is_published?: boolean;
};
export type Banner = {
  id: string;
  title: string;
  text: string | null;
  link_url: string | null;
  link_label: string | null;
  image_path: string | null;
  starts_at?: string | null;
};

export const defaultContent: SiteContent = {
  hero: { ...hero, image_path: null },
  trustPoints: [...trustPoints],
  whyUs: [...whyChooseUs],
  verification: [...verificationChecks],
  steps: [...buyingSteps],
  about: {
    intro: about.intro,
    mission: about.mission,
    vision: about.vision,
    values: about.values,
    image_path: null,
  },
  legal: legal as Record<LegalKey, LegalContent>,
};

export const defaultFaqs: Faq[] = faqs.map((faq, index) => ({
  id: `default-${index}`,
  question: faq.q,
  answer: faq.a,
  show_on_home: index < 5,
}));

type Json = unknown;
const isObject = (v: Json): v is Record<string, Json> =>
  typeof v === "object" && v !== null && !Array.isArray(v);
const text = (v: Json, fallback: string): string =>
  typeof v === "string" && v.trim() !== "" ? v : fallback;
const optionalText = (v: Json): string | null =>
  typeof v === "string" && v.trim() !== "" ? v : null;
const imagePath = (v: Json): string | null =>
  typeof v === "string" && /^content\/[a-z0-9/_-]+\.(webp|jpg|png)$/.test(v)
    ? v
    : null;

function list<T>(v: Json, read: (item: Json) => T | null, fallback: T[]): T[] {
  if (!Array.isArray(v)) return fallback;
  const items = v.map(read).filter((item): item is T => item !== null);
  return items.length > 0 ? items : fallback;
}

const iconItem = (item: Json): IconItem | null =>
  isObject(item) && typeof item.title === "string" && item.title.trim()
    ? {
        icon: typeof item.icon === "string" ? item.icon : "badge",
        title: item.title,
        text: text(item.text, ""),
      }
    : null;
const titledText = (item: Json): TitledText | null =>
  isObject(item) && typeof item.title === "string" && item.title.trim()
    ? { title: item.title, text: text(item.text, "") }
    : null;

/** Database rows ({key, value}) → the content the pages show. */
export function parseContent(
  rows: { key: string; value: Json }[],
): SiteContent {
  const byKey = new Map(
    rows.map((row) => [row.key, isObject(row.value) ? row.value : {}]),
  );
  const get = (key: string) => byKey.get(key) ?? {};
  const d = defaultContent;
  const h = get("home.hero");
  const a = get("about");
  const legalOf = (key: LegalKey): LegalContent => {
    const v = get(`legal.${key}`);
    return {
      title: text(v.title, d.legal[key].title),
      sections: list(
        v.sections,
        (s) =>
          isObject(s) && typeof s.heading === "string" && s.heading.trim()
            ? { heading: s.heading, text: text(s.text, "") }
            : null,
        d.legal[key].sections,
      ),
      final: v.final === true,
    };
  };
  return {
    hero: {
      eyebrow: text(h.eyebrow, d.hero.eyebrow),
      title: text(h.title, d.hero.title),
      subtitle: text(h.subtitle, d.hero.subtitle),
      image_path: imagePath(h.image_path),
    },
    trustPoints: list(get("home.trust_points").items, iconItem, d.trustPoints),
    whyUs: list(get("home.why_us").items, iconItem, d.whyUs),
    verification: list(
      get("home.verification").items,
      (s) => optionalText(s),
      d.verification,
    ),
    steps: list(get("home.steps").items, titledText, d.steps),
    about: {
      intro: text(a.intro, d.about.intro),
      mission: text(a.mission, d.about.mission),
      vision: text(a.vision, d.about.vision),
      values: list(a.values, titledText, d.about.values),
      image_path: imagePath(a.image_path),
    },
    legal: {
      terms: legalOf("terms"),
      privacy: legalOf("privacy"),
      disclaimer: legalOf("disclaimer"),
    },
  };
}

/** "First paragraph\n\nSecond" → ["First paragraph", "Second"] (text only, never HTML). */
export function paragraphs(value: string): string[] {
  return value
    .split(/\n\s*\n|\r\n\s*\r\n/)
    .map((p) => p.trim())
    .filter(Boolean);
}

/** True for answers the owner still has to write (kept out of search results). */
export function isPlaceholder(value: string): boolean {
  return value.trim().startsWith("PLACEHOLDER");
}
