import { sql } from "./db";
import type { Facility } from "@/types/facility";

export async function getFacilities(): Promise<Facility[]> {
  const rows = await sql`
    SELECT
      facility_id,
      old_facility_id,
      modified_at,
      facility_name,
      facility_name_short,
      category,
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
      gcs_url,
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
      AND category NOT LIKE 'Not included%'
    ORDER BY facility_name
  `;
  return rows as Facility[];
}

export async function getAllFacilityDestinations(): Promise<{ facility_id: number; destination_name: string }[]> {
  const rows = await sql`
    SELECT fd.facility_id, f.facility_name AS destination_name
    FROM facility_destinations fd
    JOIN facilities f ON f.facility_id = fd.destination_id
    WHERE f.status IS NOT NULL
      AND f.status != 'not_in_use'
      AND fd.is_charter IS FALSE
    ORDER BY fd.facility_id, f.facility_name
  `;
  return rows as { facility_id: number; destination_name: string }[];
}
