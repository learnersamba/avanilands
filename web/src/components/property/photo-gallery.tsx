"use client";

import { ChevronLeft, ChevronRight, Images, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

export type GalleryPhoto = { id: string; thumb: string; medium: string; large: string; alt: string };

/**
 * Desktop: one large photo and four small ones. Phones: a swipeable strip.
 * Any photo opens a full-screen viewer (arrow keys, swipe, Esc to close).
 */
export function PhotoGallery({ photos }: { photos: GalleryPhoto[] }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [index, setIndex] = useState<number | null>(null);

  const open = (at: number) => {
    setIndex(at);
    dialogRef.current?.showModal();
  };
  const close = () => dialogRef.current?.close();
  const step = useCallback(
    (by: number) => setIndex((current) => (current == null ? 0 : (current + by + photos.length) % photos.length)),
    [photos.length],
  );

  // Arrow keys while the viewer is open.
  useEffect(() => {
    if (index == null) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "ArrowRight") step(1);
      if (event.key === "ArrowLeft") step(-1);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [index, step]);

  // Swipe on touch screens.
  const touchStart = useRef<number | null>(null);

  if (photos.length === 0) {
    return (
      <div className="bg-contours flex aspect-[21/9] items-center justify-center rounded-2xl bg-forest text-sand-light">
        Photos coming soon
      </div>
    );
  }

  const [first, ...rest] = photos;
  const current = index == null ? null : photos[index];

  return (
    <>
      {/* Desktop grid */}
      <div className="relative hidden gap-3 lg:grid lg:grid-cols-4 lg:grid-rows-2">
        <button
          type="button"
          onClick={() => open(0)}
          className="group overflow-hidden rounded-2xl lg:col-span-2 lg:row-span-2"
          aria-label={`Open photo 1 of ${photos.length}: ${first.alt}`}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={first.medium}
            srcSet={`${first.thumb} 400w, ${first.medium} 1200w, ${first.large} 2000w`}
            sizes="50vw"
            alt={first.alt}
            fetchPriority="high"
            width={1200}
            height={900}
            className="aspect-[4/3] h-full w-full object-cover transition-transform duration-500 group-hover:scale-[1.02]"
          />
        </button>
        {rest.slice(0, 4).map((photo, i) => (
          <button
            key={photo.id}
            type="button"
            onClick={() => open(i + 1)}
            className="group overflow-hidden rounded-2xl"
            aria-label={`Open photo ${i + 2} of ${photos.length}: ${photo.alt}`}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={photo.thumb}
              srcSet={`${photo.thumb} 400w, ${photo.medium} 1200w`}
              sizes="25vw"
              alt={photo.alt}
              loading="lazy"
              width={400}
              height={300}
              className="aspect-[4/3] h-full w-full object-cover transition-transform duration-500 group-hover:scale-[1.04]"
            />
          </button>
        ))}
        {photos.length > 1 && (
          <button
            type="button"
            onClick={() => open(0)}
            className="absolute bottom-4 right-4 inline-flex items-center gap-2 rounded-lg bg-white/95 px-4 py-2 text-sm font-semibold text-forest shadow"
          >
            <Images className="h-4 w-4" aria-hidden /> View all {photos.length} photos
          </button>
        )}
      </div>

      {/* Phone strip */}
      <div className="lg:hidden">
        <div className="-mx-4 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-2 [scrollbar-width:none]">
          {photos.map((photo, i) => (
            <button
              key={photo.id}
              type="button"
              onClick={() => open(i)}
              className="relative w-[88%] shrink-0 snap-center overflow-hidden rounded-2xl"
              aria-label={`Open photo ${i + 1} of ${photos.length}: ${photo.alt}`}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={photo.medium}
                srcSet={`${photo.thumb} 400w, ${photo.medium} 1200w`}
                sizes="88vw"
                alt={photo.alt}
                loading={i === 0 ? "eager" : "lazy"}
                fetchPriority={i === 0 ? "high" : "auto"}
                width={1200}
                height={900}
                className="aspect-[4/3] w-full object-cover"
              />
              <span className="absolute bottom-3 right-3 rounded-full bg-black/60 px-2.5 py-1 text-xs text-white">
                {i + 1} / {photos.length}
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* Full-screen viewer */}
      <dialog
        ref={dialogRef}
        onClose={() => setIndex(null)}
        aria-label="Photo viewer"
        className="m-0 h-full max-h-none w-full max-w-none bg-black/95 p-0 text-white backdrop:bg-black/80"
      >
        {current && (
          <div
            className="flex h-full flex-col"
            onTouchStart={(event) => (touchStart.current = event.touches[0].clientX)}
            onTouchEnd={(event) => {
              if (touchStart.current == null) return;
              const dx = event.changedTouches[0].clientX - touchStart.current;
              if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
              touchStart.current = null;
            }}
          >
            <div className="flex items-center justify-between px-4 py-3 text-sm">
              <span aria-live="polite">
                {index! + 1} / {photos.length}
              </span>
              <button
                type="button"
                onClick={close}
                className="inline-flex h-11 w-11 items-center justify-center rounded-full hover:bg-white/10"
                aria-label="Close photo viewer"
              >
                <X className="h-6 w-6" aria-hidden />
              </button>
            </div>
            <div className="relative flex flex-1 items-center justify-center px-2 pb-6">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                key={current.id}
                src={current.large}
                srcSet={`${current.medium} 1200w, ${current.large} 2000w`}
                sizes="100vw"
                alt={current.alt}
                className="max-h-full max-w-full object-contain"
              />
              {photos.length > 1 && (
                <>
                  <button
                    type="button"
                    onClick={() => step(-1)}
                    className="absolute left-2 top-1/2 inline-flex h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-white/10 hover:bg-white/20"
                    aria-label="Previous photo"
                  >
                    <ChevronLeft className="h-7 w-7" aria-hidden />
                  </button>
                  <button
                    type="button"
                    onClick={() => step(1)}
                    className="absolute right-2 top-1/2 inline-flex h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-white/10 hover:bg-white/20"
                    aria-label="Next photo"
                  >
                    <ChevronRight className="h-7 w-7" aria-hidden />
                  </button>
                </>
              )}
            </div>
            <p className="px-4 pb-5 text-center text-sm text-white/70">{current.alt}</p>
          </div>
        )}
      </dialog>
    </>
  );
}
