/**
 * Built-in website copy. Since Phase 14 the team edits this in the admin
 * panel (Website content) and the website reads it from the database; this
 * file is only the fallback if that content can't be loaded, and the
 * starting text the database was filled with. PLACEHOLDER text is marked
 * for the owner to replace or confirm.
 */

/** Starting values for the brand details; the Super Admin edits them in Settings. */
export const brand = {
  tagline: "Find Your Space. Build Your Future.",
  descriptor: "Real Estate & Property Platform",
  parentCompany: "Tirupa Technologies Pvt. Ltd.",
};

export const hero = {
  eyebrow: "Verified land · Andhra Pradesh",
  title: "Own verified land, directly from us",
  subtitle:
    "Approved plots, farm land and agricultural land with clear titles. No brokers, no middlemen — just honest land and a team that walks the site with you.",
};

export const trustPoints = [
  { icon: "shield", title: "Clear titles", text: "Every document checked before we list" },
  { icon: "stamp", title: "Approved layouts", text: "DTCP, VMRDA and RERA where applicable" },
  { icon: "handshake", title: "No brokers", text: "You deal with us directly" },
  { icon: "map", title: "Site visits arranged", text: "We show you the land in person" },
] as const;

export const whyChooseUs = [
  {
    icon: "badge",
    title: "We own what we sell",
    text: "Every property on this website belongs to us. No third-party listings, no surprises about who you are dealing with.",
  },
  {
    icon: "file",
    title: "Paperwork you can check",
    text: "Title, encumbrance, approvals and survey details are shared before you pay anything.",
  },
  {
    icon: "ruler",
    title: "Measured and marked",
    text: "Boundaries, dimensions and road widths are stated exactly — what you see is what you register.",
  },
  {
    icon: "users",
    title: "One team, start to finish",
    text: "The same people answer your enquiry, show you the site and help with registration.",
  },
] as const;

export const verificationChecks = [
  "Title deed and link documents traced back at least 30 years",
  "Encumbrance certificate (EC) — no loans or disputes on the land",
  "Survey number, extent and boundaries matched with revenue records",
  "Layout and building approvals (DTCP / VMRDA / RERA) where they apply",
  "Physical inspection: access road, water and power on site",
];

export const buyingSteps = [
  { title: "Enquire", text: "Ask about any property by phone, WhatsApp or the enquiry form." },
  { title: "Visit the site", text: "We arrange a visit and walk the land with you." },
  { title: "Book", text: "Reserve the property with a booking amount once you are sure." },
  { title: "Documentation", text: "We share all documents for your lawyer to verify." },
  { title: "Registration", text: "Complete payment and register the land in your name." },
];

export const faqs = [
  {
    q: "Do you sell land on behalf of other owners?",
    a: "No. Every property on this website is owned by us. We do not list land for brokers, agents or other sellers.",
  },
  {
    q: "Can I see the documents before booking?",
    a: "Yes. Approval details are on each property page, and we share copies of the title and other documents during or after your site visit.",
  },
  {
    q: "How do I arrange a site visit?",
    a: "Send an enquiry or message us on WhatsApp with the property code (for example AL-0001). We will fix a time that suits you.",
  },
  {
    q: "Is the price negotiable?",
    a: "Properties marked “Negotiable” are open to discussion. For others, the listed price is final.",
  },
  {
    q: "What does “Reserved” mean?",
    a: "Another buyer has booked the property. You can still enquire — we will tell you if it becomes available again and suggest similar land.",
  },
  {
    q: "Do you help with bank loans?",
    a: "PLACEHOLDER — the owner should confirm whether loan assistance is offered.",
  },
  {
    q: "How long does registration take?",
    a: "PLACEHOLDER — usually a few weeks after full payment, depending on the sub-registrar office.",
  },
];

export const about = {
  title: "About us",
  intro:
    "PLACEHOLDER — Avanilands sells land it owns, directly to buyers, across Andhra Pradesh. Replace this with the company's story: who started it, when, and why.",
  mission: "PLACEHOLDER — To make buying land simple, transparent and safe for every family.",
  vision: "PLACEHOLDER — To be the most trusted name for land in Andhra Pradesh.",
  values: [
    { title: "Honesty", text: "We say what we know, and we show you the papers." },
    { title: "Clarity", text: "Exact measurements, fixed prices, no hidden charges." },
    { title: "Care", text: "We stay with you from the first call to registration." },
  ],
};

export const legal = {
  "terms": {
    "title": "Terms of use",
    "sections": [
      {
        "heading": "About this website",
        "text": "This website shows land owned and sold by the company. Information is provided to help you decide whether to enquire; it is not an offer or a contract."
      },
      {
        "heading": "Accuracy",
        "text": "We take care to keep details, prices and availability correct, but they can change. The registered sale documents are the final word on any property."
      },
      {
        "heading": "Bookings and payments",
        "text": "No booking or sale is complete until it is confirmed in writing by the company. Payment terms are agreed separately for each property."
      },
      {
        "heading": "Use of content",
        "text": "Photos, text and documents on this website belong to the company and may not be copied for commercial use."
      }
    ],
    "final": false
  },
  "privacy": {
    "title": "Privacy policy",
    "sections": [
      {
        "heading": "What we collect",
        "text": "When you send an enquiry we keep your name, phone number, optional email and message, and which property you asked about."
      },
      {
        "heading": "How we use it",
        "text": "Only to answer your enquiry, arrange site visits and follow up on your interest. We do not sell or share your details with other companies."
      },
      {
        "heading": "Website statistics",
        "text": "We count page visits to see which land and places interest people, without cookies. We don't store your IP address or anything else that identifies you, and visits can't be linked from one day to the next. Browsers that send Do Not Track or Global Privacy Control are not counted."
      },
      {
        "heading": "How long we keep it",
        "text": "Enquiries are kept while they are useful for your purchase and for our records, then deleted or anonymised."
      },
      {
        "heading": "Your choices",
        "text": "You can ask us to see, correct or delete your details at any time using the contact page."
      }
    ],
    "final": false
  },
  "disclaimer": {
    "title": "Disclaimer",
    "sections": [
      {
        "heading": "Photos and maps",
        "text": "Photos are for illustration and may not show the current condition of a property. Map locations may be approximate until shared with you directly."
      },
      {
        "heading": "Approvals",
        "text": "Approval and registration numbers are shown as issued. Buyers should verify all documents independently with their own legal advisor before purchase."
      },
      {
        "heading": "Prices",
        "text": "Prices exclude registration charges, stamp duty and other government fees unless stated otherwise."
      }
    ],
    "final": false
  }
};
