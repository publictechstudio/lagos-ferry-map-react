import type { MetadataRoute } from "next";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toFacilitySlug } from "@/lib/facilitySlug";
import { toRouteSlug } from "@/lib/routeSlug";

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://lagosferries.com";

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [facilities, routes] = await Promise.all([getFacilities(), getRoutes()]);

  const staticPages: MetadataRoute.Sitemap = [
    {
      url: `${BASE_URL}/`,
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 1.0,
    },
    {
      url: `${BASE_URL}/map`,
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 0.9,
    },
    {
      url: `${BASE_URL}/directory`,
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 0.7,
    },
    {
      url: `${BASE_URL}/about`,
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 0.5,
    },
  ];

  const facilityPages: MetadataRoute.Sitemap = facilities.map((f) => ({
    url: `${BASE_URL}/map/${toFacilitySlug(f)}`,
    // Use the DB-stored modification timestamp when available
    lastModified: f.modified_at ? new Date(f.modified_at) : new Date(),
    changeFrequency: "monthly" as const,
    priority: 0.6,
  }));

  const routePages: MetadataRoute.Sitemap = routes.map((r) => ({
    url: `${BASE_URL}/map/route/${toRouteSlug(r)}`,
    lastModified: new Date(),
    changeFrequency: "monthly" as const,
    priority: 0.6,
  }));

  return [...staticPages, ...facilityPages, ...routePages];
}
