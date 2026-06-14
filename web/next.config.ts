import type { NextConfig } from "next";

const config: NextConfig = {
  reactStrictMode: true,

  // r548 — security headers for the founder console. Vercel adds
  // Strict-Transport-Security automatically; the rest of the baseline
  // is what we own. CSP intentionally omitted for now — would need to
  // unblock Supabase + Recharts inline styles and we can revisit when
  // the surface stabilises.
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-DNS-Prefetch-Control", value: "off" },
          {
            key: "Permissions-Policy",
            value:
              "accelerometer=(), autoplay=(), camera=(), encrypted-media=(), fullscreen=(self), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), sync-xhr=(), usb=(), xr-spatial-tracking=()",
          },
        ],
      },
    ];
  },
};

export default config;
