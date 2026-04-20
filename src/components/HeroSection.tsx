import Image from "next/image";
import CtaCard from "./CtaCard";

// Material Icons — inline SVGs matching the screenshot exactly

const InfoIcon = (
  <svg viewBox="0 0 24 24" fill="currentColor" className="w-12 h-12" aria-hidden>
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" />
  </svg>
);

const MapIcon = (
  <svg viewBox="0 0 24 24" fill="currentColor" className="w-12 h-12" aria-hidden>
    <path d="M20.5 3l-.16.03L15 5.1 9 3 3.36 4.9c-.21.07-.36.25-.36.48V20.5c0 .28.22.5.5.5l.16-.03L9 18.9l6 2.1 5.64-1.9c.21-.07.36-.25.36-.48V3.5c0-.28-.22-.5-.5-.5zM15 19l-6-2.11V5l6 2.11V19z" />
  </svg>
);

const DirectionsIcon = (
  <svg viewBox="0 0 24 24" fill="currentColor" className="w-12 h-12" aria-hidden>
    <path d="M21.71 11.29l-9-9c-.39-.39-1.02-.39-1.41 0l-9 9c-.39.39-.39 1.02 0 1.41l9 9c.39.39 1.02.39 1.41 0l9-9c.39-.39.39-1.02 0-1.41zM14 14.5V12h-4v3H8v-4c0-.55.45-1 1-1h5V7.5l3.5 3.5-3.5 3.5z" />
  </svg>
);

const ctaCards = [
  {
    icon: MapIcon,
    title: "View map of all routes",
    description:
      "Explore the first comprehensive interactive map, showing all ferry routes, jetties, schedules, and prices.",
    href: "/map",
  },
  {
    icon: DirectionsIcon,
    title: "Navigate from A to B",
    description:
      "Get step-by-step directions, including bus connections. We have partnered with several popular navigation apps.",
    href: "/partnerships",
  },
    {
    icon: InfoIcon,
    title: "Learn about the ferries",
    description:
      "Discover the different types of ferry services, safety information, and how the ferry system works in Lagos.",
    href: "/about",
  },
];

export default function HeroSection() {
  return (
    <section className="overflow-hidden">

      {/* ── Split-screen hero ─────────────────────────────────────────────
          Traffic photo on the left, ferry photo on the right.
          Dark overlay on each panel keeps the white text legible.
          The ferry icon animates across the full section width.
      ──────────────────────────────────────────────────────────────────── */}
      <div className="relative flex flex-col md:flex-row h-[400px]">

        {/* Top panel (mobile) / Left panel (desktop) — traffic */}
        <div className="flex-1 relative">
          <Image
            src="/hero-traffic.jpg"
            alt=""
            fill
            priority
            sizes="(max-width: 768px) 100vw, 50vw"
            className="object-cover object-center"
          />
          <div className="absolute inset-0 bg-[#012c57]/75" />
        </div>

        {/* Bottom panel (mobile) / Right panel (desktop) — ferry */}
        <div className="flex-1 relative">
          <Image
            src="/hero-ferry.jpg"
            alt=""
            fill
            priority
            sizes="(max-width: 768px) 100vw, 50vw"
            className="object-cover object-center"
          />
          <div className="absolute inset-0 bg-[#012c57]/75" />
        </div>

        {/* Content — centred over both panels */}
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center px-4 gap-6">
          {/* Outer span animates (translateX); inner img rotates + whitens */}
          <span className="inline-block animate-ferry-sail select-none">
            <Image
              src="/ferry-icon.png"
              alt=""
              aria-hidden
              draggable={false}
              width={72}
              height={72}
              className="rotate-[-5deg] brightness-0 invert"
            />
          </span>

          <h1 className="text-[36px] md:text-[45px] font-normal leading-[44px] md:leading-[52px] text-white max-w-6xl">
            Avoid Lagos traffic by taking the ferry.
          </h1>

          <p className="text-base leading-6 text-white/80 max-w-xl">
            The waterways remain an underutilised way to navigate the city,
            partly due to a lack of public information. We&apos;re changing that.
          </p>
        </div>
      </div>

      {/* ── CTA cards ─────────────────────────────────────────────────────
          Full-width blue band; cards constrained to max-w-6xl inside.
      ──────────────────────────────────────────────────────────────────── */}
      <div className="bg-[#1976D2]">
        <div className="min-h-[360px] max-w-8xl mx-auto px-4 md:px-20 py-15 grid grid-cols-1 md:grid-cols-3 gap-8">
          {ctaCards.map((card) => (
            <CtaCard key={card.href} {...card} />
          ))}
        </div>
      </div>

    </section>
  );
}
