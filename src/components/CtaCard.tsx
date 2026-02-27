import Link from "next/link";
import type { ReactNode } from "react";

interface CtaCardProps {
  icon: ReactNode;
  title: string;
  description: string;
  href: string;
}

export default function CtaCard({ icon, title, description, href }: CtaCardProps) {
  return (
    <Link
      href={href}
      className="group flex flex-col items-center text-center gap-4 bg-white rounded-2xl p-8 shadow-elevation-1 hover:shadow-elevation-2 transition-shadow duration-200"
    >
      <div className="text-primary w-12 h-12 flex items-center justify-center">
        {icon}
      </div>

      <h3 className="w-60 text-[16px] font-semibold leading-6 text-white bg-[#012c57] group-hover:bg-[#1976D2] rounded-full px-5 py-2.5 transition-colors duration-200">
        {title}
      </h3>

      <p className="text-sm leading-5 text-on-surface-variant">{description}</p>
    </Link>
  );
}
