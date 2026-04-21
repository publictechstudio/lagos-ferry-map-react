import Link from "next/link";
import { REPORT_FORM_URL } from "@/lib/constants";

const internalLinks = [
  { label: "About", href: "/about" },
  { label: "Interactive Map", href: "/map" },
  { label: "Navigation Partnerships", href: "/partnerships" },
  { label: "Directory", href: "/directory" },
  { label: "Sitemap", href: "/sitemap.xml" },
  { label: "Robots", href: "/robots.txt" },
];

export default function Footer() {
  return (
    /* MD3 dark surface — on-surface (#1A1B20) */
    <footer id="site-footer" className="bg-[#1A1B20] text-[#C3C7CF]">
      <div className="text-center mb-8 text-sm bg-[#000000] py-4">
        This is a project from Public Tech Studio.{" "}
        <a
          href="https://publictech.studio"
          target="_blank"
          rel="noopener noreferrer"
          className="text-[#F9F9FF] underline underline-offset-2 hover:text-white transition-colors"
        >
          Want to build something great?
        </a>
      </div>
      <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between gap-8 py-4 px-5">
        <div>
          {/* Title Medium */}
          <p className="text-[#F9F9FF] font-medium text-base mb-2">
            Lagos Ferry Map
          </p>
          {/* Body Small */}
          <p className="text-sm text-[#8E9099] max-w-lg leading-relaxed">
            The first comprehensive map of all ferry services in Lagos, Nigeria.
          </p>
        </div>

        <nav aria-label="Footer navigation">
          {/* Label Large */}
          <ul className="grid grid-cols-2 gap-x-4 gap-y-0">
            {internalLinks.map((link) => (
              <li key={link.href}>
                <Link
                  href={link.href}
                  className="block px-4 py-1 rounded-full text-sm font-medium tracking-[0.1px] text-[#C3C7CF] hover:text-[#F9F9FF] hover:bg-white/8 transition-colors"
                >
                  {link.label}
                </Link>
              </li>
            ))}
            <li>
              <a
                href={REPORT_FORM_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="block px-4 py-2 rounded-full text-sm font-medium tracking-[0.1px] text-[#C3C7CF] hover:text-[#F9F9FF] hover:bg-white/8 transition-colors"
              >
                Report Issue
              </a>
            </li>
          </ul>
        </nav>
      </div>

      <div className="max-w-6xl mx-auto mb-8 mt-8 pt-6 border-t border-[#2E2F35] text-sm text-[#8E9099] px-5">
        © 2026 Public Tech Studio
      </div>
    </footer>
  );
}
