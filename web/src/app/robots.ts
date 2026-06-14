import type { MetadataRoute } from "next";

// The Web Console is founder-only behind magic-link auth. Block every
// crawler unconditionally — no SEO surface, no AI summary surface, and
// search engines indexing /login or /share-style routes is pure harm.
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        disallow: "/",
      },
    ],
  };
}
