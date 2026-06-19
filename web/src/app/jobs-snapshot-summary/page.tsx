import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  open_now: number;
  in_progress_now: number;
  completed_30d: number;
  cancelled_30d: number;
  unassigned_over_24h: number;
  bids_pending_now: number;
  hospitals_active_30d: number;
  engineers_active_30d: number;
  posted_today: number;
  completed_today: number;
  avg_completion_hours: number;
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

export default async function JobsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_snapshot_summary");
  if (error) throw new Error(`founder_jobs_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI marketplace dashboard · today/30d/all-time mix · pair with /jobs-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total jobs all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Open now" val={formatNumber(r.open_now)} sub="awaiting bids" />
          <Card title="In progress now" val={formatNumber(r.in_progress_now)} />
          <Card title="Completed 30d" val={formatNumber(r.completed_30d)} ok />
          <Card title="Cancelled 30d" val={formatNumber(r.cancelled_30d)} sub="friction signal" />
          <Card title="Unassigned >24h" val={formatNumber(r.unassigned_over_24h)} danger={r.unassigned_over_24h > 0} />
          <Card title="Bids pending" val={formatNumber(r.bids_pending_now)} sub="engineer trust" />
          <Card title="Active hospitals 30d" val={formatNumber(r.hospitals_active_30d)} />
          <Card title="Active engineers 30d" val={formatNumber(r.engineers_active_30d)} />
          <Card title="Posted today" val={formatNumber(r.posted_today)} />
          <Card title="Completed today" val={formatNumber(r.completed_today)} ok />
          <Card title="Avg completion (30d, hours)" val={Number(r.avg_completion_hours).toFixed(1)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
