"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { event as gaEvent } from "@/lib/gtag";

const navLinks = [
  { label: "About", href: "/about" },
  { label: "Map", href: "/map" },
  { label: "Navigation", href: "/partnerships" },
  { label: "Directory", href: "/directory" },
];

export default function Navbar() {
  const [menuOpen, setMenuOpen] = useState(false);

  // Hover on the byline is tracked here, not with :hover: after a click opens publictech.studio
  // in a new tab and the visitor comes back, browsers keep :hover until the mouse next moves,
  // so it would stay highlighted. Cleared on click and whenever the tab loses focus.
  const [bylineHover, setBylineHover] = useState(false);
  const bylineHoverOn = (e: React.PointerEvent) => {
    if (e.pointerType === "mouse") setBylineHover(true);
  };
  const bylineHoverOff = () => setBylineHover(false);

  useEffect(() => {
    window.addEventListener("blur", bylineHoverOff);
    document.addEventListener("visibilitychange", bylineHoverOff);
    return () => {
      window.removeEventListener("blur", bylineHoverOff);
      document.removeEventListener("visibilitychange", bylineHoverOff);
    };
  }, []);

  return (
    <header className="sticky top-0 z-5000 bg-[#012c57] shadow-elevation-2">
      {/* MD3 Top App Bar — 64px */}
      <nav className="px-4 h-16 flex items-center justify-between">
        <div className="flex items-center">
          {/* Title Large (22px / 400) */}
          <Link
            href="/"
            className="text-white font-bold text-[22px] leading-7 tracking-tight"
          >
            Lagos Ferry Map
          </Link>

          <span className="w-px h-[18px] md:h-5 mx-3 md:mx-4 bg-white/30 shrink-0" aria-hidden="true" />

          {/* "A product of" and the PTS logo, linking to publictech.studio (as on Population.Africa).
              Muted at rest, full white on hover, press and keyboard focus. Text is hidden on phones. */}
          <a
            href="https://publictech.studio"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="A product of Public Tech Studio (opens publictech.studio in a new tab)"
            onPointerEnter={bylineHoverOn}
            onPointerMove={bylineHoverOn}
            onPointerLeave={bylineHoverOff}
            onClick={(e) => {
              gaEvent("byline_click", { href: "https://publictech.studio" });
              bylineHoverOff();
              if (e.detail > 0) e.currentTarget.blur();
            }}
            className={`group flex items-center md:gap-2 text-xs leading-4 whitespace-nowrap rounded-[3px] transition-colors duration-150 ease-out motion-reduce:transition-none active:text-white focus-visible:text-white focus-visible:outline-2 focus-visible:outline-white focus-visible:outline-offset-4 ${bylineHover ? "is-hover text-white" : "text-white/70"}`}
          >
            <span className="hidden md:inline">A product of</span>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/logos/pts-logo-white.svg"
              alt=""
              className={`block h-6 md:h-7 w-auto transition-opacity duration-150 ease-out motion-reduce:transition-none group-active:opacity-100 group-focus-visible:opacity-100 ${bylineHover ? "opacity-100" : "opacity-60"}`}
            />
          </a>
        </div>

        {/* Desktop — Label Large (14px / 500) with pill state layers */}
        <ul className="hidden md:flex gap-1">
          {navLinks.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                onClick={() => gaEvent("nav_click", { label: link.label, href: link.href, location: "desktop" })}
                className="block px-4 py-2 rounded-full text-sm font-bold tracking-[0.1px] text-white hover:text-primary hover:bg-primary/8 transition-colors"
              >
                {link.label}
              </Link>
            </li>
          ))}
        </ul>

        {/* Mobile — MD3 icon button (40×40 circle, state layer) */}
        <button
          className="md:hidden w-10 h-10 flex flex-col items-center justify-center gap-[5px] rounded-full hover:bg-on-surface/8 transition-colors text-on-surface-variant"
          onClick={() => {
            gaEvent("mobile_menu_toggle", { state: menuOpen ? "closed" : "open" });
            setMenuOpen(!menuOpen);
          }}
          aria-label="Toggle menu"
          aria-expanded={menuOpen}
        >
          <span className="block w-5 h-[1.5px] bg-current" />
          <span className="block w-5 h-[1.5px] bg-current" />
          <span className="block w-5 h-[1.5px] bg-current" />
        </button>
      </nav>

      {/* Mobile drawer — surface-variant tint */}
      {menuOpen && (
        <ul className="md:hidden bg-surface-variant px-4 py-3 flex flex-col gap-1">
          {navLinks.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                className="block px-4 py-3 rounded-full text-sm font-bold tracking-[0.1px] text-on-surface-variant hover:bg-on-surface/8 hover:text-primary transition-colors"
                onClick={() => { gaEvent("nav_click", { label: link.label, href: link.href, location: "mobile" }); setMenuOpen(false); }}
              >
                {link.label}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </header>
  );
}
