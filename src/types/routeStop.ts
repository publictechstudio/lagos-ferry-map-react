export type RouteStop = {
  route_stop_id: number;
  route_id: number;
  stop_id: number;
  stop_order: number;
  duration_to_stop: number;
  cost_to_stop: string; // numeric stored as string
  is_stop_mandatory: string; // "Yes" | "No"
  facility_name: string | null;
  lga: string | null;
};
