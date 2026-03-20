"use client";

import { useEffect, useRef } from "react";
import type { Map as LMap, CircleMarker, Circle, Polyline, Marker } from "leaflet";
import type { Facility } from "@/types/facility";
import type { Route } from "@/types/route";
import { parseWKTLineString } from "@/lib/parseWKT";

const LAGOS_CENTER: [number, number] = [6.47, 3.3958];
const INITIAL_ZOOM = 12;
const ZOOM_LABEL_THRESHOLD = 14;

const COLOR_ROUTE = "#4e4e4e";

export const ROUTE_OPERATOR_STYLES: Record<string, { color: string; label: string }> = {
  "LagFerry":               { color: "#1565C0", label: "LagFerry" },
  "Commercial Operator":    { color: "#808080", label: "Commercial Operator" },
};

const ROUTE_FALLBACK_COLOR = "#a8a8a8";

function routeOperatorKey(operator: string | null): string {
  if (!operator) return "Commercial Operator";
  const op = operator.trim();
  if (op.startsWith("LagFerry")) return "LagFerry";
  return "Commercial Operator";
}

function routeColor(operator: string | null): string {
  const key = routeOperatorKey(operator);
  return ROUTE_OPERATOR_STYLES[key]?.color ?? ROUTE_FALLBACK_COLOR;
}

export const CATEGORY_STYLES: Record<string, { color: string; label: string }> = {
  "Ferry facility: Developed":      { color: "#1A1A1A", label: "Developed" },
  "Ferry facility: Less developed":  { color: "#8B2000", label: "Less Developed" },
  "Charter only":                    { color: "#2E7D32", label: "Charter Only" },
};

const MARKER_RADIUS = 5.5;
const MARKER_WEIGHT = 1;
const MARKER_OPACITY = 1;
const MARKER_FILL_OPACITY = 0.8;
const MARKER_STROKE_COLOR = "#ffffff";

const MARKER_SELECTED_RADIUS = 20;
const MARKER_SELECTED_WEIGHT = 5;

const CATEGORY_FALLBACK_COLOR = "#8c00ff";
const COLOR_OMI_EKO = "#ffffff";

const OMI_EKO_STAR_SVG = `<svg width="30" height="30" viewBox="0 0 30 30" xmlns="http://www.w3.org/2000/svg">
  <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26"
    fill="${COLOR_OMI_EKO}" stroke="#000000" stroke-width="1" stroke-linejoin="round"/>
</svg>`;

export { COLOR_OMI_EKO };

function markerColor(category: string | null): string {
  if (!category) return CATEGORY_FALLBACK_COLOR;
  return CATEGORY_STYLES[category]?.color ?? CATEGORY_FALLBACK_COLOR;
}

interface LeafletMapProps {
  facilities: Facility[];
  selectedId: number | null;
  onSelect: (facility: Facility) => void;
  onDeselect: () => void;
  onMapReady: (map: LMap) => void;
  routes: Route[];
  selectedRouteId: number | null;
  onSelectRoute: (route: Route) => void;
  userLocation: [number, number] | null;
  hiddenLayers: Set<string>;
}

export default function LeafletMap({
  facilities,
  selectedId,
  onSelect,
  onDeselect,
  onMapReady,
  routes,
  selectedRouteId,
  onSelectRoute,
  userLocation,
  hiddenLayers,
}: LeafletMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<LMap | null>(null);
  const markersRef = useRef<Map<number, CircleMarker>>(new Map());
  const hitAreasRef = useRef<Map<number, CircleMarker>>(new Map());
  const facilityCategoryRef = useRef<Map<number, string>>(new Map());
  const routeLinesRef = useRef<Map<number, Polyline>>(new Map());
  const routeGhostsRef = useRef<Map<number, Polyline>>(new Map());
  const routeOperatorRef = useRef<Map<number, string>>(new Map());
  const omiEkoMarkersRef = useRef<Map<number, Marker>>(new Map());
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

      // Custom pane for Omi Eko stars — sits between tiles (200) and overlay/paths (400)
      const omiEkoPane = map.createPane("omiEkoPane");
      omiEkoPane.style.zIndex = "350";

      // Clicking blank map space clears any selection
      map.on("click", onDeselect);

      L.tileLayer("https://tile.jawg.io/jawg-sunny/{z}/{x}/{y}{r}.png?access-token={accessToken}", {
        attribution:
          '<a href="https://jawg.io" title="Tiles Courtesy of Jawg Maps" target="_blank">&copy; <b>Jawg</b>Maps</a> &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        minZoom: 10,
        maxZoom: 22,
        // @ts-expect-error — accessToken is a Jawg-specific option not in Leaflet's TileLayerOptions type
        accessToken: process.env.NEXT_PUBLIC_JAWG_ACCESS_TOKEN,
      }).addTo(map);

      // ── Route polylines (drawn first, so they sit below facility markers) ──
      routes.forEach((route) => {
        const coords = parseWKTLineString(route.geom);
        if (coords.length < 2) return;

        const isSelected = route.route_id === initialSelectedRouteId;
        const opKey = routeOperatorKey(route.operator);
        const opColor = routeColor(route.operator);

        // Visual polyline — non-interactive, purely for display
        const polyline = L.polyline(coords, {
          color: isSelected ? '#262626' : opColor,
          weight: isSelected ? 6 : 2,
          opacity: isSelected ? 1 : 0.7,
          interactive: false,
        });
        polyline.addTo(map);

        const routeName =
          route.origin_name && route.destination_name
            ? `${route.origin_name} → ${route.destination_name}`
            : `Route #${route.route_id}`;

        // Ghost polyline — wide transparent line for click/touch target
        const ghost = L.polyline(coords, {
          color: '#000000',
          weight: 10,
          opacity: 0,
          interactive: true,
          bubblingMouseEvents: false,
        });
        ghost.addTo(map);
        ghost.bindTooltip(routeName, { sticky: true });
        ghost.on("click", () => onSelectRoute(route));

        routeLinesRef.current.set(route.route_id, polyline);
        routeGhostsRef.current.set(route.route_id, ghost);
        routeOperatorRef.current.set(route.route_id, opKey);
      });

      // ── Omi Eko star markers (drawn first so they sit below facility markers) ──
      const omiEkoIcon = L.divIcon({
        html: OMI_EKO_STAR_SVG,
        className: "",
        iconSize: [30, 30],
        iconAnchor: [12, 12.5],
      });

      facilities.forEach((facility) => {
        if (facility.omi_eko !== "Yes") return;
        const name = facility.facility_name ?? "Unnamed";

        const star = L.marker([facility.facility_lat, facility.facility_lon], {
          icon: omiEkoIcon,
          interactive: true,
          bubblingMouseEvents: false,
          pane: "omiEkoPane",
        });
        star.addTo(map);
        star.bindTooltip(name, { direction: "top", offset: [0, -15] });
        star.on("click", () => onSelect(facility));

        omiEkoMarkersRef.current.set(facility.facility_id, star);
      });

      // ── Facility markers ────────────────────────────────────────────────
      const markerData: Array<{ marker: CircleMarker; name: string }> = [];

      facilities.forEach((facility) => {
        const name = facility.facility_name ?? "Unnamed";
        const cat = facility.category ?? "Unknown";

        // Future Omi Eko facilities are only shown via the Omi Eko star layer
        if (cat === "Future Omi Eko") return;

        // Visual marker — non-interactive, purely for display
        const marker = L.circleMarker([facility.facility_lat, facility.facility_lon], {
          radius: MARKER_RADIUS,
          fillColor: markerColor(facility.category),
          color: MARKER_STROKE_COLOR,
          weight: MARKER_WEIGHT,
          opacity: MARKER_OPACITY,
          fillOpacity: MARKER_FILL_OPACITY,
          interactive: false,
        });
        marker.addTo(map);

        // Hit area — large transparent circle for easy clicking/tapping on mobile.
        const hitArea = L.circleMarker([facility.facility_lat, facility.facility_lon], {
          radius: 20,
          fillColor: '#000000',
          fillOpacity: 0.0,
          stroke: false,
          interactive: true,
          bubblingMouseEvents: false,
        });
        hitArea.addTo(map);
        hitArea.bindTooltip(name, { permanent: false, direction: "top", offset: [0, -8] });
        hitArea.on("click", () => onSelect(facility));

        markerData.push({ marker: hitArea, name });
        markersRef.current.set(facility.facility_id, marker);
        hitAreasRef.current.set(facility.facility_id, hitArea);
        facilityCategoryRef.current.set(facility.facility_id, cat);
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
          marker.bindTooltip(name, { permanent, direction: "top", offset: [0, -8] });
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
      hitAreasRef.current.clear();
      facilityCategoryRef.current.clear();
      routeLinesRef.current.clear();
      routeGhostsRef.current.clear();
      routeOperatorRef.current.clear();
      omiEkoMarkersRef.current.clear();
      mapRef.current?.remove();
      mapRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Selected facility highlight ───────────────────────────────────────
  useEffect(() => {
    markersRef.current.forEach((marker, id) => {
      const isSelected = id === selectedId;
      marker.setStyle({ weight: isSelected ? MARKER_SELECTED_WEIGHT : MARKER_WEIGHT, radius: isSelected ? MARKER_SELECTED_RADIUS : MARKER_RADIUS });
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
      const opKey = routeOperatorRef.current.get(id);
      const opColor = opKey ? (ROUTE_OPERATOR_STYLES[opKey]?.color ?? ROUTE_FALLBACK_COLOR) : ROUTE_FALLBACK_COLOR;
      polyline.setStyle({
        color: isSelected ? '#262626' : opColor,
        weight: isSelected ? 8 : 2,
        opacity: isSelected ? 1 : 0.7,
      });
      if (isSelected) polyline.bringToFront();
    });
  }, [selectedRouteId]);

  // ── Dim non-stop markers when a route is selected ────────────────────
  useEffect(() => {
    if (selectedRouteId === null) {
      markersRef.current.forEach((marker) => {
        marker.setStyle({ radius: MARKER_RADIUS, fillOpacity: MARKER_FILL_OPACITY, opacity: MARKER_OPACITY, weight: MARKER_WEIGHT });
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
            radius: isStop ? 12 : 3,
            fillOpacity: isStop ? 0.8 : 0.3,
            opacity: isStop ? 1 : 0.3,
          });
          if (isStop) marker.bringToFront();
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

  // ── Toggle layer visibility ─────────────────────────────────────────
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    // Toggle category markers (circle markers + hit areas)
    facilityCategoryRef.current.forEach((cat, id) => {
      const marker = markersRef.current.get(id);
      const hitArea = hitAreasRef.current.get(id);
      const hidden = hiddenLayers.has(cat);
      if (marker) {
        if (hidden) marker.remove(); else marker.addTo(map);
      }
      if (hitArea) {
        if (hidden) hitArea.remove(); else hitArea.addTo(map);
      }
    });

    // Toggle route polylines by operator
    routeOperatorRef.current.forEach((opKey, id) => {
      const polyline = routeLinesRef.current.get(id);
      const ghost = routeGhostsRef.current.get(id);
      const hidden = hiddenLayers.has(opKey);
      if (polyline) {
        if (hidden) polyline.remove(); else polyline.addTo(map);
      }
      if (ghost) {
        if (hidden) ghost.remove(); else ghost.addTo(map);
      }
    });

    // Toggle Omi Eko stars
    const omiHidden = hiddenLayers.has("Omi Eko");
    omiEkoMarkersRef.current.forEach((star) => {
      if (omiHidden) star.remove(); else star.addTo(map);
    });
  }, [hiddenLayers]);

  return (
    <div
      ref={mapContainerRef}
      className="w-full h-full overflow-hidden"
      aria-label="Interactive map of Lagos ferry facilities and routes"
    />
  );
}
