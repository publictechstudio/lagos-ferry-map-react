# Lagos Ferry Map

An interactive map and directory of ferry terminals, routes, schedules and fares across Lagos, Nigeria. It's live at [lagosferries.com](https://lagosferries.com) and built by [Public Tech Studio](https://publictech.studio).

People can use it to:

- Browse every active ferry terminal and route on a map, colour-coded by facility quality and operator
- Search for a terminal by name or LGA, or enter an address to find the nearest terminals
- Open a terminal to see where you can travel from it, which routes go there, and when they run
- Open a route to see its stops in each direction, its fares and its weekly schedule
- Download the full network as a [GTFS](https://gtfs.org) feed at `/gtfs.zip`

## Tech stack

- **[Next.js 15](https://nextjs.org)** (App Router, Turbopack) with React 19 and TypeScript
- **[Leaflet](https://leafletjs.com)** for the map, with [Jawg](https://www.jawg.io) "sunny" basemap tiles
- **PostgreSQL**, queried directly with the [`postgres`](https://github.com/porsager/postgres) client (no ORM)
- **Tailwind CSS v4** and **MUI** for styling and icons
- **Google Places API** for address search
- **Google Analytics 4** for usage tracking

## Getting started

### Prerequisites

- Node.js 20+
- Access to the Lagos ferry PostgreSQL database (ask a maintainer for a connection string)

### Environment variables

Create a `.env.local` file in the project root:

```bash
# Required. Postgres connection string; SSL is required.
DATABASE_URL=postgresql://user:password@host:port/dbname

# Required for map tiles to load
NEXT_PUBLIC_JAWG_ACCESS_TOKEN=...

# Optional. Address search returns nothing without it.
GOOGLE_MAPS_API_KEY=...

# Optional. Analytics are turned off without it.
NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX

# Optional. Base URL used in the sitemap (defaults to https://lagosferries.com)
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

The app fails on startup if `DATABASE_URL` isn't set.

### Run locally

```bash
npm install
npm run dev          # http://localhost:3000
npm run dev:clean    # same as above, but clears the .next cache first
```

Other scripts:

```bash
npm run build        # production build
npm run start        # serve the production build
npm run lint
```

## Pages

| Path | What it shows |
|------|---------------|
| `/` | Landing page |
| `/map` | Full-screen interactive map |
| `/map/facility-{id}-{name}` | Map with a terminal selected and its panel open |
| `/map/route/{id}-{origin}-{destination}` | Map with a route selected and its panel open |
| `/directory` | Lists of all terminals (grouped by LGA) and all routes |
| `/about` | About the project, data sources and limitations |
| `/partnerships` | Partnership information |
| `/gtfs-license` | Licence for the GTFS feed |
| `/gtfs.zip` | GTFS feed download |
| `/sitemap.xml`, `/sitemap.txt`, `/robots.txt` | SEO |

Facility and route pages are rendered on the server with their own metadata and schema.org JSON-LD, so each terminal and route can be indexed separately.

## How it works

### Data flow

```
PostgreSQL ──► src/lib/*.ts (SQL queries) ──► Server components (src/app/**/page.tsx)
                                                 │  facilities + routes passed as props
                                                 ▼
                                           MapWrapper (client)
                                           ├── LeafletMap      markers, route lines, layers
                                           ├── FacilityList    search, legend, layer toggles
                                           ├── FacilityPanel   ──► /api/facility-panel/[id]
                                           └── RoutePanel      ──► /api/route-stops/[id]
                                                                   /api/route-periods/[id]
```

1. **Server render.** Each `/map*` page loads every facility and route (`getFacilities()` and `getRoutes()` in `src/lib/`) and passes them to `MapWrapper`. When the URL points to a facility or route, the page also loads that item's panel data ahead of time (`getFacilityPanelData` or `getRoutePanelData`), so the panel shows up immediately and its content is in the HTML for search engines.
2. **Client map.** `MapWrapper` keeps track of what's selected, which layers are hidden and the user's location. `LeafletMap` is loaded only in the browser (`ssr: false`) and shows a static preview image while it loads. Route shapes are stored as WKT `LINESTRING`s and parsed by `src/lib/parseWKT.ts`.
3. **Selecting things.** When someone clicks a marker or route, the map flies to it and the URL changes with `history.replaceState` (no page navigation). The matching panel then fetches its details from the API routes, unless those details came with the server render.
4. **Caching.** Map pages and the facility-panel API use ISR with `revalidate = 60`, so changes to the database show up within about a minute. `/directory` is rendered on every request, and the sitemap is regenerated hourly.

### Database

The app only reads from the database. Data is collected and edited in the separate **lagos_ferry_data_forms** project, which also builds the GTFS feed. These are the main tables:

| Table | Purpose |
|-------|---------|
| `facilities` | Terminals and jetties: location, LGA, category, status, ownership, photos, OMI EKO flag |
| `routes` | Routes: operator, origin and destination facility, WKT geometry, base duration and cost, `archived` flag |
| `route_stops` | Ordered stops per route and direction (`direction_id`, `stop_order`, `cost_to_stop`, `duration_to_stop`) |
| `route_periods` | Service periods: days of the week, start and end times, frequency, per direction |
| `facility_destinations` | Which facilities are reachable from which (with an `is_charter` flag) |
| `gtfs_zip_cache` | A single row (`id = 1`) holding the zipped GTFS feed served at `/gtfs.zip` |

### Filtering rules

The queries hide several kinds of records, and these rules aren't obvious from the UI:

- **Facilities** without coordinates are hidden, and so are those whose `category` starts with `Not included`, unless they are flagged `omi_eko`.
- **Routes** without geometry, or with `archived = true`, are hidden everywhere.
- **Planned OMI EKO routes** (`omi_eko = true` and `total_base_duration = 9999`, a placeholder value) appear on the map as a separate layer that is hidden by default. They never appear as connections in facility panels, and they have no schedule or stops panel.
- **Facility panel destinations** only appear if a live, non-charter route links the two facilities in that direction *and* that route has at least one `route_periods` row for that direction. If a facility has no outgoing destinations, the panel lists the places that lead *to* it instead (`reversed: true`).

### Route direction logic

Routes are stored in one of two ways:

- **Two-way routes** have a full stop list for both `direction_id = 0` and `direction_id = 1`.
- **One-way-recorded routes** only have `direction_id = 0`. For these, the direction of travel is worked out from stop order: an earlier stop to a later stop is direction 0, and the reverse is direction 1.

`src/lib/travelDirection.ts` provides the SQL fragments (`travelDirection` and `validPair`) that handle both cases, so a two-way route isn't listed twice and each row in the panel only shows the schedule for its own direction of travel.

### Map layers

The legend in `FacilityList` lets users toggle these layers:

- **Facility categories:** Developed, Less developed, and Charter only (Charter only is hidden by default)
- **Route operators:** LagFerry (blue) and Commercial operators (grey)
- **OMI EKO:** planned facilities (star markers) and planned routes, both hidden by default

The colours and category keys are defined at the top of `src/components/LeafletMap.tsx`.

### Address search

`FacilityList` sends address queries to `/api/geocode`, which returns Google Places Autocomplete results limited to Nigeria and biased to within 50 km of Lagos. When someone picks a result, `/api/place-details` looks up its coordinates, and the facilities are sorted by straight-line distance (`src/lib/haversine.ts`). Both API routes run on the edge runtime so the Google API key stays on the server.

### URLs and legacy redirects

- Facility slugs look like `facility-{id}-{kebab-name}` and route slugs look like `{id}-{origin}-{destination}`. Only the numeric ID is used to look up the record, so changing a name doesn't break old links.
- Legacy URLs from the previous site (`/ferry-facility-…`, `/ferry-route-…`, `*.html`) are rewritten in `next.config.ts` to handlers in `src/app/legacy/`. These handlers match the old ID or name and return a 301 to the current page.

### Analytics

`src/lib/gtag.ts` wraps GA4, and nothing is sent when `NEXT_PUBLIC_GA_ID` isn't set. Page views on client-side navigation are sent by `GoogleAnalytics.tsx`. Map interactions send custom events, including `select_content` (with `select_method`), `map_panel_close` (with `close_method` and `dwell_seconds`) and `locate_me`.

### Feedback

The feedback popup and the footer both link to a Google Form for feedback and data corrections. The form ID and the ID of its field for pre-filling a location are in `src/lib/constants.ts`.

## Project structure

```
src/
  app/
    page.tsx                  Landing page
    map/                      Map pages (index, facility slug, route slug)
    directory/                Terminal and route directory
    about/, partnerships/, gtfs-license/
    api/
      facility-panel/[id]/    Destinations, connecting routes and schedules for a facility
      route-stops/[id]/       Stops for a route
      route-periods/[id]/     Service periods for a route
      geocode/                Google Places autocomplete proxy
      place-details/          Google Places details proxy
    gtfs.zip/                 Serves the cached GTFS zip from the database
    legacy/                   301 handlers for old URLs
    sitemap.ts, sitemap.txt/, robots.ts
  components/
    MapWrapper.tsx            Client-side state for the map view
    LeafletMap.tsx            Leaflet map, markers, route lines, layer styling
    FacilityList.tsx          Search, results list, legend and layer toggles
    FacilityPanel.tsx         Facility detail panel
    RoutePanel.tsx            Route detail panel
    route-panel/              Stop diagram, schedule and price tables
    ...                       Navbar, Footer, tables, shared UI
  lib/
    db.ts                     Postgres client
    facilities.ts, routes.ts  Main list queries
    facilityPanel.ts, routePanel.ts   Panel queries (used in server rendering)
    travelDirection.ts        Direction-aware SQL helpers
    *Slug.ts, legacyRedirect.ts       URL helpers
    gtag.ts, constants.ts, format.ts, haversine.ts, parseWKT.ts
  types/                      Row types for each table
scripts/
  migrate-to-railway.{sh,mjs} One-off scripts used to move the database from Neon to Railway
```

The facility panel query is written twice, once in `src/lib/facilityPanel.ts` (for server rendering) and once in `src/app/api/facility-panel/[facilityId]/route.ts` (for fetches from the browser). If you change one, change the other to match.

## Licence

The GTFS feed is published under the licence described at [`/gtfs-license`](https://lagosferries.com/gtfs-license).
