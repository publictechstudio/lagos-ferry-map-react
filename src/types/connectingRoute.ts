export type ConnectingRoute = {
  route_id: number;
  operator: string | null;
  /** Authoritative total cost, derived from the last route_stops row for this route. */
  last_stop_cost: number | null;
  total_base_duration: number | null;
  origin_name: string | null;
  destination_name: string | null;
  origin_name_short: string | null;
  destination_name_short: string | null;
  travel_direction: number;
};
