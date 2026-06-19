import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts webhook events summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  events_1h: number;
  events_24h: number;
  events_7d: number;
  success_7d: number;
  failed_7d: number;
  reversed_7d: number;
  queued_7d: number;
  other_kinds_7d: number;
  applied_24h: number;
  unapplied_24h: number;
  with_utr_7d: number;
  distinct_payouts_24h: number;
  distinct_payouts_7d: number;
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

export default async function PayoutsWebhookEventsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_webhook_events_summary");
  if (error) throw new Error(`founder_payouts_webhook_events_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  const lastMins = r?.last_event_at
    ? Math.max(0, Math.floor((Date.now() - new Date(r.last_event_at).getTime()) / 60000))
    : Number.POSITIVE_INFINITY;
  // Cashfree activation pending — silence is expected, but >7d silence after activation = stale stream.
  const streamSilence = lastMins > 10080;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts webhook events summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI Cashfree outbound-payout telemetry · terminal-state distribution + apply ratio · pair with /webhooks-snapshot-summary + /engineer-payout-history</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Events 1h" val={formatNumber(r.events_1h)} sub="webhook hits — Cashfree outbound" />
          <Card title="Events 24h" val={formatNumber(r.events_24h)} sub="all event_kinds" />
          <Card title="Events 7d" val={formatNumber(r.events_7d)} sub="rolling window" />
          <Card title="Success 7d" val={formatNumber(r.success_7d)} ok={r.success_7d > 0} sub="payout.success / processed" />
          <Card title="Failed 7d" val={formatNumber(r.failed_7d)} danger={r.failed_7d > 0} sub="payout.failed / rejected" />
          <Card title="Reversed 7d" val={formatNumber(r.reversed_7d)} danger={r.reversed_7d > 0} sub="payout.reversed / returned" />
          <Card title="Queued 7d" val={formatNumber(r.queued_7d)} sub="queued / pending / initiated" />
          <Card title="Other kinds 7d" val={formatNumber(r.other_kinds_7d)} sub="unclassified event_kind" />
          <Card title="Applied 24h" val={formatNumber(r.applied_24h)} ok={r.applied_24h > 0} sub="FSM side-effect fired" />
          <Card title="Unapplied 24h" val={formatNumber(r.unapplied_24h)} danger={r.unapplied_24h > 0} sub="logged but no state change" />
          <Card title="With UTR 7d" val={formatNumber(r.with_utr_7d)} sub="bank settlement reference present" />
          <Card title="Distinct payouts 24h" val={formatNumber(r.distinct_payouts_24h)} sub="unique razorpay_payout_id" />
          <Card title="Distinct payouts 7d" val={formatNumber(r.distinct_payouts_7d)} sub="unique payout coverage" />
          <Card title="Last event" val={relTime(r.last_event_at)} danger={streamSilence} sub="stream liveness (activation pending)" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
