import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare parts demand forecast — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_orders_lifetime: number;
  orders_last_30d: number; orders_last_90d: number; orders_last_365d: number;
  avg_orders_per_month: number;
  avg_order_amount_rupees: number;
  top_supplier_org_id: string | null;
  top_supplier_orders_count: number;
  estimated_orders_next_30d: number;
  estimated_amount_next_30d_rupees: number;
  pending_orders_count: number;
  paid_orders_amount_90d_rupees: number;
  generated_at: string;
};
type Trend = { month_start: string; order_count: number; total_amount_rupees: number; distinct_suppliers: number; };

function Card({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)] tabular-nums">{sub}</div> : null}
    </div>
  );
}
function rup(n: number): string { return `₹${formatNumber(Math.round(n))}`; }

export default async function FounderSparePartsDemandForecastPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, tRes] = await Promise.all([
    sb.rpc("founder_spare_parts_demand_forecast_summary"),
    sb.rpc("founder_spare_parts_demand_forecast_monthly_trend", { p_months: 12 }),
  ]);
  if (sRes.error) throw new Error(`spare_parts_demand_forecast_summary: ${sRes.error.message}`);
  if (tRes.error) throw new Error(`spare_parts_demand_forecast_monthly_trend: ${tRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const trend = (tRes.data ?? []) as Trend[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Spare parts demand forecast ★</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Demand patterns from historic spare_part_orders · 12-month trend · estimated next-30d order count + amount (linear projection from 90d avg). Use to pre-stock + prioritize supplier onboarding.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Total lifetime" value={formatNumber(s.total_orders_lifetime)} />
          <Card label="Last 30d" value={formatNumber(s.orders_last_30d)} />
          <Card label="Last 90d" value={formatNumber(s.orders_last_90d)} />
          <Card label="Last 365d" value={formatNumber(s.orders_last_365d)} />
          <Card label="Avg / month" value={s.avg_orders_per_month.toFixed(1)} />
          <Card label="Avg order ₹" value={rup(s.avg_order_amount_rupees)} />
          <Card label="Est next 30d orders" value={s.estimated_orders_next_30d.toFixed(0)} />
          <Card label="Est next 30d ₹" value={rup(s.estimated_amount_next_30d_rupees)} />
          <Card label="Pending orders" value={formatNumber(s.pending_orders_count)} />
          <Card label="Paid 90d ₹" value={rup(s.paid_orders_amount_90d_rupees)} />
          <Card label="Top supplier orders" value={formatNumber(s.top_supplier_orders_count)} sub="lifetime count" />
          <Card label="Generated" value={new Date(s.generated_at).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })} sub="IST" />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">12-month trend ({trend.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Month</th>
                <th className="py-2 pr-3 text-right">Orders</th>
                <th className="py-2 pr-3 text-right">Amount</th>
                <th className="py-2 text-right">Suppliers</th>
              </tr>
            </thead>
            <tbody>
              {trend.map((t) => (
                <tr key={t.month_start} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono">{t.month_start}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(t.order_count)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(t.total_amount_rupees)}</td>
                  <td className="py-2 text-xs text-right tabular-nums">{formatNumber(t.distinct_suppliers)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
