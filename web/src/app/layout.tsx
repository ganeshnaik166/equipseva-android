import "./globals.css";
import type { Metadata } from "next";
import { Suspense } from "react";
import { TopBar } from "@/components/TopBar";

export const metadata: Metadata = {
  title: "EquipSeva Founder Console",
  description: "Read-mostly cockpit over EquipSeva backend RPCs.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-[radial-gradient(circle_at_top_right,rgba(13,123,69,0.05),transparent_40%),radial-gradient(circle_at_bottom_left,rgba(14,165,233,0.04),transparent_35%)]">
        <Suspense fallback={null}>
          <TopBar />
        </Suspense>
        <main className="mx-auto max-w-7xl px-4 py-6">{children}</main>
        <footer className="mx-auto max-w-7xl px-4 py-6 text-[11px] text-[var(--color-muted)] print:hidden">
          EquipSeva Founder Console · 1710+ ships · 310+ design batches · v0.5
        </footer>
      </body>
    </html>
  );
}
