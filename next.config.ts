import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["leaflet"],
  allowedDevOrigins: ["*"],
  async redirects() {
    return [
      { source: "/map.html", destination: "/map", permanent: true },
      { source: "/directory.html", destination: "/directory", permanent: true },
      { source: "/about.html", destination: "/about", permanent: true },
      { source: "/partnerships.html", destination: "/partnerships", permanent: true },
      { source: "/about/ferries", destination: "/about", permanent: true },
    ];
  },
  // Legacy /ferry-facility-{id}-{name} and /ferry-route-{id}-{names} URLs resolve to
  // the current slugs via a lookup handler that issues a 301.
  async rewrites() {
    return [
      { source: "/ferry-facility-:rest", destination: "/legacy/facility/:rest" },
      { source: "/ferry-route-:rest", destination: "/legacy/route/:rest" },
    ];
  },
};

export default nextConfig;
