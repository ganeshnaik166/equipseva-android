import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Cart abandonment summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  active_carts: number;
  cart_lines_total: number;
  cart_value_inr: number;
  avg_cart_value_inr: number;
  unique_skus_in_carts: number;
  top_sku_qty: number;
  carts_aged_1h_plus: number;
  carts_aged_24h_plus: number;
  carts_aged_7d_plus: number;
  updated_today: number;
  orders_paid_30d: number;
  conversion_pct_30d: number;
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

export default async function CartAbandonmentSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_cart_abandonment_summary");
  if (error) throw new Error(`founder_cart_abandonment_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Cart abandonment summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI funnel-gap snapshot · ₹ in flight + aging buckets + cart→paid conversion</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Active carts" val={formatNumber(r.active_carts)} sub="distinct users with ≥1 item" />
          <Card title="Cart lines total" val={formatNumber(r.cart_lines_total)} sub="rows across all carts" />
          <Card title="Cart value in flight" val={inr(r.cart_value_inr)} sub="sum qty × price" />
          <Card title="Avg cart value" val={inr(r.avg_cart_value_inr)} />
          <Card title="Unique SKUs in carts" val={formatNumber(r.unique_skus_in_carts)} sub="parts catalog demand signal" />
          <Card title="Top SKU qty" val={formatNumber(r.top_sku_qty)} sub="highest summed quantity" />
          <Card title="Carts aged ≥1h" val={formatNumber(r.carts_aged_1h_plus)} sub="last touch >1h ago" />
          <Card title="Carts aged ≥24h" val={formatNumber(r.carts_aged_24h_plus)} danger={r.carts_aged_24h_plus > 0} sub="recovery email window" />
          <Card title="Carts aged ≥7d" val={formatNumber(r.carts_aged_7d_plus)} danger={r.carts_aged_7d_plus > 0} sub="abandoned — purge candidates" />
          <Card title="Cart activity today" val={formatNumber(r.updated_today)} ok={r.updated_today > 0} sub="lines updated (IST day)" />
          <Card title="Paid orders 30d" val={formatNumber(r.orders_paid_30d)} sub="conversion denominator context" />
          <Card title="Cart → paid % 30d" val={`${Number(r.conversion_pct_30d).toFixed(1)}%`} ok={r.conversion_pct_30d >= 20} danger={r.conversion_pct_30d < 5} sub="distinct buyers paid / cart users" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
