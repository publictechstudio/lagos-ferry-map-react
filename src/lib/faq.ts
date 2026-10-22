/** A piece of answer text: plain, a link to another page on the site, or the key fact in bold. */
export type FaqPart = string | { text: string; href: string } | { text: string; bold: true };

export type Faq = {
  question: string;
  answer: FaqPart[];
  /** Unpublished hand-written draft. Only ever returned in development, for review. */
  draft?: boolean;
};

/** The answer as plain text, for structured data. */
export function faqPlainText(faq: Faq): string {
  return faq.answer.map((p) => (typeof p === "string" ? p : p.text)).join("");
}

/** Site paths ("/map/…", not "//host") and https URLs. Anything else is not linked. */
const SAFE_HREF = /^(\/(?!\/)|https:\/\/)/;

/**
 * Parse a hand-written answer from the faqs table: plain text with **bold** and
 * [link text](href). Unsafe links (javascript:, //host, …) keep their text only.
 */
export function parseAnswer(text: string): FaqPart[] {
  const parts: FaqPart[] = [];
  let last = 0;
  for (const m of text.matchAll(/\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s]+)\)/g)) {
    if (m.index > last) parts.push(text.slice(last, m.index));
    if (m[1] !== undefined) parts.push({ text: m[1], bold: true });
    else if (SAFE_HREF.test(m[3])) parts.push({ text: m[2], href: m[3] });
    else parts.push(m[2]);
    last = m.index + m[0].length;
  }
  if (last < text.length) parts.push(text.slice(last));
  return parts;
}

/** schema.org FAQPage for a page's questions, or null when there are none. */
export function faqPageJsonLd(faqs: Faq[]) {
  if (faqs.length === 0) return null;
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faq) => ({
      "@type": "Question",
      name: faq.question,
      acceptedAnswer: { "@type": "Answer", text: faqPlainText(faq) },
    })),
  };
}
