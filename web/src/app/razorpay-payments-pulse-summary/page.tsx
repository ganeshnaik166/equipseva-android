import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Razorpay payments pulse summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  captured_1h: number;
  captured_24h: number;
  authorized_24h: number;
  refunds_created_7d: number;
  refunds_processed_7d: number;
  refunds_inflight: number;
  amc_orders_pending: number;
  escrows_pending: number;
  spare_orders_pending: number;
  stale_pending_24h: number;
  inflow_inr_24h: number;
  orphan_rows_7d: number;
  exception_rows_7d: number;
  last_captured_at: string | null;
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

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;

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

export default async function RazorpayPaymentsPulseSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_razorpay_payments_pulse_summary");
  if (error) throw new Error(`founder_razorpay_payments_pulse_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  const lastCapturedMins = r?.last_captured_at
    ? Math.max(0, Math.floor((Date.now() - new Date(r.last_captured_at).getTime()) / 60000))
    : Number.POSITIVE_INFINITY;
  const captureSilence = lastCapturedMins > 120; // >2h silence = warn
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Razorpay payments pulse summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI gateway-side pulse · capture volume + refund inflight + stuck pending · pair with /webhooks-snapshot + /amc-payment-orders-status</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Captured 1h" val={formatNumber(r.captured_1h)} sub="payment.captured events" />
          <Card title="Captured 24h" val={formatNumber(r.captured_24h)} sub="payment.captured events" />
          <Card title="Authorized 24h" val={formatNumber(r.authorized_24h)} sub="capture-lag risk if >0" danger={r.authorized_24h > 0} />
          <Card title="Inflow 24h" val={inr(r.inflow_inr_24h)} ok={r.inflow_inr_24h > 0} sub="sum amount_paise / 100" />
          <Card title="Refunds created 7d" val={formatNumber(r.refunds_created_7d)} sub="refund initiated" />
          <Card title="Refunds processed 7d" val={formatNumber(r.refunds_processed_7d)} sub="money left Razorpay" />
          <Card title="Refunds inflight" val={formatNumber(r.refunds_inflight)} danger={r.refunds_inflight > 0} sub="created − processed (7d)" />
          <Card title="AMC orders pending" val={formatNumber(r.amc_orders_pending)} sub="amc_payment_orders" />
          <Card title="Escrows pending" val={formatNumber(r.escrows_pending)} sub="repair_job_escrow" />
          <Card title="Spare orders pending" val={formatNumber(r.spare_orders_pending)} sub="with razorpay_order_id" />
          <Card title="Stale pending >24h" val={formatNumber(r.stale_pending_24h)} danger={r.stale_pending_24h > 0} sub="across all 3 intake tables" />
          <Card title="Orphan rows 7d" val={formatNumber(r.orphan_rows_7d)} danger={r.orphan_rows_7d > 0} sub="webhook→DB reconcile gap" />
          <Card title="Exception rows 7d" val={formatNumber(r.exception_rows_7d)} danger={r.exception_rows_7d > 0} sub="handler threw" />
          <Card title="Last captured" val={relTime(r.last_captured_at)} danger={captureSilence} sub="capture-recency probe" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
