import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";

export function Container({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`mx-auto w-full max-w-7xl px-4 sm:px-6 lg:px-8 ${className}`}>{children}</div>;
}

export function SectionHeading({
  title,
  subtitle,
  align = "left",
  dark = false,
  as: Heading = "h2",
}: {
  title: string;
  subtitle?: string;
  align?: "left" | "center";
  dark?: boolean;
  as?: "h1" | "h2";
}) {
  return (
    <div className={align === "center" ? "mx-auto max-w-2xl text-center" : "max-w-2xl"}>
      <Heading
        className={`font-serif text-[2rem] leading-[1.12] sm:text-[2.6rem] ${dark ? "text-white" : "text-forest-dark"}`}
      >
        {title}
      </Heading>
      {subtitle && (
        <p className={`mt-4 max-w-xl text-base leading-relaxed sm:text-lg ${align === "center" ? "mx-auto" : ""} ${dark ? "text-white/75" : "text-muted"}`}>
          {subtitle}
        </p>
      )}
    </div>
  );
}

const buttonStyles = {
  primary: "bg-forest-dark text-white hover:bg-forest",
  gold: "bg-sand text-forest-dark hover:bg-[#C29F2E]",
  outline: "border border-forest-dark/25 text-forest-dark hover:border-forest-dark",
  light: "border border-white/35 text-white hover:border-white hover:bg-white/5",
} as const;

/** Classes for a button-looking link (for client components that render their own <a>). */
export function buttonClasses(variant: keyof typeof buttonStyles = "primary", className = "") {
  return `inline-flex items-center justify-center gap-2 rounded-md px-5 py-3 font-heading text-[0.9rem] font-semibold transition-colors ${buttonStyles[variant]} ${className}`;
}

export function ButtonLink({
  variant = "primary",
  className = "",
  ...props
}: ComponentProps<typeof Link> & { variant?: keyof typeof buttonStyles }) {
  return (
    <Link
      {...props}
      className={`inline-flex items-center justify-center gap-2 rounded-md px-5 py-3 font-heading text-[0.9rem] font-semibold transition-colors ${buttonStyles[variant]} ${className}`}
    />
  );
}

/** For external links (tel:, wa.me, mailto:). */
export function ButtonAnchor({
  variant = "primary",
  className = "",
  ...props
}: ComponentProps<"a"> & { variant?: keyof typeof buttonStyles }) {
  return (
    <a
      {...props}
      className={`inline-flex items-center justify-center gap-2 rounded-md px-5 py-3 font-heading text-[0.9rem] font-semibold transition-colors ${buttonStyles[variant]} ${className}`}
    />
  );
}

const statusStyles = {
  available: "bg-available text-white",
  reserved: "bg-reserved text-white shadow-sm shadow-reserved/40",
  sold: "bg-sold text-white shadow-sm shadow-sold/40",
} as const;

export function StatusBadge({ status }: { status: keyof typeof statusStyles }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${statusStyles[status]}`}
    >
      {status !== "available" && <span className="h-1.5 w-1.5 rounded-full bg-white" aria-hidden />}
      {status === "available" ? "Available" : status === "reserved" ? "Reserved" : "Sold"}
    </span>
  );
}

/** A diagonal "Sold" / "Reserved" band across the top-left corner of a photo. */
export function StatusRibbon({
  status,
  size = "md",
}: {
  status: "available" | "reserved" | "sold";
  size?: "sm" | "md";
}) {
  if (status === "available") return null;
  const band =
    size === "sm"
      ? "left-[-38px] top-[18px] w-[140px] py-1 text-[11px]"
      : "left-[-44px] top-[28px] w-[190px] py-2 text-sm";
  return (
    <div
      className={`pointer-events-none absolute left-0 top-0 z-10 overflow-hidden ${size === "sm" ? "h-24 w-24" : "h-36 w-36"}`}
      aria-hidden
    >
      <div
        className={`absolute -rotate-45 text-center font-bold uppercase tracking-[0.25em] text-white shadow-lg ${band} ${
          status === "sold" ? "bg-sold" : "bg-reserved"
        }`}
      >
        {status === "sold" ? "Sold" : "Reserved"}
      </div>
    </div>
  );
}
