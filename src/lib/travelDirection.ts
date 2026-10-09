import { sql } from "./db";

/**
 * SQL fragments for a pair of route_stops rows (`from` before `to` in travel).
 * Routes that run both ways store a full stop list per direction_id; pairing
 * stops across those lists would make one route appear once per direction.
 * Single-direction routes only have direction_id 0, so the direction there is
 * inferred from stop order.
 */
const bothWays = (routeId: string) =>
  `EXISTS (SELECT 1 FROM route_stops d WHERE d.route_id = ${routeId} AND d.direction_id = 1)`;

/** Direction (0/1) a rider travels going from stop `a` to stop `b`. */
export const travelDirection = (a: string, b: string, routeId: string) =>
  sql.unsafe(
    `(CASE WHEN ${bothWays(routeId)} THEN ${a}.direction_id
           WHEN ${a}.stop_order < ${b}.stop_order THEN 0 ELSE 1 END)`,
  );

/** True when `a` and `b` are a valid in-order pair within the same direction. */
export const validPair = (a: string, b: string, routeId: string) =>
  sql.unsafe(
    `(${a}.direction_id = ${b}.direction_id
      AND (NOT ${bothWays(routeId)} OR ${a}.stop_order < ${b}.stop_order))`,
  );
