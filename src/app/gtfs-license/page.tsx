import type { Metadata } from "next";
import Link from "next/link";
import { getFeedInfo } from "@/lib/gtfs";

export const revalidate = 3600;

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://lagosferries.com";
const DESCRIPTION =
  "Open GTFS dataset of ferry routes, stops and timetables in Lagos, Nigeria, published by Public Tech Studio under Creative Commons Attribution 4.0.";

export const metadata: Metadata = {
  title: "Lagos Ferry GTFS Dataset and License",
  description: DESCRIPTION,
  alternates: { canonical: "/gtfs-license" },
  openGraph: {
    title: "Lagos Ferry GTFS Dataset and License — Lagos Ferry Map",
    description: DESCRIPTION,
  },
};

const linkClass = "text-primary underline underline-offset-2 hover:opacity-70";

/** schema.org Dataset, so Google Dataset Search and other crawlers can list and cite the feed. */
function datasetJsonLd(version: string | null, updatedAt: Date | null) {
  return {
    "@context": "https://schema.org",
    "@type": "Dataset",
    name: "Lagos Ferry GTFS Dataset",
    description: DESCRIPTION,
    url: `${BASE_URL}/gtfs-license`,
    keywords: ["Lagos", "ferry", "GTFS", "public transport", "water transport", "Nigeria"],
    license: "https://creativecommons.org/licenses/by/4.0/",
    isAccessibleForFree: true,
    creator: { "@type": "Organization", name: "Public Tech Studio", url: "https://publictech.studio" },
    publisher: { "@type": "Organization", name: "Public Tech Studio", url: "https://publictech.studio" },
    spatialCoverage: { "@type": "Place", name: "Lagos, Nigeria" },
    // Field data collection began in February 2026; the feed is maintained from then on
    temporalCoverage: "2026-02/..",
    ...(version && { version }),
    ...(updatedAt && { dateModified: updatedAt.toISOString() }),
    distribution: [
      {
        "@type": "DataDownload",
        encodingFormat: "application/zip",
        contentUrl: `${BASE_URL}/gtfs.zip`,
        description: "GTFS feed (zip of routes, stops, trips, stop times, frequencies and shapes)",
      },
    ],
  };
}

export default async function GtfsLicensePage() {
  const { version, updatedAt } = await getFeedInfo();
  const updated = updatedAt
    ? updatedAt.toLocaleDateString("en-US", { day: "numeric", month: "long", year: "numeric", timeZone: "Africa/Lagos" })
    : null;

  return (
    <section className="max-w-4xl mx-auto px-6 py-16">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(datasetJsonLd(version, updatedAt)) }}
      />
      <Link
        href="/"
        className="inline-flex items-center gap-2 text-primary mb-8 hover:opacity-70 transition-opacity"
      >
        <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5" aria-hidden>
          <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" />
        </svg>
        Back to home
      </Link>

      <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-8">
        Lagos Ferry GTFS Dataset and License
      </h1>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">Data Download</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-6">
        <a href="/gtfs.zip" className={linkClass}>
          https://lagosferries.com/gtfs.zip
        </a>
      </p>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">Overview</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-4">
        More than 90 ferry routes and 100 stops across Lagos, including boats to Porto-Novo in Benin
        Republic, with each route&apos;s stops, timetable and path on the water. It covers LagFerry as well as
        licensed and unlicensed commercial operators, in GTFS, the standard format journey planners use.
      </p>
      <p className="text-base leading-7 text-on-surface-variant mb-6">
        The General Transit Feed Specification (GTFS) data published on this website is openly
        available and may be used, shared, and adapted under the terms of this license. By
        accessing this GTFS data, you agree to comply with the license terms below.
      </p>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">Data Owner</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-6">
        This GTFS feed is provided by{" "}
        <a href="https://publictech.studio" className={linkClass} target="_blank" rel="noopener noreferrer">
          Public Tech Studio
        </a>
        .
      </p>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">License</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-4">
        All GTFS data is licensed under the{" "}
        <a
          href="https://creativecommons.org/licenses/by/4.0/"
          className={linkClass}
          target="_blank"
          rel="noopener noreferrer"
        >
          Creative Commons Attribution 4.0 International License (CC BY 4.0)
        </a>
        .
      </p>

      <p className="text-base leading-7 text-on-surface-variant mb-3">You are free to:</p>
      <ul className="mb-6 space-y-2">
        {[
          { term: "Share", def: "copy and redistribute the data in any medium or format" },
          {
            term: "Adapt",
            def: "remix, transform, and build upon the data for any purpose, including commercial use",
          },
        ].map(({ term, def }) => (
          <li key={term} className="flex items-start gap-3 text-base leading-7 text-on-surface-variant">
            <span className="mt-2.5 w-1.5 h-1.5 rounded-full bg-primary shrink-0" />
            <span>
              <strong className="text-on-surface">{term}</strong> — {def}
            </span>
          </li>
        ))}
      </ul>

      <p className="text-base leading-7 text-on-surface-variant mb-3">Under the following condition:</p>
      <ul className="mb-6 space-y-2">
        <li className="flex items-start gap-3 text-base leading-7 text-on-surface-variant">
          <span className="mt-2.5 w-1.5 h-1.5 rounded-full bg-primary shrink-0" />
          <span>
            <strong className="text-on-surface">Attribution</strong> — You must give proper credit
            to Public Tech Studio, include a reference to{" "}
            <a href="https://publictech.studio" className={linkClass} target="_blank" rel="noopener noreferrer">
              https://publictech.studio
            </a>{" "}
            as the source, and indicate if any changes were made.
          </span>
        </li>
      </ul>

      <p className="text-base leading-7 text-on-surface-variant mb-6">
        For full license terms, see:{" "}
        <a
          href="https://creativecommons.org/licenses/by/4.0/"
          className={linkClass}
          target="_blank"
          rel="noopener noreferrer"
        >
          https://creativecommons.org/licenses/by/4.0/
        </a>
      </p>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">Example Attribution</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-6">
        &ldquo;Lagos Ferry GTFS data &copy; 2026 Public Tech Studio, licensed under CC BY 4.0.&rdquo;
      </p>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">No Warranty</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-6">
        This data is provided &ldquo;as is&rdquo;, without warranty. Public Tech Studio is not
        liable for errors, omissions, or any consequences of its use.
      </p>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">Updates</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-6">
        The dataset is updated quarterly, and corrections may be published in between. Users are
        responsible for using the latest version.
      </p>

      <h2 className="text-2xl font-medium text-on-surface mt-8 mb-4">Contact</h2>
      <p className="text-base leading-7 text-on-surface-variant mb-6">
        Public Tech Studio
        <br />
        Email:{" "}
        <a href="mailto:hannah@publictech.studio" className={linkClass}>
          hannah@publictech.studio
        </a>
      </p>

      {(version || updated) && (
        <p className="text-sm text-on-surface-variant mt-12 pt-6 border-t border-black/10">
          {version && <>Version {version}</>}
          {version && updated && " · "}
          {updated && <>last updated {updated}</>}
        </p>
      )}
    </section>
  );
}
