import type { Metadata } from "next";
import Image from "next/image";

export const metadata: Metadata = {
  title: "Navigation Partnerships — Lagos Ferry Map",
  description:
    "Ferry data integrated into popular navigation apps and mapping platforms so Lagos residents get step-by-step, multi-modal directions including water transport.",
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
    <section className="max-w-4xl mx-auto px-4 py-16">
      <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-6">
        Navigation Partnerships
      </h1>

      <div className="space-y-6 text-base leading-6 text-on-surface-variant">
        <p>Want step-by-step directions?</p>
        <p>
          We have established partnerships to integrate our ferry data into popular navigation
          applications and mapping platforms. Now you can get step-by-step directions that include bus, train, and other transportation connections.
        </p>

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
  );
}
