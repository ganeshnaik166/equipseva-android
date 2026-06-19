import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Disputes snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  open_now: number;
  stuck_over_7d: number;
  drafts_now: number;
  accepted_30d: number;
  rejected_30d: number;
  withdrawn_30d: number;
  resolution_pct_30d: number;
  filer_hospital_30d: number;
  filer_engineer_30d: number;
  open_money_at_stake_inr: number;
  avg_resolve_hours_30d: number;
  created_today: number;
  resolved_today: number;
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

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function DisputesSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_snapshot_summary");
  if (error) throw new Error(`founder_disputes_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI mediation dashboard · open + resolution + money at stake · pair with /disputes-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total disputes all-time" val={formatNumber(r.total_all_time)} sub="submitted at least once" />
          <Card title="Open now" val={formatNumber(r.open_now)} danger={r.open_now > 0} sub="awaiting mediation" />
          <Card title="Stuck >7d" val={formatNumber(r.stuck_over_7d)} danger={r.stuck_over_7d > 0} sub="SLA breach" />
          <Card title="Drafts now" val={formatNumber(r.drafts_now)} sub="unsubmitted" />
          <Card title="Accepted 30d" val={formatNumber(r.accepted_30d)} ok sub="filer prevailed" />
          <Card title="Rejected 30d" val={formatNumber(r.rejected_30d)} sub="filer lost" />
          <Card title="Withdrawn 30d" val={formatNumber(r.withdrawn_30d)} sub="filer pulled" />
          <Card title="Resolution % 30d" val={`${Number(r.resolution_pct_30d).toFixed(1)}%`} ok sub="resolved / submitted" />
          <Card title="Filer: hospital 30d" val={formatNumber(r.filer_hospital_30d)} />
          <Card title="Filer: engineer 30d" val={formatNumber(r.filer_engineer_30d)} />
          <Card title="Open money at stake" val={inr(r.open_money_at_stake_inr)} danger={r.open_money_at_stake_inr > 0} />
          <Card title="Avg resolve hrs 30d" val={Number(r.avg_resolve_hours_30d).toFixed(1)} />
          <Card title="Created today" val={formatNumber(r.created_today)} />
          <Card title="Resolved today" val={formatNumber(r.resolved_today)} ok />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
