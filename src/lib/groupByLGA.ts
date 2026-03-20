/** Group items by LGA, sorted alphabetically by LGA name. */
export function groupByLGA<T extends { lga: string | null }>(
  items: T[],
  fallback = "Unknown",
): [string, T[]][] {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const lga = item.lga ?? fallback;
    if (!map.has(lga)) map.set(lga, []);
    map.get(lga)!.push(item);
  }
  return Array.from(map.entries()).sort(([a], [b]) => a.localeCompare(b));
}
