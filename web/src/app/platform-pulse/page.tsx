import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Platform pulse — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { metric: string; value_text: string; value_numeric: number; ord: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

const RUPEE_METRICS = new Set([
  "Total MRR",
  "GMV (30d)",
  "Engineer payouts (30d)",
  "Live escrow balance",
]);

const LINK_BY_METRIC: Record<string, string> = {
  "Total engineers":         "/engineer-utilization",
  "Verified engineers":      "/engineer-utilization",
  "Hospitals (ever-active)": "/hospital-utilization",
  "Active AMCs":             "/amc-tier-distribution",
  "Total MRR":               "/amc-revenue-by-tier",
  "Jobs posted (30d)":       "/jobs-volume-trend",
  "Jobs completed (30d)":    "/jobs-volume-trend",
  "GMV (30d)":               "/commission-revenue-30d",
  "Signups (30d)":           "/signups-by-day-trend",
  "Engineer payouts (30d)":  "/payouts-by-day-trend",
  "Open disputes":           "/open-disputes",
  "Live escrow balance":     "/escrow-balance-rollup",
};

function toneFor(metric: string, value: number): "ok" | "warn" | "danger" | "neutral" {
  if (metric === "Open disputes")        return value > 5 ? "danger" : value > 0 ? "warn" : "ok";
  if (metric === "Live escrow balance")  return value > 0 ? "warn" : "ok";
  return "neutral";
}

export default async function PlatformPulsePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_platform_pulse");
  if (error) throw new Error(`founder_platform_pulse: ${error.message}`);
  const rows = (data ?? []) as Row[];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Platform pulse</h1>
        <span className="text-xs text-[var(--color-muted)]">r700 milestone · daily check-in · click any tile to drill in</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4">
          {rows.map((r) => {
            const v = Number(r.value_numeric);
            const isRupee = RUPEE_METRICS.has(r.metric);
            const display = isRupee ? inr(v) : formatNumber(v);
            const href = LINK_BY_METRIC[r.metric];
            const tone = toneFor(r.metric, v);
            const card = <StatCard label={r.metric} value={display} tone={tone === "neutral" ? undefined : tone} />;
            return href ? (
              <Link key={r.metric} href={href} className="block transition-transform hover:-translate-y-0.5">
                {card}
              </Link>
            ) : (
              <div key={r.metric}>{card}</div>
            );
          })}
        </div>
      </section>
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r722 update.</strong> Each tile now links to its drill-down. Open disputes
        + live escrow balance are tone-coded: warn if non-zero, danger if past threshold.
        Full catalog at <Link href="/ops-index" className="underline">/ops-index</Link>.
      </section>
    </div>
  );
}
