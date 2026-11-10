import { ImageResponse } from "next/og";

import { getSiteSettings } from "@/lib/data";

export const alt = "Avanilands";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** The picture shown when a link to the website is shared (WhatsApp, Facebook, Google). */
export default async function OpenGraphImage() {
  const settings = await getSiteSettings();
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
          background: "#1f4d3a",
          color: "#ffffff",
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          <svg width="120" height="120" viewBox="0 0 32 32">
            <circle cx="16" cy="16" r="16" fill="#ffffff" fillOpacity="0.1" />
            <path d="M5 22 L12 13 L16 18 L20 11 L27 22 Z" fill="#c8a15a" />
            <path d="M5 22 H27" stroke="#efe3c8" strokeWidth="1.5" fill="none" />
          </svg>
          <div style={{ marginLeft: 36, fontSize: 92, fontWeight: 700, letterSpacing: 10, textTransform: "uppercase" }}>
            {settings.company_name}
          </div>
        </div>
        <div style={{ marginTop: 56, fontSize: 50, color: "#c8a15a" }}>{settings.tagline}</div>
        <div style={{ marginTop: 20, fontSize: 30, letterSpacing: 5, textTransform: "uppercase", color: "#ffffffaa" }}>
          {settings.descriptor}
        </div>
      </div>
    ),
    size,
  );
}
