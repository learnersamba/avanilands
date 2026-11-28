"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

/** Header link: gold with an underline when it is the current section. */
export function NavLink({ href, children }: { href: string; children: ReactNode }) {
  const pathname = usePathname();
  const active = href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);
  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      className={`relative py-2 text-[0.9rem] font-medium transition-colors after:absolute after:inset-x-0 after:-bottom-0.5 after:h-0.5 after:rounded-full after:bg-sand after:transition-opacity ${
        active ? "text-sand after:opacity-100" : "text-white/85 after:opacity-0 hover:text-sand"
      }`}
    >
      {children}
    </Link>
  );
}
