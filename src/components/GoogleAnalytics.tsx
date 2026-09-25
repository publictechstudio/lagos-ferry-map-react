"use client";

import Script from "next/script";
import { usePathname, useSearchParams } from "next/navigation";
import { useEffect, useRef } from "react";
import { GA_ID, pageview } from "@/lib/gtag";

export default function GoogleAnalytics() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  // useSearchParams() returns a new object each render, so depend on the string
  // value instead — an object dep re-runs this effect on every render pass.
  const search = searchParams.toString();
  const lastTracked = useRef<string | null>(null);

  useEffect(() => {
    const url = pathname + (search ? `?${search}` : "");
    // The inline config snippet below already counts the initial page view.
    if (lastTracked.current === null) {
      lastTracked.current = url;
      return;
    }
    if (lastTracked.current === url) return;
    lastTracked.current = url;
    pageview(url);
  }, [pathname, search]);

  if (!GA_ID) return null;

  return (
    <>
      <Script
        src={`https://www.googletagmanager.com/gtag/js?id=${GA_ID}`}
        strategy="afterInteractive"
      />
      <Script id="google-analytics" strategy="afterInteractive">
        {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','${GA_ID}');`}
      </Script>
    </>
  );
}
