"use client";

import { Fragment, useState } from "react";
import type { Faq } from "@/lib/routeFaqs";

function FaqItem({ faq }: { faq: Faq }) {
  const [open, setOpen] = useState(false);

  return (
    <div className="border-b border-outline-variant last:border-b-0">
      {/* The question is the heading: search engines treat headings as what the page answers */}
      <h3>
        <button
          onClick={() => setOpen(!open)}
          aria-expanded={open}
          className="w-full flex items-center justify-between gap-3 py-3 text-left text-[13px] font-semibold leading-5 text-on-surface hover:text-primary transition-colors"
        >
          {faq.question}
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
      <p hidden={!open} className="pb-3 text-[12px] leading-relaxed text-on-surface-variant">
        {faq.answer.map((part, i) =>
          typeof part === "string" ? (
            <Fragment key={i}>{part}</Fragment>
          ) : "href" in part ? (
            // Plain <a>: a full load re-initialises the map on the linked route
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

export default function RouteFaqs({ faqs }: { faqs: Faq[] }) {
  if (faqs.length === 0) return null;

  return (
    <section className="mb-4">
      <h2 className="text-[13px] font-semibold text-on-surface mb-2">Questions about this route</h2>
      <div className="border border-outline-variant rounded-xl px-4">
        {faqs.map((faq) => (
          <FaqItem key={faq.question} faq={faq} />
        ))}
      </div>
    </section>
  );
}
