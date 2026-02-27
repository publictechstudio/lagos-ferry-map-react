import { sql } from "./db";
import type { Facility } from "@/types/facility";

export async function getFacilities(): Promise<Facility[]> {
  const rows = await sql`
    SELECT
      facility_id,
      old_facility_id,
      modified_at,
      facility_name,
      facility_lat::float  AS facility_lat,
      facility_lon::float  AS facility_lon,
      lga,
      lagos_metro,
      google_maps_url,
      facility_type,
      commercial_transport,
      charter_services,
      status,
      quality,
      image_url,
      life_jackets,
      ownership,
      contact_name,
      contact_email,
      laswa_officer_available,
      source_of_awareness,
      omi_eko,
      assignment,
      additional_notes
    FROM facilities
    WHERE facility_lat IS NOT NULL
      AND facility_lon IS NOT NULL
      AND status IS NOT NULL
      AND status != 'not_in_use'
    ORDER BY facility_name
  `;
  return rows as Facility[];
}
