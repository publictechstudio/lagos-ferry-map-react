/** Format a number as Nigerian Naira (e.g. ₦1,500). */
export function formatNaira(amount: number): string {
  // Postgres numeric columns arrive as strings despite the type, so coerce. A fixed
  // locale keeps the server-rendered HTML identical to what the browser hydrates.
  return `₦${Number(amount).toLocaleString("en-NG")}`;
}
