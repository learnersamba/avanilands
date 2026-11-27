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
        "heading": "Who we are",
        "text": "Avanilands is a brand of Tirupa Technologies Pvt. Ltd. (\"we\", \"us\"). We sell land that we own, directly to buyers. This policy explains what personal data we collect through this website and when you deal with our team, why we collect it, who we share it with, how long we keep it, and the rights you have.\n\nWe decide why and how your personal data is used, so under India's Digital Personal Data Protection Act, 2023 (the \"DPDP Act\") we are the \"Data Fiduciary\" and you are the \"Data Principal\". We also follow the Information Technology Act, 2000 and the rules made under it. Our company details are shown at the end of this page."
      },
      {
        "heading": "What we collect",
        "text": "Only what you give us, and only what we need:\n\n• Enquiries: your name, mobile number, email (optional), how you would like us to contact you, your message, and the property you asked about.\n\n• Site visit requests: the same details, plus the date and time you chose and how many people will come.\n\n• Customer accounts and bookings (when these are offered): your email, name and mobile number, land you save, and your booking. For payments we record only the amount, date, method and reference number (such as a UTR or cheque number) — never card numbers, bank passwords or UPI PINs.\n\n• Notes our sales team adds while helping you, and the status of your enquiry or visit.\n\n• Campaign details: if you came to the website by clicking one of our adverts or links, the campaign name in that link (for example \"facebook / november-plots\") and the first page you opened. This describes the advert, not you.\n\n• Security data: when you send a form, a scrambled (hashed) version of your internet (IP) address, used only to stop the same person sending too many forms. We do not keep your IP address itself.\n\n• Advertising data, only if you allow advertising cookies: see \"Advertising on Facebook and Instagram\" below.\n\nWe do not ask for, and ask you not to send us, Aadhaar numbers, PAN, bank details or copies of identity documents through the website. If these are needed for a sale, our team will ask for them separately and securely."
      },
      {
        "heading": "Why we use it",
        "text": "• To reply to your enquiry and arrange and confirm site visits, including reminders.\n\n• To follow up on your interest in a property, and to prepare and complete a booking or sale if you go ahead.\n\n• To keep records required by law (for example tax, accounting and property-registration records).\n\n• To protect the website and our customers from spam, fraud and misuse.\n\n• To understand which of our adverts and campaigns bring genuine buyers, so we spend less on adverts that don't work.\n\n• Only with your consent: to measure our adverts on Facebook and Instagram and show them to people more likely to be interested in land.\n\nWe use your details only for these purposes. We never sell your personal data, and we never use it to decide anything about you automatically."
      },
      {
        "heading": "Our legal grounds",
        "text": "When you send us an enquiry, a site visit request or a booking request, you give us your details voluntarily for that purpose. Under section 7(a) of the DPDP Act we may use them for that purpose, and for the follow-up you would reasonably expect, unless you tell us you don't want this.\n\nWe keep records where the law requires it, and may share data where a court, regulator or other authority lawfully requires it (sections 7(d) and 7(e) of the DPDP Act).\n\nAdvertising cookies and sharing data with Meta are based only on your consent, which you give by choosing \"Allow ad cookies\" and can withdraw at any time."
      },
      {
        "heading": "Advertising on Facebook and Instagram",
        "text": "We advertise on Facebook and Instagram, which belong to Meta Platforms. When we do, the website asks whether you allow advertising cookies. Nothing below happens unless you say yes, and saying no changes nothing else on the website.\n\nIf you say yes:\n\n• Meta's measurement tool (the \"Meta Pixel\") runs in your browser. It sets Meta's cookies (_fbp and, if you came from a Meta advert, _fbc) and tells Meta which pages you open, which property you look at, the places and land types you search for, and when you tap call or WhatsApp. It also sends Meta technical details such as your IP address and browser.\n\n• When you send an enquiry or a site visit request, our server tells Meta that a lead or visit request was made, with your mobile number and email in hashed form (scrambled with SHA-256, a one-way code), your IP address and browser, and the property code. Meta uses the hashed details only to match the event to a Facebook or Instagram account, if you have one.\n\n• Later, if our team marks your enquiry as \"interested\" or \"converted\", or your site visit as completed, we tell Meta the same way. This helps Meta show our adverts to people like our real buyers instead of people who only fill in forms. We never send Meta your name, your messages, prices you discussed or any payment information.\n\nMeta may combine this information with what it already knows about you and use it under its own terms and privacy policy (facebook.com/privacy/policy), including outside India. Meta's Ad Preferences let you control the adverts you see.\n\nBrowsers that send a Global Privacy Control signal are treated as having said no, and are not asked."
      },
      {
        "heading": "Cookies and storage on your device",
        "text": "The website works without cookies. These are the only ones it can use:\n\n• al_consent — remembers your answer to the advertising-cookie question, so we don't ask on every page. Kept for 6 months, then we ask again. Set only after you answer.\n\n• _fbp and _fbc — Meta's advertising cookies, only if you allow them. Kept up to 90 days, and removed from your browser when you withdraw consent here.\n\n• Sign-in cookies — only if you sign in to a customer account, to keep you signed in. Necessary for the account to work.\n\nThe website also keeps a few things in your own browser storage, which never leave your device unless you send a form: the campaign link you arrived from (for this browser tab only), the properties you are comparing, and recently viewed land.\n\nVideo preview pictures load from YouTube, and videos play in YouTube's privacy-enhanced mode only when you press play. Maps load map images from our map provider. Like any website you visit, these providers receive your IP address."
      },
      {
        "heading": "Website statistics",
        "text": "We count page visits to see which land and places interest people, without cookies. We don't store your IP address or anything else that identifies you, and visits can't be linked from one day to the next. Browsers that send Do Not Track or Global Privacy Control are not counted."
      },
      {
        "heading": "Who we share it with",
        "text": "Only with service providers who work for us, under contracts that require them to protect your data and use it only on our instructions:\n\n• Supabase — our database and sign-in service (data stored in Mumbai, India).\n\n• Google Firebase — hosts the website and admin panel (servers in Singapore and other locations).\n\n• Resend — sends our emails to you and to our team.\n\n• Cloudflare Turnstile — checks that forms are sent by people, not robots.\n\n• Meta Platforms — only with your consent, as described above. Meta also uses this data for its own purposes under its own terms.\n\n• Our professional advisers (lawyers, auditors) and, for a sale, the sub-registrar's office and others needed to register the property.\n\n• Government, courts or law-enforcement authorities, when the law requires us to.\n\nIf our business, or part of it, is merged or sold, your data may pass to the new owner, who must keep this policy's promises."
      },
      {
        "heading": "Data stored outside India",
        "text": "Some of our service providers, and Meta, store or process data outside India. The DPDP Act allows this except to countries the Government of India restricts; we will stop any transfer to such a country. Our providers protect the data with encryption and access controls wherever it is stored."
      },
      {
        "heading": "How long we keep it",
        "text": "We keep personal data only as long as it is needed for the purpose it was collected for, or as the law requires:\n\n• Enquiries and site visit requests that do not lead to a sale: deleted or anonymised within 3 years of our last contact with you, or sooner if you ask.\n\n• Bookings and sales: for as long as tax, company and property laws require (generally 8 years after the end of the financial year), then deleted.\n\n• Meta's click and browser ids kept with an enquiry: cleared after 180 days. Records of what we sent to Meta: deleted after 90 days. Meta keeps what it receives under its own policy.\n\n• Website statistics: 6 months. Account notifications: 90 days.\n\nWhen we no longer need your data, or you withdraw your consent and no law requires us to keep it, we erase it and ask our service providers to do the same."
      },
      {
        "heading": "How we protect it",
        "text": "Data is encrypted between your browser and our servers, and stored with access limited to the staff who need it. Every staff action on enquiries and bookings is recorded. Our database itself enforces who can read what. IP addresses are hashed, and contact details sent to Meta are hashed.\n\nIf a personal data breach happens, we will inform you and the Data Protection Board of India as the law requires, explaining what happened, the likely effect and what we are doing about it."
      },
      {
        "heading": "Your rights",
        "text": "Under the DPDP Act you may ask us:\n\n• for a summary of the personal data we hold about you, what we do with it, and who we have shared it with;\n\n• to correct, complete or update it;\n\n• to erase it, unless the law requires us to keep it;\n\n• to withdraw a consent you gave (see below);\n\n• to nominate another person to exercise your rights if you die or become unable to; and\n\n• to resolve any complaint about how we handle your data.\n\nWrite to our Grievance Officer (see \"Questions and complaints\"). We may need to confirm it is really you, for example by replying to the mobile number or email you gave us. We reply as soon as we can, and in any case within the time allowed by law."
      },
      {
        "heading": "Withdrawing consent",
        "text": "Withdrawing is as easy as giving consent. Open \"Cookie choices\" at the bottom of any page and choose \"No thanks\": the Meta Pixel stops at once and Meta's cookies are removed from your browser. To stop us reporting your enquiry or visit to Meta, write to our Grievance Officer.\n\nWithdrawing does not affect anything done before, and does not change how we answer your enquiry."
      },
      {
        "heading": "Children",
        "text": "This website is for adults buying land. We do not knowingly collect personal data from anyone under 18, and we do not track or show targeted advertising to children. If you are under 18, please ask a parent or guardian to contact us for you. If we learn that we hold a child's data without a parent's verifiable consent, we will delete it."
      },
      {
        "heading": "Questions and complaints",
        "text": "For any question, request or complaint about your personal data, contact our Grievance Officer by email at the address on our Contact page (subject: \"Privacy\"), or by post to our registered office shown below. Please include your name, mobile number and, if you have one, your enquiry or visit reference.\n\nIf you are not satisfied with our reply, you may complain to the Data Protection Board of India once it accepts complaints under the DPDP Act."
      },
      {
        "heading": "Changes to this policy",
        "text": "We will update this policy when our practices or the law change, and show the date of the latest version here. If a change affects something you consented to, we will ask again before it applies to you.\n\nLast updated: 27 November 2026."
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
