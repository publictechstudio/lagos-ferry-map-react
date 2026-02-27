"use client";

import { useState } from "react";
import type { ReactNode } from "react";

interface AccordionItem {
  title: string;
  icon?: ReactNode;
  content: ReactNode;
}

function AccordionRow({ title, icon, content }: AccordionItem) {
  const [open, setOpen] = useState(false);

  return (
    <div className="border-b border-outline-variant last:border-b-0">
      <button
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        className="w-full flex items-center justify-between gap-4 py-5 text-left text-on-surface hover:text-primary transition-colors"
      >
        <span className="flex items-center gap-3 text-[20px] font-normal leading-7">
          {icon && <span className="shrink-0 text-primary [&>svg]:w-6 [&>svg]:h-6">{icon}</span>}
          {title}
        </span>
        {/* Chevron */}
        <svg
          viewBox="0 0 24 24"
          fill="currentColor"
          className={`w-6 h-6 shrink-0 transition-transform duration-200 ${open ? "rotate-180" : ""}`}
          aria-hidden
        >
          <path d="M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z" />
        </svg>
      </button>

      {open && (
        <div className="pb-6 text-base leading-6 text-on-surface-variant space-y-4">
          {content}
        </div>
      )}
    </div>
  );
}

export default function AboutAccordion({ items }: { items: AccordionItem[] }) {
  return (
    <div className="divide-y-0">
      {items.map((item) => (
        <AccordionRow key={item.title} {...item} />
      ))}
    </div>
  );
}
