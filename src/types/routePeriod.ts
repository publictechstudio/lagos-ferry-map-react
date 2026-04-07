export type RoutePeriod = {
  route_period_id: number;
  route_id: number;
  direction_id: number;
  morning_service: boolean;
  evening_service: boolean;
  monday: boolean;
  tuesday: boolean;
  wednesday: boolean;
  thursday: boolean;
  friday: boolean;
  saturday: boolean;
  sunday: boolean;
  start_time: string; // "07:00:00"
  end_time: string | null;
  single_daily_departure: boolean;
  average_daily_boat_departures: number | null;
  frequency: string | null;
};
