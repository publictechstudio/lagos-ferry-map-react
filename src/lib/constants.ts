/** Google Form for feedback / data issue reports. */
export const REPORT_FORM_URL =
  "https://docs.google.com/forms/d/e/1FAIpQLSfCkMgguEE1GJ_WhWXBaIKhaILOICt1UqiA85r0m4yz_eEmAw/viewform";

/** Pre-fill entry ID for the "Which ferry location or route?" question. */
export const FORM_ENTRY_LOCATION = "entry.26660475";

/** Public origin of the site. Behind the host's proxy, request.url is an internal address (e.g. localhost:8080). */
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://lagosferries.com";
