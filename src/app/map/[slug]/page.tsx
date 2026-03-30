import type { Metadata } from "next";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toFacilitySlug } from "@/lib/facilitySlug";

export const revalidate = 3600;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const facilityId = parseInt(slug.split("-")[1], 10);

  if (!isNaN(facilityId)) {
    const facilities = await getFacilities();
    const facility = facilities.find((f) => f.facility_id === facilityId);

    if (facility) {
      const name = facility.facility_name ?? "Ferry Facility";
      const lga = facility.lga ? ` in ${facility.lga} LGA` : "";
      const type = facility.facility_type ?? "ferry facility";
      const description = `${name}${lga} — a ${type.toLowerCase()} on the Lagos Ferry Map. View routes, schedules, and fares from this terminal.`;

      return {
        title: name,
        description,
        openGraph: {
          title: `${name} — Lagos Ferry Map`,
          description,
          url: `/map/${toFacilitySlug(facility)}`,
        },
        alternates: { canonical: `/map/${toFacilitySlug(facility)}` },
      };
    }
  }

  // Fallback: reconstruct name from slug
  const name = slug
    .split("-")
    .slice(1)
    .join(" ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

  return {
    title: name || "Facility",
    description: `View ferry facility details, routes, and schedules on the Lagos Ferry Map.`,
  };
}

export default async function FacilityMapPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const [facilities, routes, { slug }] = await Promise.all([
    getFacilities(),
    getRoutes(),
    params,
  ]);

  const facilityId = parseInt(slug.split("-")[1], 10);
  const initialSelected =
    !isNaN(facilityId)
      ? (facilities.find((f) => f.facility_id === facilityId) ?? null)
      : null;

  const jsonLd = initialSelected
    ? {
        "@context": "https://schema.org",
        "@type": "Place",
        name: initialSelected.facility_name,
        geo: {
          "@type": "GeoCoordinates",
          latitude: initialSelected.facility_lat,
          longitude: initialSelected.facility_lon,
        },
        ...(initialSelected.lga && {
          address: {
            "@type": "PostalAddress",
            addressRegion: initialSelected.lga,
            addressLocality: "Lagos",
            addressCountry: "NG",
          },
        }),
        ...(initialSelected.image_url && { image: initialSelected.image_url }),
      }
    : null;

  return (
    <>
      {jsonLd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      )}
      <section className="flex flex-col" style={{ height: "calc(100vh - 64px)" }}>
        <div className="flex-1 min-h-0">
          <MapWrapper
            facilities={facilities}
            routes={routes}
            initialSelected={initialSelected}
            initialSelectedRoute={null}
          />
        </div>
      </section>
    </>
  );
}
