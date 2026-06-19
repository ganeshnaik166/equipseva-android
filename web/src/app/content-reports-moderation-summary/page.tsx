import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Content reports moderation summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  reports_today: number;
  reports_7d: number;
  reports_30d: number;
  pending_reports: number;
  pending_over_24h: number;
  actioned_30d: number;
  dismissed_30d: number;
  avg_resolution_hours_30d: number;
  abuse_reports_30d: number;
  scam_reports_30d: number;
  distinct_targets_30d: number;
  repeat_reporters_30d: number;
  blocks_created_30d: number;
  top_blocked_count_30d: number;
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

export default async function ContentReportsModerationSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_content_reports_moderation_summary");
  if (error) throw new Error(`founder_content_reports_moderation_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Content reports moderation summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI community-safety dashboard · today / 7d / 30d windows · user-reported content + block-list velocity — no report bodies surfaced (DPDP)</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Reports today" val={formatNumber(r.reports_today)} sub="IST day" danger={r.reports_today > 5} />
          <Card title="Reports 7d" val={formatNumber(r.reports_7d)} />
          <Card title="Reports 30d" val={formatNumber(r.reports_30d)} />
          <Card title="Pending queue" val={formatNumber(r.pending_reports)} danger={r.pending_reports > 10} sub="awaiting triage" />
          <Card title="Pending over 24h" val={formatNumber(r.pending_over_24h)} danger={r.pending_over_24h > 0} sub="SLA breach" />
          <Card title="Actioned 30d" val={formatNumber(r.actioned_30d)} ok={r.actioned_30d > 0} sub="takedown / sanction" />
          <Card title="Dismissed 30d" val={formatNumber(r.dismissed_30d)} sub="no-violation" />
          <Card title="Avg resolution hours 30d" val={formatNumber(r.avg_resolution_hours_30d)} sub="created -> reviewed" />
          <Card title="Abuse / harassment 30d" val={formatNumber(r.abuse_reports_30d)} danger={r.abuse_reports_30d > 0} />
          <Card title="Scam / illegal 30d" val={formatNumber(r.scam_reports_30d)} danger={r.scam_reports_30d > 0} sub="legal escalation risk" />
          <Card title="Distinct targets 30d" val={formatNumber(r.distinct_targets_30d)} sub="unique flagged items" />
          <Card title="Repeat reporters 30d" val={formatNumber(r.repeat_reporters_30d)} sub=">=3 reports filed" />
          <Card title="Blocks created 30d" val={formatNumber(r.blocks_created_30d)} sub="user_blocks edges" />
          <Card title="Top blocked count 30d" val={formatNumber(r.top_blocked_count_30d)} danger={r.top_blocked_count_30d >= 5} sub="max against one account" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
