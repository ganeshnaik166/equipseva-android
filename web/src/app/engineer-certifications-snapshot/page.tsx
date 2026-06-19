import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer certifications snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  active_engineers_total: number;
  tier_none_count: number;
  tier_bronze_count: number;
  tier_silver_count: number;
  tier_gold_count: number;
  manual_override_count: number;
  promotions_this_month: number;
  demotions_this_month: number;
  promotions_today: number;
  stalled_over_30d: number;
  promotion_eligible_queue: number;
  avg_days_to_promotion: number;
  history_events_30d: number;
  hours_since_last_compute: number;
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

export default async function EngineerCertificationsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_certifications_snapshot_summary");
  if (error) throw new Error(`founder_engineer_certifications_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer certifications snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI cert-ladder pulse · tier mix + promo/demo flow + stalled + eligible queue · pair with /supervised-training-snapshot-summary</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Active engineers (any tier row)" val={formatNumber(r.active_engineers_total)} />
          <Card title="Tier: None" val={formatNumber(r.tier_none_count)} sub="not yet promoted" />
          <Card title="Tier: Bronze" val={formatNumber(r.tier_bronze_count)} />
          <Card title="Tier: Silver" val={formatNumber(r.tier_silver_count)} ok={r.tier_silver_count > 0} />
          <Card title="Tier: Gold" val={formatNumber(r.tier_gold_count)} ok={r.tier_gold_count > 0} sub="code-red first-pick" />
          <Card title="Manual founder overrides" val={formatNumber(r.manual_override_count)} sub="bypass cron compute" />
          <Card title="Promotions this month" val={formatNumber(r.promotions_this_month)} ok={r.promotions_this_month > 0} sub="supply upgrading" />
          <Card title="Demotions this month" val={formatNumber(r.demotions_this_month)} danger={r.demotions_this_month > 0} sub="watch for spikes" />
          <Card title="Promotions today" val={formatNumber(r.promotions_today)} ok={r.promotions_today > 0} />
          <Card title="Stalled >30d (non-gold)" val={formatNumber(r.stalled_over_30d)} danger={r.stalled_over_30d > 0} sub="skill investment not compounding" />
          <Card title="Promotion-eligible queue" val={formatNumber(r.promotion_eligible_queue)} ok={r.promotion_eligible_queue > 0} sub="passes all next-tier gates" />
          <Card title="Avg days between promotions (180d)" val={Number(r.avg_days_to_promotion).toFixed(1)} sub="ladder velocity" />
          <Card title="Ladder events 30d" val={formatNumber(r.history_events_30d)} sub="any tier change" />
          <Card title="Hours since last compute" val={Number(r.hours_since_last_compute).toFixed(1)} danger={Number(r.hours_since_last_compute) > 48} sub="cron runs 03:17 UTC" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}