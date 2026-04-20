import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Lagos Ferry Navigation Partnerships | Google Maps, OrnaMap & More",
  description:
    "Get step-by-step ferry directions in Lagos via Google Maps, OrnaMap, Lara, and OpenStreetMap. Lagos Ferry Map data is integrated into popular navigation apps so you can plan multi-modal journeys including water transport.",
  openGraph: {
    title: "Lagos Ferry Navigation Partnerships | Google Maps, OrnaMap & More",
    description:
      "Lagos ferry routes are integrated into Google Maps, OrnaMap, Lara, and OpenStreetMap. Get step-by-step directions including ferry connections across Lagos Lagoon.",
  },
  alternates: { canonical: "/partnerships" },
};

const partnershipsJsonLd = {
  "@context": "https://schema.org",
  "@type": "WebPage",
  name: "Lagos Ferry Navigation Partnerships",
  description:
    "Lagos ferry data integrated into Google Maps, OrnaMap, Lara, and OpenStreetMap for multi-modal step-by-step directions.",
  url: "https://lagosferries.com/partnerships",
  about: [
    { "@type": "Organization", name: "Google Maps", url: "https://maps.google.com" },
    { "@type": "Organization", name: "OrnaMap", url: "https://ornamap.com" },
    { "@type": "Organization", name: "Lara", url: "https://lara.ng" },
    { "@type": "Organization", name: "OpenStreetMap", url: "https://www.openstreetmap.org" },
  ],
};

const partners = [
  {
    name: "Google Maps",
    logo: "/logos/google-maps.png",
    width: 200,
    height: 150,
    body: (
      <>
        Thanks to a partnership with{" "}
        <a
          href="https://lara.ng"
          className="text-primary underline underline-offset-2 hover:text-primary-dark"
          target="_blank"
          rel="noopener noreferrer"
        >
          Lara.ng
        </a>{" "}
        , the ferry routes are included in Google Maps,
        alongside other public transit options.
      </>
    ),
  },
  {
    name: "OrnaMap",
    logo: "/logos/ornamap.png",
    width: 200,
    height: 150,
    body: (
      <>
        OrnaMap includes an integration for topping up your Cowry Card to pay for
        LagFerry and LAMATA trains and buses.{" "}
        <a
          href="https://ornamap.com"
          className="text-primary underline underline-offset-2 hover:text-primary-dark"
          target="_blank"
          rel="noopener noreferrer"
        >
          Download the app
        </a>
        .
      </>
    ),
  },
  {
    name: "Lara",
    logo: "/logos/lara.png",
    width: 100,
    height: 150,
    showName: true,
    body: (
      <>
        Lara is a chat-based navigation tool with the most comprehensive data on danfos and other forms of popular public transit. You don&apos;t need to download an app.
        <br></br>
        <a
          href="https://lara.ng"
          className="text-primary underline underline-offset-2 hover:text-primary-dark"
          target="_blank"
          rel="noopener noreferrer"
        >
          Use it now: Lara.ng
        </a>.
      </>
    ),
  },
  {
    name: "OpenStreetMap",
    logo: "/logos/openstreetmap.png",
    width: 300,
    height: 150,
    body: (
      <>
        OpenStreetMap is a fully open source open data platform. Transportation
        data layers are freely available for tech companies and GIS users
        building on Lagos mobility data.{" "}
        <a
          href="https://tasks.hotosm.org"
          className="text-primary underline underline-offset-2 hover:text-primary-dark"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn more about the partnership
        </a>
        .
      </>
    ),
  },
];

export default function PartnershipsPage() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(partnershipsJsonLd) }}
      />
    <section className="max-w-4xl mx-auto px-4 py-16">
      <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-6">
        Navigation Partnerships
      </h1>

      <div className="space-y-6 text-base leading-6 text-on-surface-variant">
        <p>Want step-by-step directions?</p>
        <p>
          We have established partnerships to integrate our ferry data into popular navigation
          apps and mapping platforms. Now you can get step-by-step directions for the ferries that include bus, train, and other transportation connections. View all the navigation options below.
        </p>

        <div className="inline-flex items-center">
          <div className="inline-flex items-center mb-0 w-53 text-sm font-semibold leading-6 text-white bg-[#012c57] group-hover:bg-[#1976D2] rounded-full px-5 py-2.5 transition-colors duration-200">
            <Link
              href="/map"
              className="inline-flex items-center gap-1.5"
            >
              <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5" aria-hidden>
                <path d="M20.5 3l-.16.03L15 5.1 9 3 3.36 4.9c-.21.07-.36.25-.36.48V20.5c0 .28.22.5.5.5l.16-.03L9 18.9l6 2.1 5.64-1.9c.21-.07.36-.25.36-.48V3.5c0-.28-.22-.5-.5-.5zM15 19l-6-2.11V5l6 2.11V19z" />
              </svg>
              View Full Map Instead
            </Link>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 pt-4">
          {partners.map((partner) => (
            <div
              key={partner.name}
              className="flex flex-col items-center text-center gap-4 bg-white rounded-2xl p-8 shadow-elevation-1"
            >
              <div className="flex items-center gap-2">
                <Image
                  src={partner.logo}
                  alt={`${partner.name} logo`}
                  width={partner.width}
                  height={partner.height}
                  sizes="(max-width: 640px) 50vw, 200px"
                  className="object-contain"
                />
                {"showName" in partner && partner.showName && (
                  <span className="text-[28px] font-semibold text-on-surface leading-none">
                    {partner.name}
                  </span>
                )}
              </div>
              {/* <h2 className="text-[20px] font-semibold leading-7 text-on-surface">
                {partner.name}
              </h2> */}
              <p className="text-sm leading-5 text-on-surface-variant">{partner.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
    </>
  );
}
