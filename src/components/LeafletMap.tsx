"use client";

import { useEffect, useRef } from "react";
import type { Map as LMap, CircleMarker, Circle, Polyline } from "leaflet";
import type { Facility } from "@/types/facility";
import type { Route } from "@/types/route";
import { parseWKTLineString } from "@/lib/parseWKT";

const LAGOS_CENTER: [number, number] = [6.4531, 3.3958];
const INITIAL_ZOOM = 12;
const ZOOM_LABEL_THRESHOLD = 14;

const COLOR_DEVELOPED     = "#1A1A1A";
const COLOR_LESS_DEVELOPED = "#8B2000";
const COLOR_ROUTE         = "#4e4e4e";

function markerColor(quality: string | null): string {
  if (!quality) return COLOR_LESS_DEVELOPED;
  return quality.toLowerCase().startsWith("less")
    ? COLOR_LESS_DEVELOPED
    : COLOR_DEVELOPED;
}

interface LeafletMapProps {
  facilities: Facility[];
  selectedId: number | null;
  onSelect: (facility: Facility) => void;
  onMapReady: (map: LMap) => void;
  routes: Route[];
  selectedRouteId: number | null;
  onSelectRoute: (route: Route) => void;
  userLocation: [number, number] | null;
}

export default function LeafletMap({
  facilities,
  selectedId,
  onSelect,
  onMapReady,
  routes,
  selectedRouteId,
  onSelectRoute,
  userLocation,
}: LeafletMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<LMap | null>(null);
  const markersRef = useRef<Map<number, CircleMarker>>(new Map());
  const routeLinesRef = useRef<Map<number, Polyline>>(new Map());
  const userMarkersRef = useRef<{ dot: CircleMarker; ring: Circle } | null>(null);

  // ── Map initialisation (runs once) ──────────────────────────────────────
  useEffect(() => {
    if (!mapContainerRef.current) return;

    let cancelled = false;

    const initialSelectedId = selectedId;
    const initialSelectedRouteId = selectedRouteId;

    import("leaflet").then((L) => {
      if (cancelled || !mapContainerRef.current) return;

      const map = L.map(mapContainerRef.current, {
        center: LAGOS_CENTER,
        zoom: INITIAL_ZOOM,
        zoomControl: false,
        scrollWheelZoom: true,
      });

      L.control.zoom({ position: "topright" }).addTo(map);

      L.tileLayer("https://tile.jawg.io/jawg-sunny/{z}/{x}/{y}{r}.png?access-token={accessToken}", {
        attribution:
          '<a href="https://jawg.io" title="Tiles Courtesy of Jawg Maps" target="_blank">&copy; <b>Jawg</b>Maps</a> &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        minZoom: 0,
        maxZoom: 22,
        // @ts-expect-error — accessToken is a Jawg-specific option not in Leaflet's TileLayerOptions type
        accessToken: process.env.NEXT_PUBLIC_JAWG_ACCESS_TOKEN,
      }).addTo(map);

      // ── Route polylines (drawn first, so they sit below facility markers) ──
      routes.forEach((route) => {
        const coords = parseWKTLineString(route.geom);
        if (coords.length < 2) return;

        const isSelected = route.route_id === initialSelectedRouteId;

        const polyline = L.polyline(coords, {
          color: isSelected ? COLOR_ROUTE : '#949494',
          weight: isSelected ? 8 : 1,
          opacity: isSelected ? 1 : 1,
        });
        polyline.addTo(map);

        const routeName =
          route.origin_name && route.destination_name
            ? `${route.origin_name} → ${route.destination_name}`
            : `Route #${route.route_id}`;

        polyline.bindTooltip(routeName, { sticky: true });
        polyline.on("click", () => onSelectRoute(route));

        routeLinesRef.current.set(route.route_id, polyline);
      });

      // ── Facility markers ────────────────────────────────────────────────
      const markerData: Array<{ marker: CircleMarker; name: string }> = [];

      facilities.forEach((facility) => {
        const name = facility.facility_name ?? "Unnamed";

        const marker = L.circleMarker([facility.facility_lat, facility.facility_lon], {
          radius: 8,
          fillColor: markerColor(facility.quality),
          color: "#FFFFFF",
          weight: 2,
          opacity: 1,
          fillOpacity: 0.8,
        });
        marker.addTo(map);
        marker.bindTooltip(name, { permanent: false, direction: "top", offset: [0, -5] });
        marker.on("click", () => onSelect(facility));

        markerData.push({ marker, name });
        markersRef.current.set(facility.facility_id, marker);
      });

      // Apply the initial selected facility style.
      if (initialSelectedId !== null) {
        const m = markersRef.current.get(initialSelectedId);
        if (m) {
          m.setStyle({ weight: 4, radius: 15 });
          m.bringToFront();
        }
      }

      // ── Zoom-based permanent labels ───────────────────────────────────
      function updateLabels() {
        const permanent = map.getZoom() >= ZOOM_LABEL_THRESHOLD;
        markerData.forEach(({ marker, name }) => {
          marker.unbindTooltip();
          marker.bindTooltip(name, { permanent, direction: "top", offset: [0, -5] });
        });
      }

      map.on("zoomend", updateLabels);
      updateLabels();

      mapRef.current = map;
      onMapReady(map);
    });

    return () => {
      cancelled = true;
      markersRef.current.clear();
      routeLinesRef.current.clear();
      mapRef.current?.remove();
      mapRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Selected facility highlight ───────────────────────────────────────
  useEffect(() => {
    markersRef.current.forEach((marker, id) => {
      const isSelected = id === selectedId;
      marker.setStyle({ weight: isSelected ? 4 : 2, radius: isSelected ? 15 : 8 });
      if (isSelected) {
        // Bring circle to front in SVG layer
        marker.bringToFront();
        // Bring tooltip to front by re-appending its DOM element
        const tooltipEl = marker.getTooltip()?.getElement();
        if (tooltipEl?.parentNode) {
          tooltipEl.parentNode.appendChild(tooltipEl);
        }
      }
    });
  }, [selectedId]);

  // ── Selected route highlight ──────────────────────────────────────────
  useEffect(() => {
    routeLinesRef.current.forEach((polyline, id) => {
      const isSelected = id === selectedRouteId;
      polyline.setStyle({
        weight: isSelected ? 5 : 3,
        opacity: isSelected ? 1 : 0.5,
      });
      if (isSelected) polyline.bringToFront();
    });
  }, [selectedRouteId]);

  // ── Dim non-stop markers when a route is selected ────────────────────
  useEffect(() => {
    if (selectedRouteId === null) {
      markersRef.current.forEach((marker) => {
        marker.setStyle({ radius: 8, fillOpacity: 0.8, opacity: 1 });
      });
      return;
    }

    fetch(`/api/route-stops/${selectedRouteId}`)
      .then((r) => r.json())
      .then((stops: { stop_id: number }[]) => {
        const stopIds = new Set(stops.map((s) => s.stop_id));
        markersRef.current.forEach((marker, id) => {
          const isStop = stopIds.has(id);
          marker.setStyle({
            radius: isStop ? 8 : 3,
            fillOpacity: isStop ? 0.8 : 0.3,
            opacity: isStop ? 1 : 0.3,
          });
        });
      })
      .catch(() => {/* leave markers as-is on error */});
  }, [selectedRouteId]);

  // ── User location marker ──────────────────────────────────────────────
  useEffect(() => {
    import("leaflet").then((L) => {
      if (userMarkersRef.current) {
        userMarkersRef.current.dot.remove();
        userMarkersRef.current.ring.remove();
        userMarkersRef.current = null;
      }
      if (!userLocation || !mapRef.current) return;

      const [lat, lon] = userLocation;

      const ring = L.circle([lat, lon], {
        radius: 120,
        color: "#1976D2",
        fillColor: "#1976D2",
        fillOpacity: 0.12,
        weight: 1,
        interactive: false,
      }).addTo(mapRef.current);

      const dot = L.circleMarker([lat, lon], {
        radius: 9,
        fillColor: "#1976D2",
        color: "#FFFFFF",
        weight: 3,
        opacity: 1,
        fillOpacity: 1,
        interactive: false,
      }).addTo(mapRef.current);

      userMarkersRef.current = { dot, ring };
    });
  }, [userLocation]);

  return (
    <div
      ref={mapContainerRef}
      className="w-full h-full overflow-hidden"
      aria-label="Interactive map of Lagos ferry facilities and routes"
    />
  );
}
