"use client";

import { useEffect, useRef, useState } from "react";

/** Map tiles: OpenStreetMap by default; set NEXT_PUBLIC_MAP_TILE_URL for a commercial provider at launch. */
const tileUrl = process.env.NEXT_PUBLIC_MAP_TILE_URL || "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const attribution =
  process.env.NEXT_PUBLIC_MAP_ATTRIBUTION ||
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';

const pin = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 42" width="32" height="42"><path d="M16 0C7.2 0 0 7.1 0 15.9 0 27.8 16 42 16 42s16-14.2 16-26.1C32 7.1 24.8 0 16 0Z" fill="#1f4d3a"/><circle cx="16" cy="16" r="6" fill="#c8a15a"/></svg>`;

/**
 * Leaflet map, loaded only when scrolled into view.
 * exact = pin; otherwise a ~1 km circle around the rounded position (decision 18).
 */
export function PropertyMap({ lat, lng, exact, label }: { lat: number; lng: number; exact: boolean; label: string }) {
  const container = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const element = container.current;
    if (!element) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: "300px" },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!visible || !container.current) return;
    let map: import("leaflet").Map | undefined;
    let cancelled = false;
    // The map's code and styles load only now, so they never slow the page's first paint.
    Promise.all([import("leaflet"), import("leaflet/dist/leaflet.css")]).then(([L]) => {
      if (cancelled || !container.current) return;
      map = L.map(container.current, {
        scrollWheelZoom: false,
        dragging: !L.Browser.mobile,
        attributionControl: true,
      }).setView([lat, lng], exact ? 15 : 13);
      L.tileLayer(tileUrl, { attribution, maxZoom: 18 }).addTo(map);
      if (exact) {
        L.marker([lat, lng], {
          title: label,
          alt: label,
          icon: L.divIcon({ html: pin, className: "", iconSize: [32, 42], iconAnchor: [16, 42] }),
        }).addTo(map);
      } else {
        L.circle([lat, lng], { radius: 900, color: "#1f4d3a", weight: 2, fillColor: "#c8a15a", fillOpacity: 0.25 }).addTo(map);
      }
    });
    return () => {
      cancelled = true;
      map?.remove();
    };
  }, [visible, lat, lng, exact, label]);

  return (
    <div
      ref={container}
      role="region"
      aria-label={exact ? `Map showing ${label}` : `Map showing the area around ${label}`}
      className="relative z-0 aspect-[16/10] w-full overflow-hidden rounded-2xl bg-line sm:aspect-[16/9]"
    />
  );
}
