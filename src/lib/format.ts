/** Format a number as Nigerian Naira (e.g. ₦1,500). */
export function formatNaira(amount: number): string {
  return `₦${amount.toLocaleString()}`;
}
