import Link from "next/link";

const internalLinks = [
  { label: "About", href: "/about" },
  { label: "Interactive Map", href: "/map" },
  { label: "Directory", href: "/directory" },
  { label: "Sitemap", href: "/sitemap.xml" },
  { label: "Robots", href: "/robots.txt" },
];

export default function Footer() {
  return (
    /* MD3 dark surface — on-surface (#1A1B20) */
    <footer id="site-footer" className="bg-[#1A1B20] text-[#C3C7CF] py-10 px-4">
      <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between gap-8">
        <div>
          {/* Title Medium */}
          <p className="text-[#F9F9FF] font-medium text-base mb-2">
            Lagos Ferry Map
          </p>
          {/* Body Small */}
          <p className="text-sm text-[#8E9099] max-w-xs leading-relaxed">
            The first comprehensive map of all ferry services in Lagos, Nigeria.
          </p>
        </div>

        <nav aria-label="Footer navigation">
          {/* Label Large */}
          <ul className="flex flex-wrap gap-2">
            {internalLinks.map((link) => (
              <li key={link.href}>
                <Link
                  href={link.href}
                  className="block px-4 py-2 rounded-full text-sm font-medium tracking-[0.1px] text-[#C3C7CF] hover:text-[#F9F9FF] hover:bg-white/8 transition-colors"
                >
                  {link.label}
                </Link>
              </li>
            ))}
            <li>
              <a
                href="https://docs.google.com/forms/d/e/1FAIpQLSfCkMgguEE1GJ_WhWXBaIKhaILOICt1UqiA85r0m4yz_eEmAw/viewform"
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

      <div className="max-w-6xl mx-auto mt-8 pt-6 border-t border-[#2E2F35] text-sm text-[#8E9099]">
        © 2026 Public Tech Studio
      </div>
    </footer>
  );
}
