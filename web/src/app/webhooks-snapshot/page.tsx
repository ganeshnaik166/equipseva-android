import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Webhooks snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  rzp_events_1h: number;
  rzp_events_24h: number;
  rzp_failed_1h: number;
  rzp_failed_24h: number;
  rzp_success_pct_24h: number | null;
  rzp_last_event_at: string | null;
  payouts_events_24h: number;
  payouts_failed_24h: number;
  payouts_success_pct_24h: number | null;
  payouts_last_event_at: string | null;
  orphan_rows_7d: number;
  exception_rows_7d: number;
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

function fmtPct(v: number | null): string {
  if (v === null || v === undefined) return "—";
  return `${Number(v).toFixed(1)}%`;
}

function fmtAgo(iso: string | null): string {
  if (!iso) return "never";
  const ms = Date.now() - new Date(iso).getTime();
  if (ms < 0) return "now";
  const m = Math.floor(ms / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  return `${d}d ago`;
}

export default async function WebhooksSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_webhooks_snapshot_summary");
  if (error) throw new Error(`founder_webhooks_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Webhooks snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI Razorpay+payouts webhook health · money-pipeline early warning · pair with /webhook-health + /webhook-failures-recent</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Razorpay events 1h" val={formatNumber(r.rzp_events_1h)} sub="incoming payments" />
          <Card title="Razorpay events 24h" val={formatNumber(r.rzp_events_24h)} />
          <Card title="Razorpay failed 1h" val={formatNumber(r.rzp_failed_1h)} danger={r.rzp_failed_1h > 0} sub="recent breakage" />
          <Card title="Razorpay failed 24h" val={formatNumber(r.rzp_failed_24h)} danger={r.rzp_failed_24h > 0} />
          <Card title="Razorpay success % 24h" val={fmtPct(r.rzp_success_pct_24h)} ok={r.rzp_success_pct_24h !== null && r.rzp_success_pct_24h >= 99} danger={r.rzp_success_pct_24h !== null && r.rzp_success_pct_24h < 95} />
          <Card title="Razorpay last event" val={fmtAgo(r.rzp_last_event_at)} sub="recency = liveness" />
          <Card title="Payouts events 24h" val={formatNumber(r.payouts_events_24h)} sub="engineer money out" />
          <Card title="Payouts failed 24h" val={formatNumber(r.payouts_failed_24h)} danger={r.payouts_failed_24h > 0} />
          <Card title="Payouts success % 24h" val={fmtPct(r.payouts_success_pct_24h)} ok={r.payouts_success_pct_24h !== null && r.payouts_success_pct_24h >= 99} danger={r.payouts_success_pct_24h !== null && r.payouts_success_pct_24h < 95} />
          <Card title="Payouts last event" val={fmtAgo(r.payouts_last_event_at)} />
          <Card title="Orphan rows 7d" val={formatNumber(r.orphan_rows_7d)} sub="no_matching_row triage" danger={r.orphan_rows_7d > 0} />
          <Card title="Exception rows 7d" val={formatNumber(r.exception_rows_7d)} sub="handler threw" danger={r.exception_rows_7d > 0} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
