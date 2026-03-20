import { toKebab } from "./slug";

/** Build the URL slug for a facility or destination: `{id}-{kebab-name}` */
export function toFacilitySlug(facility: {
  facility_id: number;
  facility_name: string | null;
}): string {
  const slug = toKebab(facility.facility_name ?? "unnamed");
  return `facility-${facility.facility_id}-${slug}`;
}
