export const GA_ID = process.env.NEXT_PUBLIC_GA_ID ?? "";

function canTrack() {
  return Boolean(GA_ID) && typeof window !== "undefined" && typeof window.gtag === "function";
}

// A repeat gtag("config") call re-sends page_view, so route changes send the
// event directly instead.
export function pageview(url: string) {
  if (!canTrack()) return;
  window.gtag("event", "page_view", {
    page_path: url,
    page_location: window.location.href,
    page_title: document.title,
  });
}

export function event(action: string, params?: Record<string, unknown>) {
  if (!canTrack()) return;
  window.gtag("event", action, params);
}

declare global {
  interface Window {
    gtag: (...args: unknown[]) => void;
    dataLayer: unknown[];
  }
}
