"use client";

import { useRouter } from "next/navigation";
import type { ReactNode } from "react";

export function ClickableRow({ href, children }: { href: string; children: ReactNode }) {
  const router = useRouter();
  return (
    <tr
      onClick={() => router.push(href)}
      className="bg-surface hover:bg-on-surface/[0.03] transition-colors cursor-pointer group"
    >
      {children}
    </tr>
  );
}
