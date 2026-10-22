import type { MetadataRoute } from "next";
import { getFacilities } from "@/lib/facilities";
import { getRoutes } from "@/lib/routes";
import { toFacilitySlug } from "@/lib/facilitySlug";
import { toRouteSlug } from "@/lib/routeSlug";
import { getFaqs } from "@/lib/faqs";
import { getFeedInfo } from "@/lib/gtfs";

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://lagosferries.com";

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [facilities, routes, faqs, feed] = await Promise.all([getFacilities(), getRoutes(), getFaqs(), getFeedInfo()]);
  const faqsUpdated = faqs.reduce<Date | null>((latest, f) => (!latest || f.updatedAt > latest ? f.updatedAt : latest), null);

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
    {
      url: `${BASE_URL}/partnerships`,
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 0.5,
    },
    {
      url: `${BASE_URL}/faq`,
      lastModified: faqsUpdated ?? new Date(),
      changeFrequency: "monthly",
      priority: 0.7,
    },
    {
      url: `${BASE_URL}/gtfs-license`,
      lastModified: feed.updatedAt ?? new Date(),
      changeFrequency: "monthly",
      priority: 0.5,
    },
    {
      url: `${BASE_URL}/gtfs.zip`,
      lastModified: feed.updatedAt ?? new Date(),
      changeFrequency: "monthly",
      priority: 0.3,
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
    // Real edit dates, so crawlers can trust them; "now" on every crawl gets ignored
    lastModified: r.modified_at ? new Date(r.modified_at) : new Date(),
    changeFrequency: "monthly" as const,
    priority: 0.6,
  }));

  return [...staticPages, ...facilityPages, ...routePages];
}
