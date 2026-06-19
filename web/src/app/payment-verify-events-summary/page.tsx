import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payment verify events summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  events_1h: number;
  events_24h: number;
  events_7d: number;
  success_24h: number;
  idempotent_success_24h: number;
  failures_24h: number;
  invalid_signature_7d: number;
  amount_mismatch_7d: number;
  server_verify_failed_7d: number;
  unauthenticated_7d: number;
  not_owner_7d: number;
  distinct_fns_24h: number;
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

export default async function PaymentVerifyEventsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payment_verify_events_summary");
  if (error) throw new Error(`founder_payment_verify_events_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  const lastMins = r?.last_event_at
    ? Math.max(0, Math.floor((Date.now() - new Date(r.last_event_at).getTime()) / 60000))
    : Number.POSITIVE_INFINITY;
  const streamSilence = lastMins > 360; // >6h silence on a busy payment path = stale telemetry
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payment verify events summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI server-side verify-* ledger · HMAC-checked client redirects · pair with /razorpay-payments-pulse-summary + /webhooks-snapshot</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Events 1h" val={formatNumber(r.events_1h)} sub="verify-* edge fn hits" />
          <Card title="Events 24h" val={formatNumber(r.events_24h)} sub="all outcomes" />
          <Card title="Events 7d" val={formatNumber(r.events_7d)} sub="rolling window" />
          <Card title="Success 24h" val={formatNumber(r.success_24h)} ok={r.success_24h > 0} sub="first-write verify ok" />
          <Card title="Idempotent success 24h" val={formatNumber(r.idempotent_success_24h)} sub="replay of already-verified" />
          <Card title="Failures 24h" val={formatNumber(r.failures_24h)} danger={r.failures_24h > 0} sub="non-success outcomes" />
          <Card title="Invalid signature 7d" val={formatNumber(r.invalid_signature_7d)} danger={r.invalid_signature_7d > 0} sub="HMAC mismatch — tamper signal" />
          <Card title="Amount mismatch 7d" val={formatNumber(r.amount_mismatch_7d)} danger={r.amount_mismatch_7d > 0} sub="client amount != server amount" />
          <Card title="Server verify failed 7d" val={formatNumber(r.server_verify_failed_7d)} danger={r.server_verify_failed_7d > 0} sub="Razorpay GET /payments errored" />
          <Card title="Unauthenticated 7d" val={formatNumber(r.unauthenticated_7d)} sub="missing/expired JWT" />
          <Card title="Not owner 7d" val={formatNumber(r.not_owner_7d)} danger={r.not_owner_7d > 0} sub="cross-user verify attempt" />
          <Card title="Distinct fns 24h" val={formatNumber(r.distinct_fns_24h)} sub="of 3 verify-* edge fns" />
          <Card title="Distinct payments 24h" val={formatNumber(r.distinct_payments_24h)} sub="unique razorpay_payment_id" />
          <Card title="Last event" val={relTime(r.last_event_at)} danger={streamSilence} sub="telemetry-stream liveness" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
