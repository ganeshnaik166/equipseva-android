import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Razorpay webhook events summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  events_1h: number;
  events_24h: number;
  events_7d: number;
  applied_24h: number;
  no_match_24h: number;
  exception_24h: number;
  escrow_flips_7d: number;
  spare_flips_7d: number;
  amc_flips_7d: number;
  refunds_processed_7d: number;
  distinct_event_types_24h: number;
  distinct_orders_24h: number;
  distinct_payments_24h: number;
  last_event_at: string | null;
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

export default async function RazorpayWebhookEventsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_razorpay_webhook_events_summary");
  if (error) throw new Error(`founder_razorpay_webhook_events_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  const lastMins = r?.last_event_at
    ? Math.max(0, Math.floor((Date.now() - new Date(r.last_event_at).getTime()) / 60000))
    : Number.POSITIVE_INFINITY;
  const streamSilence = lastMins > 360;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Razorpay webhook events summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI inbound gateway audit log · safety-net for verify-* 5xx · pair with /payment-verify-events-summary + /razorpay-payments-pulse-summary</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Events 1h" val={formatNumber(r.events_1h)} sub="razorpay webhook hits" />
          <Card title="Events 24h" val={formatNumber(r.events_24h)} sub="all outcomes" />
          <Card title="Events 7d" val={formatNumber(r.events_7d)} sub="rolling window" />
          <Card title="Applied 24h" val={formatNumber(r.applied_24h)} ok={r.applied_24h > 0} sub="row flipped successfully" />
          <Card title="No-match 24h" val={formatNumber(r.no_match_24h)} danger={r.no_match_24h > 0} sub="orphans — verify race / env mismatch" />
          <Card title="Exception 24h" val={formatNumber(r.exception_24h)} danger={r.exception_24h > 0} sub="handler threw — manual triage" />
          <Card title="Escrow flips 7d" val={formatNumber(r.escrow_flips_7d)} sub="repair_job_escrow → held" />
          <Card title="Spare flips 7d" val={formatNumber(r.spare_flips_7d)} sub="spare_part_orders → completed" />
          <Card title="AMC flips 7d" val={formatNumber(r.amc_flips_7d)} sub="amc_payment_orders → paid" />
          <Card title="Refunds processed 7d" val={formatNumber(r.refunds_processed_7d)} sub="money left Razorpay" />
          <Card title="Distinct event types 24h" val={formatNumber(r.distinct_event_types_24h)} sub="captured / authorized / refund.*" />
          <Card title="Distinct orders 24h" val={formatNumber(r.distinct_orders_24h)} sub="unique razorpay_order_id" />
          <Card title="Distinct payments 24h" val={formatNumber(r.distinct_payments_24h)} sub="unique razorpay_payment_id" />
          <Card title="Last event" val={relTime(r.last_event_at)} danger={streamSilence} sub="webhook-stream liveness" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
