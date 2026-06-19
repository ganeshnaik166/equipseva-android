import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audits snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  invitations_all_time: number;
  responses_all_time: number;
  response_pct_all_time: number;
  invitations_today: number;
  responses_today: number;
  invitations_30d: number;
  responses_30d: number;
  response_pct_30d: number;
  avg_rating_30d: number;
  five_star_pct_30d: number;
  low_rating_count_30d: number;
  open_invitations_now: number;
  expiring_within_24h: number;
  stuck_open_over_5d: number;
  hospitals_audited_30d: number;
  engineers_audited_30d: number;
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

export default async function SpotAuditsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audits_snapshot_summary");
  if (error) throw new Error(`founder_spot_audits_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audits snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI QA dashboard · invitations + responses + ratings + coverage · IST-day scoped</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Invitations all-time" val={formatNumber(r.invitations_all_time)} />
          <Card title="Responses all-time" val={formatNumber(r.responses_all_time)} ok />
          <Card title="Response rate all-time" val={`${Number(r.response_pct_all_time).toFixed(1)}%`} sub="quality signal cap" />
          <Card title="Invitations today" val={formatNumber(r.invitations_today)} sub="IST day" />
          <Card title="Responses today" val={formatNumber(r.responses_today)} sub="IST day" ok={r.responses_today > 0} />
          <Card title="Invitations 30d" val={formatNumber(r.invitations_30d)} />
          <Card title="Responses 30d" val={formatNumber(r.responses_30d)} ok />
          <Card title="Response rate 30d" val={`${Number(r.response_pct_30d).toFixed(1)}%`} sub="hospital engagement" />
          <Card title="Avg rating 30d" val={Number(r.avg_rating_30d).toFixed(2)} sub="/ 5.00" ok={Number(r.avg_rating_30d) >= 4.0} danger={Number(r.avg_rating_30d) > 0 && Number(r.avg_rating_30d) < 3.5} />
          <Card title="5-star share 30d" val={`${Number(r.five_star_pct_30d).toFixed(1)}%`} sub="delight signal" />
          <Card title="Low ratings 30d (≤2★)" val={formatNumber(r.low_rating_count_30d)} sub="investigate" danger={r.low_rating_count_30d > 0} />
          <Card title="Open invitations now" val={formatNumber(r.open_invitations_now)} sub="awaiting response" />
          <Card title="Expiring <24h" val={formatNumber(r.expiring_within_24h)} sub="last-chance nudge" danger={r.expiring_within_24h > 0} />
          <Card title="Stuck open >5d" val={formatNumber(r.stuck_open_over_5d)} sub="follow-up alert" danger={r.stuck_open_over_5d > 0} />
          <Card title="Hospitals audited 30d" val={formatNumber(r.hospitals_audited_30d)} sub="coverage breadth" />
          <Card title="Engineers audited 30d" val={formatNumber(r.engineers_audited_30d)} sub="QA reach" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
