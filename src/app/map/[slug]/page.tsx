import type { Metadata } from "next";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";

export const revalidate = 3600;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  // Reconstruct a readable name from the slug for the page title
  const name = slug.split("-").slice(1).join(" ");
  return {
    title: name
      ? `${name.replace(/\b\w/g, (c) => c.toUpperCase())} — Lagos Ferry Map`
      : "Facility — Lagos Ferry Map",
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

  const facilityId = parseInt(slug.split("-")[0], 10);
  const initialSelected =
    !isNaN(facilityId)
      ? (facilities.find((f) => f.facility_id === facilityId) ?? null)
      : null;

  return (
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
  );
}
