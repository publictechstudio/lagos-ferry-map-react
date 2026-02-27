# Lagos Ferry Map

A Next.js web application providing information about ferry routes in Lagos, Nigeria.

## Project Overview

This app helps users navigate Lagos using the waterway ferry system. It features:
- Interactive Leaflet map of all ferry routes
- Route and terminal directory
- Ferry service information and guides
- About page with FAQ accordion

## Tech Stack

- **Framework**: Next.js 15 (App Router, Turbopack)
- **Language**: TypeScript
- **Styling**: Tailwind CSS v4, MUI (Material UI)
- **Database**: Neon PostgreSQL (serverless)
- **Map**: Leaflet.js
- **Runtime**: Node.js 20

## Project Structure

```
src/
  app/           # Next.js App Router pages
    about/       # About page
    api/         # API routes
    directory/   # Ferry directory
    map/         # Interactive map
    partnerships/ # Partnerships page
  components/    # React components
  lib/           # Database and utility functions
    db.ts        # Neon database connection
    facilities.ts
    routes.ts
    terminals.ts
  types/         # TypeScript types
public/          # Static assets
```

## Environment Variables

- `DATABASE_URL` - Neon PostgreSQL connection string (required)

## Development

```bash
npm run dev -- --port 5000 --hostname 0.0.0.0
```

## Deployment

- Target: Autoscale
- Build: `npm run build`
- Run: `npm run start -- --port 5000 --hostname 0.0.0.0`
