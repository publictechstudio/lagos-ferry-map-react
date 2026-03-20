"use client";

import dynamic from "next/dynamic";
import { useEffect, useRef, useState } from "react";
import type { Map as LMap } from "leaflet";
import type { Facility } from "@/types/facility";
import type { Route } from "@/types/route";
import FacilityList from "./FacilityList";
import FacilityPanel from "./FacilityPanel";
import RoutePanel from "./RoutePanel";
// RoutePanel fetches its own stops/periods data
import { toFacilitySlug } from "@/lib/facilitySlug";
import { toRouteSlug } from "@/lib/routeSlug";
import { parseWKTLineString, latLonBounds } from "@/lib/parseWKT";

const LeafletMap = dynamic(() => import("./LeafletMap"), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center bg-surface-variant">
      <div className="flex flex-col items-center gap-3 text-on-surface-variant">
        <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
        <span className="text-sm">Loading map…</span>
      </div>
    </div>
  ),
});

interface MapWrapperProps {
  facilities: Facility[];
  routes: Route[];
  initialSelected: Facility | null;
  initialSelectedRoute: Route | null;
}

export default function MapWrapper({
  facilities,
  routes,
  initialSelected,
  initialSelectedRoute,
}: MapWrapperProps) {
  const [selected, setSelected] = useState<Facility | null>(initialSelected);
  const [selectedRoute, setSelectedRoute] = useState<Route | null>(initialSelectedRoute);
  const [userLocation, setUserLocation] = useState<[number, number] | null>(null);
  const [locating, setLocating] = useState(false);
  const [hiddenLayers, setHiddenLayers] = useState<Set<string>>(new Set());
  const [mobileCollapsed, setMobileCollapsed] = useState(false);
  const mapRef = useRef<LMap | null>(null);

  const pendingFlyTo = useRef<Facility | null>(initialSelected);
  const pendingRoute = useRef<Route | null>(initialSelectedRoute);

  // After the layout changes size, tell Leaflet to re-measure the container.
  useEffect(() => {
    const id = setTimeout(() => mapRef.current?.invalidateSize(), 350);
    return () => clearTimeout(id);
  }, [selected, selectedRoute, mobileCollapsed]);

  function handleSelect(facility: Facility) {
    setSelected(facility);
    setSelectedRoute(null);
    window.history.replaceState(null, "", `/map/${toFacilitySlug(facility)}`);
    mapRef.current?.flyTo([facility.facility_lat, facility.facility_lon], 15, {
      animate: true,
      duration: 0.8,
    });
  }

  function handleClose() {
    setSelected(null);
    window.history.replaceState(null, "", "/map");
  }

  function handleDeselect() {
    setSelected(null);
    setSelectedRoute(null);
    window.history.replaceState(null, "", "/map");
  }

  function handleSelectRoute(route: Route) {
    setSelectedRoute(route);
    setSelected(null);
    window.history.replaceState(null, "", `/map/route/${toRouteSlug(route)}`);
    const coords = parseWKTLineString(route.geom);
    const bounds = latLonBounds(coords);
    if (bounds && mapRef.current) {
      mapRef.current.fitBounds(bounds, { padding: [40, 40] });
    }
  }

  function handleLocate() {
    if (!navigator.geolocation) return;
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const loc: [number, number] = [pos.coords.latitude, pos.coords.longitude];
        setUserLocation(loc);
        setLocating(false);
        mapRef.current?.flyTo(loc, 15, { animate: true, duration: 1.2 });
      },
      () => setLocating(false),
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  function handleCloseRoute() {
    setSelectedRoute(null);
    window.history.replaceState(null, "", "/map");
  }

  function handleMapReady(map: LMap) {
    mapRef.current = map;
    if (pendingFlyTo.current) {
      const f = pendingFlyTo.current;
      pendingFlyTo.current = null;
      map.setView([f.facility_lat, f.facility_lon], 15);
    } else if (pendingRoute.current) {
      const route = pendingRoute.current;
      pendingRoute.current = null;
      const coords = parseWKTLineString(route.geom);
      const bounds = latLonBounds(coords);
      if (bounds) {
        map.fitBounds(bounds, { padding: [40, 40] });
      }
    }
  }

  const panelOpen = selected !== null || selectedRoute !== null;

  return (
    <div className="w-full h-full flex flex-col md:flex-row">

      {/* ── Map area ───────────────────────────────────────────────── */}
      <div className="relative flex-1 min-h-0 min-w-0">

        <LeafletMap
          facilities={facilities}
          selectedId={selected?.facility_id ?? null}
          onSelect={handleSelect}
          onDeselect={handleDeselect}
          onMapReady={handleMapReady}
          routes={routes}
          selectedRouteId={selectedRoute?.route_id ?? null}
          onSelectRoute={handleSelectRoute}
          userLocation={userLocation}
          hiddenLayers={hiddenLayers}
        />

        {/* Facility list — desktop: absolute overlay inside map area */}
        <div className={`hidden md:block ${panelOpen ? "md:hidden" : ""}`}>
          <FacilityList
            facilities={facilities}
            selected={selected}
            onSelect={handleSelect}
            hiddenLayers={hiddenLayers}
            setHiddenLayers={setHiddenLayers}
          />
        </div>

        {/* Locate me button*/}
        <button
          onClick={handleLocate}
          disabled={locating}
          className="absolute top-3 left-3 md:left-[calc(18rem+0.75rem)] z-[900] w-10 h-10 bg-surface rounded-lg shadow-elevation-2 flex items-center justify-center text-on-surface-variant hover:bg-surface-variant transition-colors disabled:opacity-50"
          aria-label="Show my location"
          title="Show my location"
        >
          {locating ? (
            <div className="w-4 h-4 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          ) : (
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
              <path d="M12 8c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm8.94 3c-.46-4.17-3.77-7.48-7.94-7.94V1h-2v2.06C6.83 3.52 3.52 6.83 3.06 11H1v2h2.06c.46 4.17 3.77 7.48 7.94 7.94V23h2v-2.06c4.17-.46 7.48-3.77 7.94-7.94H23v-2h-2.06zM12 19c-3.87 0-7-3.13-7-7s3.13-7 7-7 7 3.13 7 7-3.13 7-7 7z" />
            </svg>
          )}
        </button>

      </div>

      {/* Facility list — mobile: flex child below map */}
      {!panelOpen && (
        <div className="md:hidden relative z-[1002]">
          <FacilityList
            facilities={facilities}
            selected={selected}
            onSelect={handleSelect}
            hiddenLayers={hiddenLayers}
            setHiddenLayers={setHiddenLayers}
            onCollapsedChange={setMobileCollapsed}
          />
        </div>
      )}

      {/* ── Facility detail panel ──────────────────────────────────── */}
      {selected && (
        <FacilityPanel facility={selected} onClose={handleClose} />
      )}

      {/* ── Route detail panel ────────────────────────────────────── */}
      {selectedRoute && (
        <RoutePanel
          route={selectedRoute}
          onClose={handleCloseRoute}
        />
      )}

    </div>
  );
}
