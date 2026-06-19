import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "System throughput hourly summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  jobs_posted_24h: number;
  jobs_completed_24h: number;
  peak_hour_posts_24h: number;
  peak_hour_count_24h: number;
  trough_hour_posts_24h: number;
  trough_hour_count_24h: number;
  business_hours_share_pct: number;
  night_hours_share_pct: number;
  avg_posts_per_hour_24h: number;
  avg_completes_per_hour_24h: number;
  busiest_dow_7d: number;
  busiest_dow_count_7d: number;
};

const DOW = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function fmtHour(h: number): string {
  const hh = String(Math.max(0, Math.min(23, h))).padStart(2, "0");
  return `${hh}:00 IST`;
}

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function SystemThroughputHourlySummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_system_throughput_hourly_summary");
  if (error) throw new Error(`founder_system_throughput_hourly_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">System throughput hourly summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI capacity-planning lens · last 24h IST · peak/trough/dow mix</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Jobs posted 24h" val={formatNumber(r.jobs_posted_24h)} />
          <Card title="Jobs completed 24h" val={formatNumber(r.jobs_completed_24h)} ok />
          <Card title="Peak hour (24h)" val={fmtHour(r.peak_hour_posts_24h)} sub={`${formatNumber(r.peak_hour_count_24h)} posts`} />
          <Card title="Peak hour count" val={formatNumber(r.peak_hour_count_24h)} />
          <Card title="Trough hour (24h)" val={fmtHour(r.trough_hour_posts_24h)} sub={`${formatNumber(r.trough_hour_count_24h)} posts`} />
          <Card title="Trough hour count" val={formatNumber(r.trough_hour_count_24h)} />
          <Card title="Business hours share" val={`${Number(r.business_hours_share_pct).toFixed(1)}%`} sub="09:00-17:59 IST" />
          <Card title="Night hours share" val={`${Number(r.night_hours_share_pct).toFixed(1)}%`} sub="22:00-05:59 IST" danger={Number(r.night_hours_share_pct) > 20} />
          <Card title="Avg posts / hour" val={Number(r.avg_posts_per_hour_24h).toFixed(2)} sub="24h mean" />
          <Card title="Avg completes / hour" val={Number(r.avg_completes_per_hour_24h).toFixed(2)} sub="24h mean" />
          <Card title="Busiest day-of-week (7d)" val={DOW[Math.max(0, Math.min(6, r.busiest_dow_7d))] ?? "-"} sub={`${formatNumber(r.busiest_dow_count_7d)} posts`} />
          <Card title="Busiest dow count" val={formatNumber(r.busiest_dow_count_7d)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
