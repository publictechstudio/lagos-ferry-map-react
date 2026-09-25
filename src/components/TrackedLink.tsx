"use client";

import type { ReactNode } from "react";
import { event as gaEvent } from "@/lib/gtag";

interface TrackedLinkProps {
  href: string;
  eventName: string;
  params?: Record<string, unknown>;
  className?: string;
  children: ReactNode;
}

// Outbound link that reports a GA event. Exists so server components can track
// clicks without becoming client components themselves.
export default function TrackedLink({ href, eventName, params, className, children }: TrackedLinkProps) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={className}
      onClick={() => gaEvent(eventName, params)}
    >
      {children}
    </a>
  );
}
