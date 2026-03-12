import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'export',
  distDir: 'dist',
  basePath: process.env.NEXT_PUBLIC_BASE_PATH || '',
  turbopack: {
    root: path.resolve(__dirname, "../.."),
  },
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
