import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audit responses summary - EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  responses_24h: number;
  responses_7d: number;
  responses_30d: number;
  responses_90d: number;
  low_rating_30d: number;
  mid_rating_30d: number;
  high_rating_30d: number;
  avg_rating_30d: number;
  with_feedback_30d: number;
  feedback_pct_30d: number;
  distinct_hospitals_30d: number;
  distinct_engineers_30d: number;
  median_response_hours_30d: number;
  last_response_at: string | null;
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

function relTime(iso: string | null): string {
  if (!iso) return "never";
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return "never";
  const mins = Math.max(0, Math.floor((Date.now() - then) / 60000));
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 48) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

export default async function SpotAuditResponsesSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audit_responses_summary");
  if (error) throw new Error(`founder_spot_audit_responses_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;

  const avg = Number(r?.avg_rating_30d ?? 0);
  const avgDanger = r != null && r.responses_30d > 0 && avg < 3;
  const avgOk = avg >= 4;
  const lastMins = r?.last_response_at
    ? Math.max(0, Math.floor((Date.now() - new Date(r.last_response_at).getTime()) / 60000))
    : Number.POSITIVE_INFINITY;
  const streamSilence = lastMins > 7 * 24 * 60;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audit responses summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI hospital-side random-sweep rating ledger - v2.1 PR-D43 - pair with /spot-audit-by-engineer + /spot-audit-rating-distribution</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Responses 24h" val={formatNumber(r.responses_24h)} sub="last day window" />
          <Card title="Responses 7d" val={formatNumber(r.responses_7d)} sub="rolling week" />
          <Card title="Responses 30d" val={formatNumber(r.responses_30d)} sub="30-day pool (base for mix)" />
          <Card title="Responses 90d" val={formatNumber(r.responses_90d)} sub="quarter view" />
          <Card title="Low (1-2) 30d" val={formatNumber(r.low_rating_30d)} danger={r.low_rating_30d > 0} sub="poor-service signal" />
          <Card title="Mid (3) 30d" val={formatNumber(r.mid_rating_30d)} sub="neutral / room to improve" />
          <Card title="High (4-5) 30d" val={formatNumber(r.high_rating_30d)} ok={r.high_rating_30d > 0} sub="happy hospital signal" />
          <Card title="Avg rating 30d" val={avg.toFixed(2)} danger={avgDanger} ok={avgOk} sub="mean over responses_30d" />
          <Card title="With feedback 30d" val={formatNumber(r.with_feedback_30d)} sub="non-empty free-text body" />
          <Card title="Feedback % 30d" val={`${Number(r.feedback_pct_30d).toFixed(1)}%`} sub="engagement depth" />
          <Card title="Hospitals 30d" val={formatNumber(r.distinct_hospitals_30d)} sub="distinct invited hospitals" />
          <Card title="Engineers 30d" val={formatNumber(r.distinct_engineers_30d)} sub="distinct rated engineers" />
          <Card title="Median response 30d" val={`${Number(r.median_response_hours_30d).toFixed(1)}h`} sub="p50 invite-to-respond" />
          <Card title="Last response" val={relTime(r.last_response_at)} danger={streamSilence} sub="telemetry-stream liveness" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
