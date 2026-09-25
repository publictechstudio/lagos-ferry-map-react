import { getFacilities } from "./facilities";
import { getRoutes } from "./routes";
import { toFacilitySlug } from "./facilitySlug";
import { toRouteSlug } from "./routeSlug";

/** Lowercase alphanumerics only — old slugs concatenated names, dropping separators like "/". */
const squash = (s: string | null | undefined) => (s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");

/** `{oldId}-{squashed-name}` → current path, or a listing page when nothing matches. */
export async function legacyFacilityPath(rest: string): Promise<string> {
  const [, oldId, ...nameParts] = /^(\d+)-?(.*)$/.exec(rest) ?? [];
  const name = squash(nameParts.join(""));
  const facilities = await getFacilities();
  const match =
    facilities.find((f) => f.old_facility_id === oldId && squash(f.facility_name) === name) ??
    facilities.find((f) => squash(f.facility_name) === name) ??
    facilities.find((f) => f.old_facility_id === oldId);
  return match ? `/map/${toFacilitySlug(match)}` : "/directory";
}

export async function legacyRoutePath(rest: string): Promise<string> {
  const name = squash(rest.replace(/^\d+-?/, ""));
  const routes = await getRoutes();
  const match = routes.find(
    (r) => squash(`${r.origin_name}${r.destination_name}`) === name,
  );
  return match ? `/map/route/${toRouteSlug(match)}` : "/map";
}
