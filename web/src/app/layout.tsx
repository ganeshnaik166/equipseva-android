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
      <body className="min-h-screen">
        <Suspense fallback={null}>
          <TopBar />
        </Suspense>
        <main className="mx-auto max-w-7xl px-4 py-6">{children}</main>
      </body>
    </html>
  );
}
