/** Build the URL slug for a facility or destination: `{id}-{kebab-name}` */
export function toFacilitySlug(facility: {
  facility_id: number;
  facility_name: string | null;
}): string {
  const name = facility.facility_name ?? "unnamed";
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  return `${facility.facility_id}-${slug}`;
}
