import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised training snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  pending_accept_now: number;
  active_now: number;
  pending_over_48h: number;
  active_over_14d: number;
  completed_successful_all: number;
  completed_failed_all: number;
  declined_all: number;
  revoked_all: number;
  requested_30d: number;
  signoff_successful_30d: number;
  signoff_failed_30d: number;
  requested_today: number;
  pass_rate_30d_pct: number;
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

export default async function SupervisedTrainingSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_training_snapshot_summary");
  if (error) throw new Error(`founder_supervised_training_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised training snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI training pipeline · active + pass rate + stuck · pair with /supervised-by-week-13wk</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total assignments all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Pending supervisor accept" val={formatNumber(r.pending_accept_now)} sub="awaiting supervisor" />
          <Card title="Active now" val={formatNumber(r.active_now)} sub="trainee shadowing" />
          <Card title="Pending >48h" val={formatNumber(r.pending_over_48h)} danger={r.pending_over_48h > 0} sub="supervisor silent" />
          <Card title="Active >14d" val={formatNumber(r.active_over_14d)} danger={r.active_over_14d > 0} sub="no signoff" />
          <Card title="Completed successful (all)" val={formatNumber(r.completed_successful_all)} ok />
          <Card title="Completed failed (all)" val={formatNumber(r.completed_failed_all)} sub="incl disputed" />
          <Card title="Declined (all)" val={formatNumber(r.declined_all)} />
          <Card title="Revoked (all)" val={formatNumber(r.revoked_all)} sub="founder action" />
          <Card title="Requested 30d" val={formatNumber(r.requested_30d)} />
          <Card title="Signoff successful 30d" val={formatNumber(r.signoff_successful_30d)} ok />
          <Card title="Signoff failed 30d" val={formatNumber(r.signoff_failed_30d)} />
          <Card title="Requested today" val={formatNumber(r.requested_today)} />
          <Card title="Pass rate 30d" val={`${Number(r.pass_rate_30d_pct).toFixed(1)}%`} ok={Number(r.pass_rate_30d_pct) >= 80} danger={Number(r.pass_rate_30d_pct) < 50 && (r.signoff_successful_30d + r.signoff_failed_30d) > 0} sub="success / (success+failed)" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
