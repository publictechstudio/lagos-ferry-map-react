# Analytics & SEO

Reference for how lagosferries.com is instrumented for Google Analytics 4, what
each event is for, and the SEO changes made alongside it. Read this before adding
or changing any tracking — several of the rules below exist because we broke them
once already.

---

## 1. How tracking is wired

Three files carry the whole setup:

| File | Role |
| --- | --- |
| `src/lib/gtag.ts` | Thin wrapper over `window.gtag`. Exposes `pageview()` and `event()`. |
| `src/components/GoogleAnalytics.tsx` | Loads gtag.js, fires the initial page view, tracks client-side route changes. |
| `src/components/TrackedLink.tsx` | Outbound `<a>` that reports a GA event. Lets server components track clicks without becoming client components. |

The measurement ID comes from `NEXT_PUBLIC_GA_ID`. Because it is a
`NEXT_PUBLIC_` variable it is **inlined at build time**, so changing it in Railway
requires a rebuild, not just a restart. If it is unset, `canTrack()` returns false
and every event silently no-ops — there is no error to notice.

### Page views

The inline config snippet in `GoogleAnalytics.tsx` counts the **initial** page
view. The effect counts **subsequent** client-side route changes only. This split
is deliberate; see "Bugs fixed" below.

Note that selecting a facility on the map rewrites the URL with
`window.history.replaceState` (`MapWrapper.tsx`). That bypasses the Next.js
router, so **no page view fires**. This is intentional, but it means the page
views for `/map/{slug}` reflect only people who landed on that deep link
directly. To measure in-session facility browsing, use `select_content`, never
the Pages report.

---

## 2. Event reference

### Primary business events

| Event | Fires when | Key parameters | Defined in |
| --- | --- | --- | --- |
| `home_cta_click` | One of the three home page CTA cards is clicked | `cta_id`, `cta_label`, `cta_destination`, `cta_position` | `CtaCard.tsx` |
| `select_content` | A facility or route is selected, by any means | `content_type`, `item_id`, `item_name`, `lga`, `select_method`, `route_name` | `MapWrapper.tsx` |
| `directions_click` | "View on Google Maps", or a partner navigation app link | `destination`, `item_id`, `item_name`, `partner_section` | `FacilityPanel.tsx`, `partnerships/page.tsx` |
| `search` | A name or address search is performed | `search_type`, `results_count`, `search_term` (name search only), `lga` (address search only) | `FacilityList.tsx` |
| `map_panel_close` | A facility or route detail panel closes | `content_type`, `close_method`, `dwell_seconds` | `MapWrapper.tsx` |

### Secondary events

| Event | Fires when | Key parameters | Defined in |
| --- | --- | --- | --- |
| `nav_click` | A navbar link is clicked | `nav_label`, `href`, `nav_location` | `Navbar.tsx` |
| `mobile_menu_toggle` | The mobile hamburger is tapped | `menu_state` (`open` / `closed`) | `Navbar.tsx` |
| `outbound_link_click` | Footer or OpenStreetMap external link | `destination`, `link_location` | `Footer.tsx`, `partnerships/page.tsx` |
| `locate_me` | The "show my location" map button | none | `MapWrapper.tsx` |
| `layer_toggle` | A map legend layer checkbox | `layer`, `visible` | `FacilityList.tsx` |
| `lga_expand` | An LGA accordion group opens or closes | `lga`, `expanded` | `FacilityList.tsx` |
| `lga_section_toggle` | The "Explore by LGA" section opens or closes | `expanded` | `FacilityList.tsx` |

### `select_method` values

`select_content` is reported in exactly one place — `MapWrapper.handleSelect` —
and callers pass how the selection happened. This is the dimension that answers
"do people use the map, the list, or the search box?"

| Value | Meaning |
| --- | --- |
| `map_marker` | Clicked a pin or star on the map (the default) |
| `sidebar_list` | Clicked a facility row in the LGA accordion |
| `name_search` | Picked a result from the facility name search |
| `proximity_search` | Picked a result from the address / nearest-facility search |
| `map_route` | Clicked a route line on the map |

### `close_method` values

| Value | Meaning |
| --- | --- |
| `close_button` | The panel's own × button |
| `map_click` | Clicked empty map space to dismiss |
| `switched` | Opened a different facility or route without closing first |

`switched` is recorded so that closes are not undercounted relative to opens. If
it were omitted, `dwell_seconds` would be biased toward users who deliberately
dismiss panels, and every "browse straight from one terminal to the next"
session would be invisible.

---

## 3. Bugs fixed, and why they mattered

### `source` was overwriting traffic attribution

`select_content` used to send a parameter named `source` with values like
`name_search`. In GA4, `source` is part of the **manual campaign attribution**
parameter set, so those values surfaced as if they were traffic sources —
meaning sessions that used in-app search were being re-attributed away from
their real acquisition channel. Renamed to `select_method`.

**Rule: never name a parameter `source`, `medium`, `campaign`, `term`, or
`content`.** Also avoid anything prefixed `ga_`, `google_`, or `firebase_`.

### `page_view` was firing twice on load

`pageview()` called `gtag("config", ...)` a second time, and a repeat `config`
call re-sends `page_view` on top of the one the inline snippet already fires.
Route changes now send an explicit `page_view` **event** instead.

### `page_view` was firing twice on navigation

`useSearchParams()` returns a new object on every render, so using it as an
effect dependency re-ran the effect on the extra render passes React performs
during a route transition. Confirmed in DebugView: two hits one second apart
with an identical `page_location`. The effect now depends on the query **string**
and guards on the last tracked URL.

Only *consecutive* duplicates are suppressed, so revisiting a page later in the
same session is still counted correctly.

### `select_content` was firing twice per search

`FacilityList` reported `select_content` and then called `onSelect`, which
reported it again in `MapWrapper`. Every search-driven selection was double
counted. Reporting now happens in one place.

**Historical data caveat:** `select_content` counts for search-driven selections
are inflated for the period before this fix.

### The address search was sending personal data

The proximity search reported the user's typed address as `search_term` — which
could be someone's home address, and Google's terms prohibit sending personal
data to Analytics. The event now fires *after* the address resolves and reports
`lga` (the area of the nearest facility) plus `results_count` instead. The
geographic demand signal is preserved; the door number is not sent.

### Ambiguous parameter names renamed

`nav_click` used `label` and `location`, and `mobile_menu_toggle` used `state`.
None were reserved, but `location` sits close to GA4's `page_location` and the
others are vague. Renamed to `nav_label`, `nav_location`, and `menu_state` while
nothing was registered yet — renaming after registration would mean creating new
custom dimensions and losing continuity.

### Unguarded gtag calls could throw

Events fired before gtag.js finished loading threw a TypeError inside React
click handlers. `canTrack()` now checks `window.gtag` exists and drops the event
instead.

### Home CTAs were never tracked

The three CTA cards are internal Next.js links, so they produced no click event
at all — only a `page_view` for the destination, indistinguishable from arriving
via the navbar or a direct link. They now fire `home_cta_click`.

`cta_id` is a stable machine key (`map`, `navigation`, `learn`) deliberately kept
separate from `cta_label`, which holds the visible copy. Reporting on the label
alone would silently split the time series the day someone rewrites the copy.
`cta_position` is captured so that a future reorder of the cards can be
distinguished from a genuine change in preference.

---

## 4. SEO changes

### Legacy URL redirects

The site replaced an older static HTML site. Inbound links and search engine
results still point at the old URLs, so those now 301 to current pages.

- **Static paths** — `next.config.ts` `redirects()` handles `/map.html`,
  `/directory.html`, `/about.html`, `/partnerships.html`, `/about/ferries`.
- **Dynamic paths** — old `/ferry-facility-{id}-{name}` and
  `/ferry-route-{id}-{names}` URLs are rewritten to handlers at
  `src/app/legacy/facility/[rest]/route.ts` and `.../route/[rest]/route.ts`,
  which resolve the old slug and issue a 301.

`src/lib/legacyRedirect.ts` does the matching. Old slugs concatenated names and
dropped separators, so it compares a "squashed" form (lowercase alphanumerics
only). It tries old ID + name, then name alone, then ID alone, and falls back to
`/directory` or `/map` when nothing matches — so a stale link always lands
somewhere useful rather than a 404.

301s are permanent and **cached aggressively** by both browsers and search
engines. Test changes here carefully; they are hard to walk back.

### About accordion made crawlable

`AboutAccordion.tsx` previously rendered panel content only when open
(`{open && ...}`), so it never appeared in the server HTML and crawlers could
not index it. Content is now always rendered and hidden with the `hidden`
attribute instead. Visually identical, but the text is in the initial HTML.

---

## 5. GA4 configuration required

Code alone is not enough. **GA4 does not backfill** — a parameter is invisible in
reports until it is registered as a custom dimension, and registration only
applies going forward. Register before or immediately after shipping new events.

### Custom dimensions (Admin → Data display → Custom definitions), scope Event

Essential:

| Dimension name | Parameter |
| --- | --- |
| CTA ID | `cta_id` |
| CTA Position | `cta_position` |
| Content Type | `content_type` |
| Item Name | `item_name` |
| Select Method | `select_method` |
| Close Method | `close_method` |
| Search Type | `search_type` |
| Search Results Count | `results_count` |
| Outbound Destination | `destination` |

Worth adding: `lga` (geographic demand) and `route_name` (the only human-readable
route label).

Deliberately skipped as redundant: `cta_label` and `cta_destination` (covered by
`cta_id`), `item_id` (covered by `item_name`), `nav_location` (GA4's built-in
Device category), `link_location` (no variance), `partner_section` (covered by
`destination`).

### Custom metric

`dwell_seconds` is a number to average, not group by, so it belongs on the
**Custom metrics** tab — name "Panel Dwell Seconds", unit Standard.

### Other settings

- **Key event:** mark `directions_click`. It is the closest thing the site has to
  a conversion, and marking it unlocks conversion-rate columns across all
  acquisition and landing-page reports.
- **Data retention:** Admin → Data display → Data retention. The free-tier
  default is **2 months**; set it to 14. Not retroactive.
- **BigQuery export:** Admin → Product links. Daily export only (streaming
  bills per GB). BigQuery stores *every* parameter regardless of whether it was
  registered as a dimension, has no retention cap, and no cardinality limits —
  so it is the escape hatch for the two traps above. Not retroactive either.

### Cardinality warning

`item_name` is high cardinality — there are hundreds of facilities. GA4 standard
reports roll the long tail into `(other)` once row limits are exceeded, which
would quietly wreck "which terminals do people view most". BigQuery has no such
limit; prefer it for that specific question.

---

## 6. Known risks

- **No consent management.** There is no cookie banner or Consent Mode
  implementation. Relevant to NDPR and any EU traffic.
- **Enhanced Measurement "Page changes based on browser history events".** If
  this sub-option is enabled on the data stream, GA4 fires its own `page_view`
  on History API changes — which would both duplicate the manual route-change
  tracking *and* generate page views for `MapWrapper`'s `replaceState` calls.
  Use either that setting or the manual tracking in `GoogleAnalytics.tsx`, never
  both. Verify in Admin → Data streams → Enhanced measurement → gear icon.
- **Enhanced Measurement is on.** GA4 automatically fires a generic `click` event
  for outbound links with `link_url`, `link_domain`, `link_text`. That is where
  the undifferentiated `click` events in reports come from — not this codebase.

---

## 7. Adding new tracking

1. Import `event as gaEvent` from `@/lib/gtag`, or use `TrackedLink` for outbound
   links in server components.
2. One event name, distinguished by parameters. Do not create a new event per
   variant — it burns the 500-event-name budget and makes comparison impossible.
3. Use a stable machine key for the reporting dimension; keep display copy in a
   separate parameter.
4. Avoid the reserved parameter names listed above.
5. Register the custom dimension in GA4 the same day you ship.
6. Verify in Admin → DebugView with the Google Analytics Debugger extension
   before assuming it works.
