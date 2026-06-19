import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer tier history summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  events_total: number;
  events_24h: number;
  events_7d: number;
  events_30d: number;
  events_180d: number;
  promotions_30d: number;
  demotions_30d: number;
  cron_compute_30d: number;
  founder_override_30d: number;
  reached_gold_total: number;
  reached_silver_total: number;
  first_promo_none_bronze: number;
  distinct_engineers_30d: number;
  hours_since_last_event: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function EngineerTierHistorySummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_tier_history_summary");
  if (error) throw new Error(`founder_engineer_tier_history_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer tier history summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI append-only ladder ledger pulse · volume + direction + cron-vs-founder mix · pair with /engineer-certifications-snapshot</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Ledger events (all-time)" val={formatNumber(r.events_total)} sub="every tier transition recorded" />
          <Card title="Events 24h" val={formatNumber(r.events_24h)} ok={r.events_24h > 0} sub="last cron tick window" />
          <Card title="Events 7d" val={formatNumber(r.events_7d)} sub="weekly tier churn" />
          <Card title="Events 30d" val={formatNumber(r.events_30d)} sub="monthly ladder activity" />
          <Card title="Events 180d" val={formatNumber(r.events_180d)} sub="half-year horizon" />
          <Card title="Promotions 30d" val={formatNumber(r.promotions_30d)} ok={r.promotions_30d > 0} sub="upward moves only" />
          <Card title="Demotions 30d" val={formatNumber(r.demotions_30d)} danger={r.demotions_30d > 0} sub="watch for spikes" />
          <Card title="Cron compute 30d" val={formatNumber(r.cron_compute_30d)} sub="auto-driven via 03:17 cron" />
          <Card title="Founder override 30d" val={formatNumber(r.founder_override_30d)} sub="manual promote/demote/override" />
          <Card title="Reached Gold (all-time)" val={formatNumber(r.reached_gold_total)} ok={r.reached_gold_total > 0} sub="code-red first-pick milestone" />
          <Card title="Reached Silver (all-time)" val={formatNumber(r.reached_silver_total)} sub="mid-ladder milestone" />
          <Card title="First promo none→bronze" val={formatNumber(r.first_promo_none_bronze)} sub="cold-start activations" />
          <Card title="Distinct engineers 30d" val={formatNumber(r.distinct_engineers_30d)} sub="unique movers this month" />
          <Card title="Hours since last event" val={Number(r.hours_since_last_event).toFixed(1)} danger={Number(r.hours_since_last_event) > 48} sub="cron tick health" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
