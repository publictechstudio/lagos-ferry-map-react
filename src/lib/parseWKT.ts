/**
 * Parse a WKT "LineString Z (lon lat z, ...)" string into Leaflet-compatible
 * [lat, lon] pairs.  Returns an empty array for null / malformed input.
 */
export function parseWKTLineString(wkt: string | null): [number, number][] {
  if (!wkt) return [];
  const match = wkt.match(/\(([^)]+)\)/);
  if (!match) return [];
  return match[1].split(",").map((point) => {
    const parts = point.trim().split(/\s+/);
    return [parseFloat(parts[1]), parseFloat(parts[0])]; // [lat, lon]
  });
}

/** Compute a [[minLat, minLon], [maxLat, maxLon]] bounding box from coordinates. */
export function latLonBounds(
  coords: [number, number][]
): [[number, number], [number, number]] | null {
  if (coords.length === 0) return null;
  const lats = coords.map((c) => c[0]);
  const lons = coords.map((c) => c[1]);
  return [
    [Math.min(...lats), Math.min(...lons)],
    [Math.max(...lats), Math.max(...lons)],
  ];
}
