/** Convert a display name to a URL-safe kebab-case string. */
export function toKebab(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}
