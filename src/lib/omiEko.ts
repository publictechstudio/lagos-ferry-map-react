/**
 * Omi Eko routes that are planned but not yet running are stored with this
 * placeholder duration. Client-safe: no DB import, so components can use it.
 */
export const PLANNED_OMI_EKO_DURATION = 9999;

/** True for an Omi Eko route that is only planned, so it has no schedule, fares or real duration. */
export function isPlannedOmiEkoRoute(route: {
  omi_eko: boolean | null;
  total_base_duration: number | null;
}): boolean {
  return route.omi_eko === true && route.total_base_duration === PLANNED_OMI_EKO_DURATION;
}
