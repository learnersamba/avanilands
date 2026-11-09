import type { Metadata, Viewport } from "next";
import { Suspense } from "react";
import { Fraunces, Inter } from "next/font/google";

import { AccountProvider } from "@/components/account/account-provider";
import { CompareTray } from "@/components/compare/compare-tray";
import { JsonLd } from "@/components/json-ld";
import { PageTracker } from "@/components/page-tracker";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { WhatsAppButton } from "@/components/whatsapp-button";
import { getSiteSettings } from "@/lib/data";
import { env } from "@/lib/env";
import { organizationJsonLd } from "@/lib/structured-data";

import "./globals.css";

const inter = Inter({ variable: "--font-inter", subsets: ["latin"], display: "swap" });
// Headings use one weight, so only that file is downloaded.
const fraunces = Fraunces({ variable: "--font-fraunces", subsets: ["latin"], weight: "400", display: "swap" });

export async function generateMetadata(): Promise<Metadata> {
  const settings = await getSiteSettings();
  const title = settings.seo_title ?? `${settings.company_name} — Verified land for sale`;
  const description =
    settings.seo_description ??
    `Approved plots, agricultural and farm land sold directly by ${settings.company_name}. Clear titles, no brokers.`;
  return {
    metadataBase: new URL(env.siteUrl),
    title: { default: title, template: `%s | ${settings.company_name}` },
    description,
    openGraph: { type: "website", siteName: settings.company_name, title, description, locale: "en_IN" },
    twitter: { card: "summary_large_image" },
  };
}

export const viewport: Viewport = { themeColor: "#1f4d3a" };

export default async function RootLayout({ children }: LayoutProps<"/">) {
  const settings = await getSiteSettings();
  return (
    <html lang="en-IN" className={`${inter.variable} ${fraunces.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col">
        <a
          href="#main"
          className="sr-only z-50 rounded bg-forest px-4 py-2 text-white focus:not-sr-only focus:fixed focus:left-4 focus:top-4"
        >
          Skip to content
        </a>
        <JsonLd data={organizationJsonLd(settings, env.siteUrl)} />
        <AccountProvider>
          <SiteHeader />
          <main id="main" className="flex-1">
            {children}
          </main>
          <SiteFooter />
          <WhatsAppButton />
          {/* Read the page address: kept out of the pre-rendered page. */}
          <Suspense fallback={null}>
            <CompareTray />
            <PageTracker />
          </Suspense>
        </AccountProvider>
      </body>
    </html>
  );
}
