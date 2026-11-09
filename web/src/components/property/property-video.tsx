"use client";

import { Play } from "lucide-react";
import { useState } from "react";

/**
 * YouTube "lite" player: shows the thumbnail and loads YouTube's player
 * only when tapped (saves ~1 MB on every page view). Privacy-enhanced mode.
 */
export function YouTubeVideo({ id, title }: { id: string; title: string }) {
  const [playing, setPlaying] = useState(false);
  if (playing) {
    return (
      <iframe
        src={`https://www.youtube-nocookie.com/embed/${id}?autoplay=1&rel=0&modestbranding=1`}
        title={title}
        allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
        allowFullScreen
        className="aspect-video w-full rounded-2xl"
      />
    );
  }
  return (
    <button
      type="button"
      onClick={() => setPlaying(true)}
      className="group relative block aspect-video w-full overflow-hidden rounded-2xl bg-ink"
      aria-label={`Play video: ${title}`}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={`https://i.ytimg.com/vi/${id}/hqdefault.jpg`}
        alt=""
        loading="lazy"
        className="h-full w-full object-cover opacity-85 transition-opacity group-hover:opacity-100"
      />
      <span className="absolute left-1/2 top-1/2 flex h-16 w-16 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-forest/90 text-white shadow-lg transition-transform group-hover:scale-110">
        <Play className="ml-1 h-7 w-7 fill-current" aria-hidden />
      </span>
      <span className="absolute bottom-3 left-3 rounded bg-black/60 px-2 py-1 text-sm text-white">{title}</span>
    </button>
  );
}

export function UploadedVideo({ src, poster, title }: { src: string; poster?: string; title: string }) {
  return (
    <video controls preload="none" poster={poster} className="aspect-video w-full rounded-2xl bg-ink" aria-label={title}>
      <source src={src} type="video/mp4" />
    </video>
  );
}
