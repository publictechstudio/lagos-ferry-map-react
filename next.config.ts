import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["leaflet"],
  allowedDevOrigins: ["*"],
};

export default nextConfig;
