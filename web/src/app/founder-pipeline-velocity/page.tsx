import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder pipeline velocity — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  pipeline_total_prospects: number;
  pipeline_in_negotiation: number;
  pipeline_signed_not_active: number;
  pipeline_active: number;
  pipeline_paused: number;
  pipeline_churned_30d: number;
  median_days_lead_to_signed: number;
  median_days_signed_to_active: number;
  median_days_active_lifetime: number;
  win_rate_pct_30d: number;
  win_rate_pct_90d: number;
  total_pipeline_value_rupees: number;
  qualified_pipeline_value_rupees: number;
  closed_won_value_30d_rupees: number;
  cycle_time_p50_days: number;
  cycle_time_p90_days: number;
};

type ChainRow = {
  chain_id: string;
  chain_name: string;
  stage: string;
  default_amc_tier: string | null;
  default_monthly_fee_rupees: number | null;
  total_hospitals_target: number | null;
  hospitals_onboarded_count: number | null;
  pipeline_value_rupees: number;
  days_in_current_stage: number;
  created_at: string;
};

function Card({ title, val, sub, danger, ok, warn, info }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean; info?: boolean }) {
  const tone = danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : warn ? "text-[var(--color-warn)]" : info ? "text-[var(--color-info)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${tone}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function FunnelBar({ label, count, max, tone }: { label: string; count: number; max: number; tone: string }) {
  const pct = max > 0 ? Math.max(2, Math.round((count / max) * 100)) : 0;
  return (
    <div className="space-y-1">
      <div className="flex items-baseline justify-between text-xs">
        <span className="text-[var(--color-muted)]">{label}</span>
        <span className="tabular-nums font-medium">{formatNumber(count)}</span>
      </div>
      <div className="h-3 w-full rounded bg-[var(--color-border)]/40 overflow-hidden">
        <div className={`h-full ${tone}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

function stageTone(stage: string): string {
  switch (stage) {
    case "negotiating": return "text-[var(--color-warn)]";
    case "signed":
    case "onboarding": return "text-[var(--color-info)]";
    case "live":
    case "active": return "text-[var(--color-ok)]";
    case "paused": return "text-[var(--color-warn)]";
    case "churned":
    case "offboarded": return "text-[var(--color-danger)]";
    default: return "text-[var(--color-muted)]";
  }
}

export default async function FounderPipelineVelocityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: sumData, error: sumErr }, { data: chainData, error: chainErr }] = await Promise.all([
    supabase.rpc("founder_pipeline_velocity_summary"),
    supabase.rpc("founder_pipeline_velocity_by_chain", { p_limit: 30 }),
  ]);
  if (sumErr) throw new Error(`founder_pipeline_velocity_summary: ${sumErr.message}`);
  if (chainErr) throw new Error(`founder_pipeline_velocity_by_chain: ${chainErr.message}`);

  const s = (sumData?.[0] ?? null) as Summary | null;
  const chains = (chainData ?? []) as ChainRow[];

  const funnelMax = s ? Math.max(
    s.pipeline_total_prospects,
    s.pipeline_in_negotiation,
    s.pipeline_signed_not_active,
    s.pipeline_active,
    s.pipeline_paused,
    s.pipeline_churned_30d,
    1,
  ) : 1;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Founder pipeline velocity</h1>
        <span className="text-xs text-[var(--color-muted)]">AMC sales funnel · win-rate · cycle-time · per-chain stage</span>
      </header>

      {s ? (
        <>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Prospects" val={formatNumber(s.pipeline_total_prospects)} sub="top of funnel" />
            <Card title="In negotiation" val={formatNumber(s.pipeline_in_negotiation)} warn sub="active deals" />
            <Card title="Signed not active" val={formatNumber(s.pipeline_signed_not_active)} info sub="onboarding" />
            <Card title="Active" val={formatNumber(s.pipeline_active)} ok sub="chains + AMCs" />
            <Card title="Paused" val={formatNumber(s.pipeline_paused)} warn />
            <Card title="Churned 30d" val={formatNumber(s.pipeline_churned_30d)} danger={s.pipeline_churned_30d > 0} />
            <Card title="Median lead→signed (d)" val={Number(s.median_days_lead_to_signed).toFixed(1)} />
            <Card title="Median signed→active (d)" val={Number(s.median_days_signed_to_active).toFixed(1)} />
            <Card title="Median active lifetime (d)" val={Number(s.median_days_active_lifetime).toFixed(0)} ok />
            <Card title="Win rate 30d" val={`${Number(s.win_rate_pct_30d).toFixed(1)}%`} info />
            <Card title="Win rate 90d" val={`${Number(s.win_rate_pct_90d).toFixed(1)}%`} info />
            <Card title="Cycle p50 (d)" val={Number(s.cycle_time_p50_days).toFixed(1)} />
            <Card title="Cycle p90 (d)" val={Number(s.cycle_time_p90_days).toFixed(1)} sub="tail risk" warn />
            <Card title="Total pipeline ARR" val={`Rs ${formatNumber(Math.round(s.total_pipeline_value_rupees))}`} sub="all open stages" />
            <Card title="Qualified pipeline ARR" val={`Rs ${formatNumber(Math.round(s.qualified_pipeline_value_rupees))}`} info sub="negotiating+signed+onboarding" />
            <Card title="Closed-won ARR 30d" val={`Rs ${formatNumber(Math.round(s.closed_won_value_30d_rupees))}`} ok sub="newly activated AMCs" />
          </div>

          <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <h2 className="text-sm font-semibold mb-3">Velocity funnel</h2>
            <div className="space-y-3">
              <FunnelBar label="Prospects" count={s.pipeline_total_prospects} max={funnelMax} tone="bg-[var(--color-muted)]/60" />
              <FunnelBar label="In negotiation" count={s.pipeline_in_negotiation} max={funnelMax} tone="bg-[var(--color-warn)]" />
              <FunnelBar label="Signed not active" count={s.pipeline_signed_not_active} max={funnelMax} tone="bg-[var(--color-info)]" />
              <FunnelBar label="Active" count={s.pipeline_active} max={funnelMax} tone="bg-[var(--color-ok)]" />
              <FunnelBar label="Paused" count={s.pipeline_paused} max={funnelMax} tone="bg-[var(--color-warn)]/60" />
              <FunnelBar label="Churned 30d" count={s.pipeline_churned_30d} max={funnelMax} tone="bg-[var(--color-danger)]" />
            </div>
          </section>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No summary data.</p>}

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
        <div className="border-b border-[var(--color-border)] p-3">
          <h2 className="text-sm font-semibold">Per-chain pipeline state (top 30)</h2>
          <p className="text-xs text-[var(--color-muted)]">Sorted by stage hotness: negotiating first, then signed/onboarding/prospecting.</p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-[var(--color-border)]/30 text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Chain</th>
                <th className="px-3 py-2 text-left">Stage</th>
                <th className="px-3 py-2 text-left">Tier</th>
                <th className="px-3 py-2 text-right">Monthly fee</th>
                <th className="px-3 py-2 text-right">Target</th>
                <th className="px-3 py-2 text-right">Onboarded</th>
                <th className="px-3 py-2 text-right">Pipeline ARR</th>
                <th className="px-3 py-2 text-right">Days in stage</th>
              </tr>
            </thead>
            <tbody>
              {chains.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-[var(--color-muted)]">No chains tracked yet.</td></tr>
              ) : chains.map((c) => (
                <tr key={c.chain_id} className="border-t border-[var(--color-border)]/40">
                  <td className="px-3 py-2 font-medium">{c.chain_name}</td>
                  <td className={`px-3 py-2 ${stageTone(c.stage)}`}>{c.stage}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{c.default_amc_tier ?? "-"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{c.default_monthly_fee_rupees ? `Rs ${formatNumber(Math.round(c.default_monthly_fee_rupees))}` : "-"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{c.total_hospitals_target ?? 0}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{c.hospitals_onboarded_count ?? 0}</td>
                  <td className="px-3 py-2 text-right tabular-nums">Rs {formatNumber(Math.round(c.pipeline_value_rupees))}</td>
                  <td className={`px-3 py-2 text-right tabular-nums ${c.days_in_current_stage > 60 ? "text-[var(--color-danger)]" : c.days_in_current_stage > 30 ? "text-[var(--color-warn)]" : ""}`}>{c.days_in_current_stage}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <h2 className="text-sm font-semibold text-[var(--color-fg)]">Definitions</h2>
        <p>Pipeline stages combine hospital_chains.status (prospecting, negotiating, signed, onboarding, live, paused, churned, offboarded) with amc_contracts.status (active, paused, expired, cancelled, renewal_failed) for the closed-won tail.</p>
        <p>Pipeline ARR = default_monthly_fee_rupees x max(total_hospitals_target, 1) x 12. Closed-won ARR uses amc_contracts.monthly_fee_rupees x 12 for AMCs activated in the trailing 30 days.</p>
        <p>Cycle time p50/p90 measured from amc_contracts.created_at to activated_at over the trailing 365 days. Lifetime measured from activated_at to deactivated_at (or now() if still live).</p>
        <p>Win rate = activated / created within the window. Days-in-stage uses hospital_chains.updated_at (fallback created_at). {">"} 60d = red, {">"} 30d = amber.</p>
      </section>
    </div>
  );
}
