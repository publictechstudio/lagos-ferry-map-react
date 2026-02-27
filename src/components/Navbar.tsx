"use client";

import Link from "next/link";
import { useState } from "react";

const navLinks = [
  { label: "About", href: "/about" },
  { label: "Map", href: "/map" },
  { label: "Directory", href: "/directory" },
  { label: "Partnerships", href: "/partnerships" },
];

export default function Navbar() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="sticky top-0 z-5000 bg-[#012c57] shadow-elevation-2">
      {/* MD3 Top App Bar — 64px */}
      <nav className="px-4 h-16 flex items-center justify-between">
        {/* Title Large (22px / 400) */}
        <Link
          href="/"
          className="text-white font-bold text-[22px] leading-7 tracking-tight"
        >
          Lagos Ferry Map
        </Link>

        {/* Desktop — Label Large (14px / 500) with pill state layers */}
        <ul className="hidden md:flex gap-1">
          {navLinks.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
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
          onClick={() => setMenuOpen(!menuOpen)}
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
                onClick={() => setMenuOpen(false)}
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
