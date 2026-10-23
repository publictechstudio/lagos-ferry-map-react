"use client";

import { Fragment, useState } from "react";
import type { Faq } from "@/lib/faq";

type Variant = "panel" | "page";

const STYLES: Record<Variant, { question: string; answer: string; list: string }> = {
  // Compact, for the map side panels
  panel: {
    question: "py-3 text-[13px] font-semibold leading-5",
    answer: "pb-3 text-[12px] leading-relaxed",
    list: "border border-outline-variant rounded-xl px-4",
  },
  // Full page (/faq), matching the About page sizes
  page: {
    question: "py-5 text-[18px] font-normal leading-7",
    answer: "pb-6 text-base leading-6",
    list: "",
  },
};

function FaqItem({ faq, variant }: { faq: Faq; variant: Variant }) {
  const [open, setOpen] = useState(false);
  const styles = STYLES[variant];

  return (
    <div className="border-b border-outline-variant last:border-b-0">
      {/* The question is the heading: search engines treat headings as what the page answers */}
      <h3>
        <button
          onClick={() => setOpen(!open)}
          aria-expanded={open}
          className={`w-full flex items-center justify-between gap-3 text-left text-on-surface hover:text-primary transition-colors ${styles.question}`}
        >
          <span>
            {faq.draft && (
              <span className="mr-2 inline-flex px-2 py-0.5 rounded-full bg-[#7B3F00]/15 text-[#7B3F00] text-[11px] font-bold align-middle">
                Draft
              </span>
            )}
            {faq.question}
          </span>
          <svg
            viewBox="0 0 24 24"
            fill="currentColor"
            className={`w-4 h-4 shrink-0 text-on-surface-variant transition-transform duration-200 ${open ? "rotate-180" : ""}`}
            aria-hidden
          >
            <path d="M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z" />
          </svg>
        </button>
      </h3>

      {/* Always rendered (hidden via attribute) so crawlers see the answer in the server HTML. */}
      <p hidden={!open} className={`text-on-surface-variant ${styles.answer}`}>
        {faq.answer.map((part, i) =>
          typeof part === "string" ? (
            <Fragment key={i}>{part}</Fragment>
          ) : "href" in part ? (
            // Plain <a>: a full load re-initialises the map on the linked page
            <a key={i} href={part.href} className="text-primary underline underline-offset-2 hover:opacity-70">
              {part.text}
            </a>
          ) : (
            <strong key={i} className="font-semibold text-on-surface">{part.text}</strong>
          ),
        )}
      </p>
    </div>
  );
}

export default function FaqList({
  faqs,
  title,
  variant = "panel",
}: {
  faqs: Faq[];
  /** Section heading; omit when the page already provides one. */
  title?: string;
  variant?: Variant;
}) {
  if (faqs.length === 0) return null;

  return (
    <section className="mb-4">
      {title && <h2 className="text-[13px] font-semibold text-on-surface mb-2">{title}</h2>}
      <div className={STYLES[variant].list}>
        {faqs.map((faq) => (
          <FaqItem key={faq.question} faq={faq} variant={variant} />
        ))}
      </div>
    </section>
  );
}
