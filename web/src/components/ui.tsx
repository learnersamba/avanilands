import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";

export function Container({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`mx-auto w-full max-w-7xl px-4 sm:px-6 lg:px-8 ${className}`}>{children}</div>;
}

export function SectionHeading({
  eyebrow,
  title,
  subtitle,
  align = "left",
  dark = false,
  as: Heading = "h2",
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  align?: "left" | "center";
  dark?: boolean;
  as?: "h1" | "h2";
}) {
  return (
    <div className={align === "center" ? "mx-auto max-w-2xl text-center" : "max-w-2xl"}>
      {eyebrow && (
        <p className={`text-xs font-semibold uppercase tracking-[0.2em] ${dark ? "text-sand" : "text-sand-dark"}`}>
          {eyebrow}
        </p>
      )}
      <Heading
        className={`mt-3 font-serif text-3xl leading-tight sm:text-4xl ${dark ? "text-white" : "text-forest"}`}
      >
        {title}
      </Heading>
      {subtitle && <p className={`mt-4 text-base sm:text-lg ${dark ? "text-white/80" : "text-ink/75"}`}>{subtitle}</p>}
    </div>
  );
}

const buttonStyles = {
  primary: "bg-forest text-white hover:bg-forest-dark",
  gold: "bg-sand text-forest-dark hover:bg-[#b8914c]",
  outline: "border border-forest/30 text-forest hover:border-forest hover:bg-forest/5",
  light: "border border-white/40 text-white hover:bg-white/10",
} as const;

/** Classes for a button-looking link (for client components that render their own <a>). */
export function buttonClasses(variant: keyof typeof buttonStyles = "primary", className = "") {
  return `inline-flex items-center justify-center gap-2 rounded-lg px-5 py-3 text-sm font-semibold transition-colors ${buttonStyles[variant]} ${className}`;
}

export function ButtonLink({
  variant = "primary",
  className = "",
  ...props
}: ComponentProps<typeof Link> & { variant?: keyof typeof buttonStyles }) {
  return (
    <Link
      {...props}
      className={`inline-flex items-center justify-center gap-2 rounded-lg px-5 py-3 text-sm font-semibold transition-colors ${buttonStyles[variant]} ${className}`}
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
      className={`inline-flex items-center justify-center gap-2 rounded-lg px-5 py-3 text-sm font-semibold transition-colors ${buttonStyles[variant]} ${className}`}
    />
  );
}

const statusStyles = {
  available: "bg-available text-white",
  reserved: "bg-reserved text-white",
  sold: "bg-sold text-white",
} as const;

export function StatusBadge({ status }: { status: keyof typeof statusStyles }) {
  return (
    <span className={`rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide ${statusStyles[status]}`}>
      {status === "available" ? "Available" : status === "reserved" ? "Reserved" : "Sold"}
    </span>
  );
}
