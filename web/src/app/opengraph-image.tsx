import { ImageResponse } from "next/og";

import { splitBrandName } from "@/lib/brand";
import { getSiteSettings } from "@/lib/data";

export const alt = "Avanilands";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** The picture shown when a link to the website is shared (WhatsApp, Facebook, Google). */
export default async function OpenGraphImage() {
  const settings = await getSiteSettings();
  const [first, last] = splitBrandName(settings.company_name);
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: "0 96px",
          background: "#0B3B2E",
          color: "#ffffff",
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          <svg width="150" height="136" viewBox="16 14 166 150">
            <path d="M100 16 L100 60 L63 141 L33 148 Z" fill="#4CAF50" />
            <path d="M100 16 L170 157 L141 157 L100 60 Z" fill="#2E7D32" />
            <path d="M18 161 Q114 160 180 60 Q96 126 18 161 Z" fill="#D4AF37" />
          </svg>
          <div style={{ marginLeft: 36, display: "flex", fontSize: 96, fontWeight: 700, letterSpacing: 2 }}>
            <span style={{ color: "#ffffff" }}>{first}</span>
            <span style={{ color: "#D4AF37" }}>{last}</span>
          </div>
        </div>
        <div style={{ marginTop: 56, fontSize: 50, color: "#ffffff" }}>{settings.tagline}</div>
        <div style={{ marginTop: 20, fontSize: 30, letterSpacing: 5, textTransform: "uppercase", color: "#ffffffaa" }}>
          {settings.descriptor}
        </div>
      </div>
    ),
    size,
  );
}
