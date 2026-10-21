/** Format a number as Nigerian Naira (e.g. ₦1,500). */
export function formatNaira(amount: number): string {
  // Postgres numeric columns arrive as strings despite the type, so coerce. A fixed
  // locale keeps the server-rendered HTML identical to what the browser hydrates.
  return `₦${Number(amount).toLocaleString("en-NG")}`;
}

/** Format a duration in minutes (e.g. 45 min, 2 hr, 2 hr 30 min). */
export function formatMinutes(mins: number | null): string | null {
  if (mins == null) return null;
  if (mins < 60) return `${mins} min`;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return m === 0 ? `${h} hr` : `${h} hr ${m} min`;
}

/** Format a Postgres time ("07:30:00") as a 12-hour clock time (7:30 AM). */
export function formatTime(timeStr: string): string {
  const [h, m] = timeStr.split(":");
  const hour = parseInt(h, 10);
  const minute = m;
  const ampm = hour >= 12 ? "PM" : "AM";
  const h12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
  return `${h12}:${minute} ${ampm}`;
}

/** Format a date as month and year (October 2026), in Lagos time so server and browser agree. */
export function formatMonthYear(date: string | Date): string {
  return new Date(date).toLocaleDateString("en-NG", { month: "long", year: "numeric", timeZone: "Africa/Lagos" });
}
