import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder action followups summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_followups_aged_7d: number;
  total_followups_aged_30d: number;
  open_disputes_over_7d: number;
  open_disputes_over_30d: number;
  spot_audit_fails_over_7d: number;
  spot_audit_fails_over_30d: number;
  stalled_dsrs_over_7d: number;
  stalled_dsrs_over_30d: number;
  idle_code_red_over_7d: number;
  idle_code_red_over_30d: number;
  oldest_dispute_age_days: number;
  oldest_dsr_age_days: number;
  oldest_code_red_age_days: number;
  oldest_spot_audit_fail_age_days: number;
  founder_actions_7d: number;
  founder_actions_today: number;
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

export default async function FounderActionFollowupsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_founder_action_followups_summary");
  if (error) throw new Error(`founder_founder_action_followups_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Founder action followups summary</h1>
        <span className="text-xs text-[var(--color-muted)]">16-KPI TODO age pulse · disputes/audits/DSRs/code-red aged &gt;7d · oldest-age + founder activity</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total followups aged >7d" val={formatNumber(r.total_followups_aged_7d)} danger={r.total_followups_aged_7d > 0} sub="founder TODO" />
          <Card title="Total followups aged >30d" val={formatNumber(r.total_followups_aged_30d)} danger={r.total_followups_aged_30d > 0} sub="red flag" />
          <Card title="Open disputes >7d" val={formatNumber(r.open_disputes_over_7d)} danger={r.open_disputes_over_7d > 0} sub="needs mediator" />
          <Card title="Open disputes >30d" val={formatNumber(r.open_disputes_over_30d)} danger={r.open_disputes_over_30d > 0} />
          <Card title="Spot-audit fails >7d" val={formatNumber(r.spot_audit_fails_over_7d)} danger={r.spot_audit_fails_over_7d > 0} sub="rating <=2" />
          <Card title="Spot-audit fails >30d" val={formatNumber(r.spot_audit_fails_over_30d)} danger={r.spot_audit_fails_over_30d > 0} />
          <Card title="Stalled DSRs >7d" val={formatNumber(r.stalled_dsrs_over_7d)} danger={r.stalled_dsrs_over_7d > 0} sub="pending hospital sign" />
          <Card title="Stalled DSRs >30d" val={formatNumber(r.stalled_dsrs_over_30d)} danger={r.stalled_dsrs_over_30d > 0} />
          <Card title="Idle code-red >7d" val={formatNumber(r.idle_code_red_over_7d)} danger={r.idle_code_red_over_7d > 0} sub="unresolved" />
          <Card title="Idle code-red >30d" val={formatNumber(r.idle_code_red_over_30d)} danger={r.idle_code_red_over_30d > 0} />
          <Card title="Oldest dispute (days)" val={Number(r.oldest_dispute_age_days).toFixed(1)} danger={Number(r.oldest_dispute_age_days) > 30} />
          <Card title="Oldest DSR (days)" val={Number(r.oldest_dsr_age_days).toFixed(1)} danger={Number(r.oldest_dsr_age_days) > 30} />
          <Card title="Oldest code-red (days)" val={Number(r.oldest_code_red_age_days).toFixed(1)} danger={Number(r.oldest_code_red_age_days) > 7} />
          <Card title="Oldest audit fail (days)" val={Number(r.oldest_spot_audit_fail_age_days).toFixed(1)} danger={Number(r.oldest_spot_audit_fail_age_days) > 30} />
          <Card title="Founder actions 7d" val={formatNumber(r.founder_actions_7d)} ok={r.founder_actions_7d > 0} sub="activity signal" />
          <Card title="Founder actions today" val={formatNumber(r.founder_actions_today)} ok={r.founder_actions_today > 0} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
