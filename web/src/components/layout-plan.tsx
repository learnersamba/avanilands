/**
 * The home hero's drawing: a land layout plan (boundary, roads, numbered plots,
 * a park, north arrow and scale bar) with one plot picked out in brass. It draws
 * itself once on load (see .plan-draw / .plan-fade in globals.css). Decorative:
 * the caption is the only text a screen reader needs, and it is in the page.
 */

type Plot = { x: number; y: number; w: number; h: number; n: number };

const W = 46; // plot frontage
const D = 82; // plot depth

/** Two back-to-back rows of plots filling a block, numbered left to right. */
function block(x0: number, y0: number, cols: number, start: number): Plot[] {
  const plots: Plot[] = [];
  for (let row = 0; row < 2; row++) {
    for (let col = 0; col < cols; col++) {
      plots.push({ x: x0 + col * W, y: y0 + row * D, w: W, h: D, n: start + row * cols + col });
    }
  }
  return plots;
}

const blocks = [
  block(34, 60, 5, 1), // north-west
  block(296, 60, 5, 11), // north-east
  block(34, 288, 5, 21), // south-west
];
const PICK = 10; // the highlighted plot: fronts the internal road on its east side
const picked = blocks.flat().find((p) => p.n === PICK)!;

const boundary = "M30 58 L512 40 L536 272 L508 470 L46 478 L18 262 Z";

export function LayoutPlan({ caption }: { caption: string }) {
  return (
    <figure className="relative">
      <svg
        viewBox="0 0 560 540"
        className="h-auto w-full"
        role="img"
        aria-label="Illustration of a land layout plan with one plot highlighted"
      >
        <defs>
          <clipPath id="plan-site">
            <path d={boundary} />
          </clipPath>
        </defs>

        {/* Plots, faint, clipped to the site boundary. */}
        <g clipPath="url(#plan-site)" className="plan-fade" style={{ animationDelay: "0.9s" }}>
          {blocks.flat().map((p) => (
            <g key={p.n}>
              <rect x={p.x} y={p.y} width={p.w} height={p.h} fill="none" stroke="rgba(255,255,255,0.22)" strokeWidth="1" />
              <text
                x={p.x + p.w / 2}
                y={p.y + p.h / 2 + 4}
                textAnchor="middle"
                fontSize="11"
                fill="rgba(255,255,255,0.38)"
                className="tabular-nums"
              >
                {p.n}
              </text>
            </g>
          ))}

          {/* Park with contour lines in the south-east block. */}
          <rect x="296" y="288" width="230" height="190" fill="rgba(184,146,90,0.07)" />
          <g fill="none" stroke="rgba(184,146,90,0.35)" strokeWidth="1">
            <ellipse cx="410" cy="384" rx="34" ry="18" />
            <ellipse cx="410" cy="384" rx="62" ry="34" />
            <ellipse cx="410" cy="384" rx="92" ry="52" />
          </g>
          <text x="410" y="389" textAnchor="middle" fontSize="12" fill="rgba(236,226,204,0.75)" letterSpacing="0.04em">
            Park
          </text>
        </g>

        {/* Roads: a 12 m road across the site and an internal road down the middle. */}
        <g fill="none" stroke="rgba(255,255,255,0.55)" strokeWidth="1.2">
          <path className="plan-draw" pathLength={1} d="M18 228 L534 228" style={{ animationDelay: "0.35s" }} />
          <path className="plan-draw" pathLength={1} d="M22 280 L536 280" style={{ animationDelay: "0.35s" }} />
          <path className="plan-draw" pathLength={1} d="M264 46 L264 228 M264 280 L264 476" style={{ animationDelay: "0.5s" }} />
          <path className="plan-draw" pathLength={1} d="M292 45 L292 228 M292 280 L292 476" style={{ animationDelay: "0.5s" }} />
        </g>
        <g className="plan-fade" style={{ animationDelay: "1.2s" }} fontSize="10.5" fill="rgba(255,255,255,0.5)" letterSpacing="0.06em">
          <text x="150" y="258">12 m road</text>
          <text x="282" y="380" transform="rotate(-90 282 380)" textAnchor="middle">9 m road</text>
        </g>

        {/* Site boundary. */}
        <path
          className="plan-draw"
          pathLength={1}
          d={boundary}
          fill="none"
          stroke="#b8925a"
          strokeWidth="1.8"
          strokeLinejoin="round"
        />

        {/* The highlighted plot, its dimensions and a callout. */}
        <g className="plan-fade" style={{ animationDelay: "1.55s" }}>
          <rect
            x={picked.x}
            y={picked.y}
            width={picked.w}
            height={picked.h}
            fill="rgba(184,146,90,0.5)"
            stroke="#d9b98a"
            strokeWidth="1.6"
          />
          <text x={picked.x + picked.w / 2} y={picked.y + picked.h / 2 + 4} textAnchor="middle" fontSize="12" fill="#fff">
            {picked.n}
          </text>
          {/* Frontage dimension along the road. */}
          <g stroke="#d9b98a" strokeWidth="1">
            <path d={`M${picked.x + picked.w + 9} ${picked.y} V${picked.y + picked.h}`} />
            <path d={`M${picked.x + picked.w + 5} ${picked.y} h8 M${picked.x + picked.w + 5} ${picked.y + picked.h} h8`} />
          </g>
          <text
            x={picked.x + picked.w + 21}
            y={picked.y + picked.h / 2}
            textAnchor="middle"
            fontSize="10.5"
            fill="#d9b98a"
            transform={`rotate(-90 ${picked.x + picked.w + 21} ${picked.y + picked.h / 2})`}
          >
            40 ft
          </text>
          {/* Callout. */}
          <path d={`M${picked.x + picked.w} ${picked.y + 6} L312 128`} stroke="#d9b98a" strokeWidth="1" fill="none" />
          <g transform="translate(304 68)">
            <rect width="168" height="60" rx="4" fill="#0f2c22" stroke="#b8925a" strokeWidth="1" />
            <text x="14" y="25" fontSize="15" fill="#fff" fontFamily="var(--font-display)">
              Plot {picked.n}, available
            </text>
            <text x="14" y="45" fontSize="11.5" fill="rgba(255,255,255,0.72)">
              East facing, clear title
            </text>
          </g>
        </g>

        {/* North arrow and scale bar. */}
        <g className="plan-fade" style={{ animationDelay: "1.2s" }} stroke="rgba(255,255,255,0.6)" fill="none">
          <g transform="translate(40 510)">
            <path d="M0 0 H30 M30 0 H60" strokeWidth="1" />
            <path d="M0 -4 V4 M30 -4 V4 M60 -4 V4" strokeWidth="1" />
            <path d="M0 0 H30" stroke="rgba(255,255,255,0.85)" strokeWidth="3" />
          </g>
          <g transform="translate(520 500)">
            <path d="M0 -26 L7 -6 L0 -10 L-7 -6 Z" fill="rgba(255,255,255,0.75)" stroke="none" />
            <circle cx="0" cy="-14" r="17" strokeWidth="1" />
          </g>
        </g>
        <g className="plan-fade" style={{ animationDelay: "1.2s" }} fontSize="10" fill="rgba(255,255,255,0.55)">
          <text x="40" y="527">0</text>
          <text x="66" y="527">10</text>
          <text x="94" y="527">20 m</text>
          <text x="520" y="466" textAnchor="middle">N</text>
        </g>
      </svg>
      <figcaption className="mt-1 text-right text-sm text-white/55">{caption}</figcaption>
    </figure>
  );
}
