import { useId } from "react";

/** The AVANILANDS symbol: architectural A with the gold swoosh (brand kit, Nov 2026). */
export function BrandMark({ className = "h-10 w-10" }: { className?: string }) {
  const id = useId().replace(/:/g, "");
  return (
    <svg viewBox="16 14 166 150" className={className} aria-hidden focusable="false">
      <defs>
        <linearGradient id={`${id}l`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#6CC24A" />
          <stop offset="1" stopColor="#2E7D32" />
        </linearGradient>
        <linearGradient id={`${id}r`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#3F9A3A" />
          <stop offset="1" stopColor="#1F6326" />
        </linearGradient>
        <linearGradient id={`${id}s`} x1="0" y1="1" x2="1" y2="0">
          <stop offset="0" stopColor="#B8921F" />
          <stop offset="0.45" stopColor="#D4AF37" />
          <stop offset="1" stopColor="#F2D675" />
        </linearGradient>
      </defs>
      <path d="M100 16 L100 60 L63 141 L33 148 Z" fill={`url(#${id}l)`} />
      <path d="M100 16 L170 157 L141 157 L100 60 Z" fill={`url(#${id}r)`} />
      <path d="M18 161 Q114 160 180 60 Q96 126 18 161 Z" fill={`url(#${id}s)`} />
    </svg>
  );
}
