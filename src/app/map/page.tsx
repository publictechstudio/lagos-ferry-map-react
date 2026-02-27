import type { Metadata } from "next";
import MapWrapper from "@/components/MapWrapper";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";

export const metadata: Metadata = {
  title: "Map — Lagos Ferry Map",
  description: "Interactive map of all Lagos ferry routes and terminals.",
};

export const revalidate = 3600;

export default async function MapPage() {
  const [facilities, routes] = await Promise.all([getFacilities(), getRoutes()]);

  return (
    <section className="flex flex-col" style={{ height: "calc(100vh - 64px)" }}>
      <div className="flex-1 min-h-0">
        <MapWrapper
          facilities={facilities}
          routes={routes}
          initialSelected={null}
          initialSelectedRoute={null}
        />
      </div>
    </section>
  );
}
