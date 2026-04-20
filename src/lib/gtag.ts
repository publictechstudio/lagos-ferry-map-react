export const GA_ID = process.env.NEXT_PUBLIC_GA_ID ?? "";

export function pageview(url: string) {
  if (!GA_ID || typeof window === "undefined") return;
  window.gtag("config", GA_ID, { page_path: url });
}

export function event(action: string, params?: Record<string, unknown>) {
  if (!GA_ID || typeof window === "undefined") return;
  window.gtag("event", action, params);
}

declare global {
  interface Window {
    gtag: (...args: unknown[]) => void;
    dataLayer: unknown[];
  }
}
