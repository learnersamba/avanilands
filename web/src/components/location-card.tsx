import { ArrowRight } from "lucide-react";
import Link from "next/link";

import type { LocationSummary } from "@/lib/data";
import { storageUrl } from "@/lib/media";

export function LocationCard({ location, href }: { location: LocationSummary; href: string }) {
  return (
    <Link
      href={href}
      className="group relative flex aspect-[4/3] flex-col justify-end overflow-hidden rounded-2xl bg-forest p-5 text-white"
    >
      {location.cover_image_path ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={storageUrl("site-assets", location.cover_image_path)}
          alt=""
          loading="lazy"
          className="absolute inset-0 h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
        />
      ) : (
        <div className="bg-contours absolute inset-0" aria-hidden />
      )}
      <div className="absolute inset-0 bg-gradient-to-t from-forest-dark/90 via-forest-dark/30 to-transparent" aria-hidden />
      <div className="relative">
        <p className="font-serif text-2xl">{location.city}</p>
        <p className="mt-1 flex items-center gap-1 text-sm text-white/85">
          {location.count === 0
            ? "New listings soon"
            : `${location.count} ${location.count === 1 ? "property" : "properties"}`}
          <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" aria-hidden />
        </p>
      </div>
    </Link>
  );
}
