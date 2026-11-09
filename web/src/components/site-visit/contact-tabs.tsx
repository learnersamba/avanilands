"use client";

import { type KeyboardEvent, type ReactNode, useState, useSyncExternalStore } from "react";

type Tab = "enquire" | "visit";

const subscribeHash = (onChange: () => void) => {
  window.addEventListener("hashchange", onChange);
  return () => window.removeEventListener("hashchange", onChange);
};
const useHash = () => useSyncExternalStore(subscribeHash, () => window.location.hash, () => "");

/**
 * "Ask a question" / "Book a site visit" on the property page. Both forms
 * stay mounted (typed text survives switching). A link to #visit opens the
 * booking tab; a tab the visitor picks wins until the address changes again.
 */
export function ContactTabs({ enquire, visit }: { enquire: ReactNode; visit: ReactNode }) {
  const hash = useHash();
  const [choice, setChoice] = useState<{ tab: Tab; hash: string } | null>(null);
  const fromHash: Tab = hash === "#visit" ? "visit" : "enquire";
  const tab = choice && choice.hash === hash ? choice.tab : fromHash;
  const tabs: { id: Tab; label: string }[] = [
    { id: "enquire", label: "Ask a question" },
    { id: "visit", label: "Book a site visit" },
  ];

  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    const next = tab === "enquire" ? "visit" : "enquire";
    setChoice({ tab: next, hash });
    document.getElementById(`contact-tab-${next}`)?.focus();
  };

  return (
    <div>
      <div role="tablist" aria-label="How to get in touch" className="grid grid-cols-2 gap-1 rounded-xl bg-sand-light p-1">
        {tabs.map((item) => (
          <button
            key={item.id}
            id={`contact-tab-${item.id}`}
            type="button"
            role="tab"
            aria-selected={tab === item.id}
            aria-controls={`contact-panel-${item.id}`}
            tabIndex={tab === item.id ? 0 : -1}
            onClick={() => setChoice({ tab: item.id, hash })}
            onKeyDown={onKeyDown}
            className={`rounded-lg px-3 py-2.5 text-sm font-semibold transition ${
              tab === item.id ? "bg-white text-forest shadow-sm" : "text-ink/70 hover:text-forest"
            }`}
          >
            {item.label}
          </button>
        ))}
      </div>
      <div id="contact-panel-enquire" role="tabpanel" aria-labelledby="contact-tab-enquire" hidden={tab !== "enquire"} className="mt-5">
        {enquire}
      </div>
      <div id="contact-panel-visit" role="tabpanel" aria-labelledby="contact-tab-visit" hidden={tab !== "visit"} className="mt-5">
        {visit}
      </div>
    </div>
  );
}
