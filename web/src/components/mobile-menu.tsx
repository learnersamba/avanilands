"use client";

import { Menu, X } from "lucide-react";
import Link from "next/link";
import { useState } from "react";

/** Phone navigation: a button that opens a full-width panel. */
export function MobileMenu({ links }: { links: { href: string; label: string }[] }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="lg:hidden">
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
        aria-controls="mobile-menu"
        aria-label={open ? "Close menu" : "Open menu"}
        className="inline-flex h-10 w-10 items-center justify-center rounded-lg text-white hover:bg-white/10"
      >
        {open ? <X className="h-6 w-6" aria-hidden /> : <Menu className="h-6 w-6" aria-hidden />}
      </button>
      {open && (
        <nav
          id="mobile-menu"
          aria-label="Main"
          className="absolute inset-x-0 top-[4.5rem] border-b border-line bg-paper px-4 pb-6 pt-2 shadow-lg"
        >
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              onClick={() => setOpen(false)}
              className="block border-b border-line/70 py-4 text-lg font-medium text-ink"
            >
              {link.label}
            </Link>
          ))}
          <Link
            href="/contact"
            onClick={() => setOpen(false)}
            className="mt-5 flex items-center justify-center rounded-md bg-sand py-3.5 font-heading font-semibold text-forest-dark"
          >
            Enquire Now
          </Link>
        </nav>
      )}
    </div>
  );
}
