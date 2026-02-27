export type ConnectingRoute = {
  route_id: number;
  operator: string | null;
  total_base_cost: number | null;
  total_base_duration: number | null;
  origin_name: string | null;
  destination_name: string | null;
  travel_direction: "Inbound" | "Outbound";
};
