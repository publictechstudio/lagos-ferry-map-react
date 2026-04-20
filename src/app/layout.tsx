import type { Metadata } from "next";
import { Lato } from "next/font/google";
import { Suspense } from "react";
import "./globals.css";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import FeedbackPopup from "@/components/FeedbackPopup";
import GoogleAnalytics from "@/components/GoogleAnalytics";

const lato = Lato({
  subsets: ["latin"],
  weight: ["300", "400", "700"],
  variable: "--font-lato",
});

const BASE_URL =
  process.env.NEXT_PUBLIC_SITE_URL ?? "https://lagosferries.com";

export const metadata: Metadata = {
  metadataBase: new URL(BASE_URL),
  title: {
    default: "Lagos Ferry Map",
    template: "%s — Lagos Ferry Map",
  },
  description:
    "Avoid Lagos traffic by taking the ferry. The first comprehensive map of all ferry services in Lagos, Nigeria — routes, schedules, fares, and terminals.",
  icons: {
    icon: [
      { url: "/favicon-16x16.png", sizes: "16x16", type: "image/png" },
      { url: "/favicon-32x32.png", sizes: "32x32", type: "image/png" },
    ],
    apple: { url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" },
    other: [
      { rel: "icon", url: "/android-chrome-192x192.png", sizes: "192x192", type: "image/png" },
      { rel: "icon", url: "/android-chrome-512x512.png", sizes: "512x512", type: "image/png" },
    ],
  },
  openGraph: {
    type: "website",
    locale: "en_NG",
    siteName: "Lagos Ferry Map",
    title: "Lagos Ferry Map",
    description:
      "The first comprehensive map of all ferry routes, schedules, fares, and terminals in Lagos, Nigeria.",
    url: BASE_URL,
    images: [{ url: "/Open_Graph_Lagos_Ferry_Map.png", width: 1200, height: 630, alt: "Lagos Ferry Map" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Lagos Ferry Map",
    description:
      "The first comprehensive map of all ferry routes, schedules, fares, and terminals in Lagos, Nigeria.",
    images: ["/Open_Graph_Lagos_Ferry_Map.png"],
  },
  alternates: {
    canonical: BASE_URL,
  },
  other: {
    "theme-color": "#012c57",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${lato.className} min-h-screen flex flex-col antialiased`}
        suppressHydrationWarning
      >
        <Suspense>
          <GoogleAnalytics />
        </Suspense>
        <Navbar />
        <main className="flex-1">{children}</main>
        <Footer />
        <FeedbackPopup />
      </body>
    </html>
  );
}
