import type { Metadata } from "next";
import { Lato } from "next/font/google";
import "./globals.css";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import FeedbackPopup from "@/components/FeedbackPopup";

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
  openGraph: {
    type: "website",
    locale: "en_NG",
    siteName: "Lagos Ferry Map",
    title: "Lagos Ferry Map",
    description:
      "The first comprehensive map of all ferry routes, schedules, fares, and terminals in Lagos, Nigeria.",
    url: BASE_URL,
  },
  twitter: {
    card: "summary_large_image",
    title: "Lagos Ferry Map",
    description:
      "The first comprehensive map of all ferry routes, schedules, fares, and terminals in Lagos, Nigeria.",
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
        <Navbar />
        <main className="flex-1">{children}</main>
        <Footer />
        <FeedbackPopup />
      </body>
    </html>
  );
}
