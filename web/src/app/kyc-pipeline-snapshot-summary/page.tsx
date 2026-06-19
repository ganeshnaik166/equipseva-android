import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "KYC pipeline snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineer_pending: number;
  engineer_rejected: number;
  engineer_pending_0_7d: number;
  engineer_pending_7_30d: number;
  engineer_pending_over_30d: number;
  engineer_oldest_age_days: number;
  buyer_pending: number;
  buyer_rejected: number;
  buyer_pending_0_7d: number;
  buyer_pending_7_30d: number;
  buyer_pending_over_30d: number;
  rekyc_due_30d: number;
  rekyc_overdue: number;
  rekyc_grace_expiring_7d: number;
  engineer_intake_today: number;
  engineer_verified_today: number;
  engineer_verified_30d: number;
  buyer_intake_today: number;
  buyer_verified_today: number;
  buyer_verified_30d: number;
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

export default async function KycPipelineSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_kyc_pipeline_snapshot_summary");
  if (error) throw new Error(`founder_kyc_pipeline_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">KYC pipeline snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">20-KPI engineer + buyer KYC backlog · aging · re-KYC · intake vs approval · gates Cashfree + Class A/B</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Engineer pending" val={formatNumber(r.engineer_pending)} sub="awaiting verify" danger={r.engineer_pending > 0} />
          <Card title="Engineer rejected" val={formatNumber(r.engineer_rejected)} sub="needs resubmit" danger={r.engineer_rejected > 0} />
          <Card title="Engineer pending 0-7d" val={formatNumber(r.engineer_pending_0_7d)} />
          <Card title="Engineer pending 7-30d" val={formatNumber(r.engineer_pending_7_30d)} sub="aging" />
          <Card title="Engineer pending >30d" val={formatNumber(r.engineer_pending_over_30d)} danger={r.engineer_pending_over_30d > 0} />
          <Card title="Oldest engineer wait (d)" val={formatNumber(r.engineer_oldest_age_days)} danger={r.engineer_oldest_age_days > 30} />
          <Card title="Buyer pending" val={formatNumber(r.buyer_pending)} sub="checkout gate" danger={r.buyer_pending > 0} />
          <Card title="Buyer rejected" val={formatNumber(r.buyer_rejected)} sub="needs resubmit" danger={r.buyer_rejected > 0} />
          <Card title="Buyer pending 0-7d" val={formatNumber(r.buyer_pending_0_7d)} />
          <Card title="Buyer pending 7-30d" val={formatNumber(r.buyer_pending_7_30d)} sub="aging" />
          <Card title="Buyer pending >30d" val={formatNumber(r.buyer_pending_over_30d)} danger={r.buyer_pending_over_30d > 0} />
          <Card title="Re-KYC due 30d" val={formatNumber(r.rekyc_due_30d)} sub="365d anniversary" />
          <Card title="Re-KYC overdue" val={formatNumber(r.rekyc_overdue)} danger={r.rekyc_overdue > 0} />
          <Card title="Re-KYC grace <=7d" val={formatNumber(r.rekyc_grace_expiring_7d)} danger={r.rekyc_grace_expiring_7d > 0} />
          <Card title="Engineer intake today" val={formatNumber(r.engineer_intake_today)} />
          <Card title="Engineer verified today" val={formatNumber(r.engineer_verified_today)} ok={r.engineer_verified_today > 0} />
          <Card title="Engineer verified 30d" val={formatNumber(r.engineer_verified_30d)} ok />
          <Card title="Buyer intake today" val={formatNumber(r.buyer_intake_today)} />
          <Card title="Buyer verified today" val={formatNumber(r.buyer_verified_today)} ok={r.buyer_verified_today > 0} />
          <Card title="Buyer verified 30d" val={formatNumber(r.buyer_verified_30d)} ok />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
