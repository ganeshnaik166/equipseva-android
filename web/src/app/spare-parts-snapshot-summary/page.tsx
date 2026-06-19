import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare parts snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  paid_30d: number;
  paid_gmv_30d: number;
  pending_payment_now: number;
  shipped_30d: number;
  delivered_30d: number;
  cancelled_30d: number;
  refunded_30d: number;
  stuck_over_7d: number;
  stuck_inr_over_7d: number;
  distinct_buyers_30d: number;
  distinct_suppliers_30d: number;
  avg_order_inr_30d: number;
  created_today: number;
  paid_today: number;
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

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function SparePartsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_snapshot_summary");
  if (error) throw new Error(`founder_spare_parts_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">15-KPI commerce dashboard · today/30d/all-time · stuck pipeline · pair with /spare-parts-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total orders all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Paid 30d" val={formatNumber(r.paid_30d)} ok sub={inr(r.paid_gmv_30d)} />
          <Card title="Pending payment now" val={formatNumber(r.pending_payment_now)} />
          <Card title="Shipped 30d" val={formatNumber(r.shipped_30d)} />
          <Card title="Delivered 30d" val={formatNumber(r.delivered_30d)} ok />
          <Card title="Cancelled 30d" val={formatNumber(r.cancelled_30d)} sub="friction signal" />
          <Card title="Refunded 30d" val={formatNumber(r.refunded_30d)} danger={r.refunded_30d > 0} />
          <Card title="Stuck >7d (paid not shipped)" val={formatNumber(r.stuck_over_7d)} danger={r.stuck_over_7d > 0} sub={inr(r.stuck_inr_over_7d)} />
          <Card title="Buyers 30d" val={formatNumber(r.distinct_buyers_30d)} sub="distinct" />
          <Card title="Suppliers 30d" val={formatNumber(r.distinct_suppliers_30d)} sub="distinct orgs" />
          <Card title="Avg order INR 30d" val={inr(r.avg_order_inr_30d)} sub="paid only" />
          <Card title="Created today" val={formatNumber(r.created_today)} />
          <Card title="Paid today" val={formatNumber(r.paid_today)} ok />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
