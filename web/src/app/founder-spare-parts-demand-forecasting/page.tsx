import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function SparePartsDemandForecastingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, byPartRes, reorderRes, weeklyRes, stockoutRes, overstockRes, actionsRes] = await Promise.all([
    supabase.rpc('founder_sp_demand_kpis'),
    supabase.rpc('founder_sp_demand_by_part', { p_limit: 50 }),
    supabase.rpc('founder_sp_reorder_recommendations', { p_limit: 30 }),
    supabase.rpc('founder_sp_weekly_trend', { p_limit: 13 }),
    supabase.rpc('founder_sp_stockout_risk', { p_limit: 25 }),
    supabase.rpc('founder_sp_overstocked', { p_limit: 25 }),
    supabase.rpc('founder_sp_recent_actions', { p_limit: 30 }),
  ]);

  await supabase.rpc('log_founder_sp_demand_view', { p_scope: 'spare_parts_demand_forecasting' });

  const k = (kpisRes.data?.[0] ?? {}) as Record<string, number | string | null>;
  const byPart = (byPartRes.data ?? []) as Array<{ id: string; part_name: string; units_90d: number; orders_90d: number; cost_90d_rupees: number; daily_burn: number; forecast_30d_units: number; on_hand_units: number; days_of_cover: number | null; risk_band: string }>;
  const reorder = (reorderRes.data ?? []) as Array<{ id: string; part_name: string; days_of_cover: number | null; on_hand_units: number; forecast_30d_units: number; suggested_reorder_qty: number; estimated_reorder_cost_rupees: number; urgency: string }>;
  const weekly = (weeklyRes.data ?? []) as Array<{ id: string; week_start: string; units_consumed: number; orders_count: number; cost_rupees: number; distinct_parts: number }>;
  const stockout = (stockoutRes.data ?? []) as Array<{ id: string; part_name: string; on_hand_units: number; daily_burn: number; days_to_stockout: number | null; last_order_at: string }>;
  const overstock = (overstockRes.data ?? []) as Array<{ id: string; part_name: string; on_hand_units: number; on_hand_value_rupees: number; days_of_cover: number; excess_units: number }>;
  const actions = (actionsRes.data ?? []) as Array<{ id: string; acted_at: string; part_name: string; action: string; qty_adjusted: number | null; note: string | null }>;

  const num = (v: unknown) => (typeof v === 'number' ? v : Number(v ?? 0));
  const rupees = (v: unknown) => formatRupees(num(v));
  const cards: Array<{ label: string; value: string }> = [
    { label: 'Parts tracked', value: String(num(k.total_parts_tracked)) },
    { label: 'Parts w/ 90d demand', value: String(num(k.parts_with_demand_90d)) },
    { label: 'Units consumed 90d', value: num(k.total_units_consumed_90d).toLocaleString('en-IN') },
    { label: 'Cost consumed 90d', value: rupees(k.total_cost_consumed_90d_rupees) },
    { label: 'Avg daily burn', value: num(k.avg_daily_burn_units).toFixed(2) },
    { label: 'Forecast 30d units', value: num(k.forecast_30d_units).toLocaleString('en-IN') },
    { label: 'Forecast 30d cost', value: rupees(k.forecast_30d_cost_rupees) },
    { label: 'Bonded on-hand units', value: num(k.bonded_on_hand_units).toLocaleString('en-IN') },
    { label: 'Bonded on-hand value', value: rupees(k.bonded_on_hand_value_rupees) },
    { label: 'Parts needing reorder', value: String(num(k.parts_needing_reorder)) },
    { label: 'Stockout risk 7d', value: String(num(k.parts_stockout_risk_7d)) },
    { label: 'Stockout risk 30d', value: String(num(k.parts_stockout_risk_30d)) },
    { label: 'Overstocked parts', value: String(num(k.parts_overstocked)) },
    { label: 'Avg days of cover', value: num(k.avg_days_of_cover).toFixed(1) },
    { label: 'Top part units 90d', value: num(k.top_part_units).toLocaleString('en-IN') },
    { label: 'Reorder actions 30d', value: String(num(k.reorder_actions_30d)) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Spare Parts Demand Forecasting</h1>
        <p className="text-sm text-gray-600 mt-1">90-day rolling demand by part. 30-day depletion forecast vs bonded inventory. Re-order recommendations with urgency bands. Days-of-cover {"<"} 7 = critical, {"<"} 30 = low, {">"} 180 = overstock.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border bg-white p-3">
            <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
            <div className="text-xl font-semibold mt-1">{c.value}</div>
          </div>
        ))}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Re-order recommendations</h2>
        <p className="text-xs text-gray-600">Parts with days-of-cover {"<"} 30. Suggested qty = ceil(60-day demand) minus on-hand.</p>
        <DataTable
          rows={reorder}
          rowKey={(r) => r.id}
          columns={[
            { key: 'c17', header: 'Part', render: (r) => r.part_name },
            { key: 'c18', header: 'Urgency', render: (r) => r.urgency },
            { key: 'c19', header: 'Days of cover', render: (r) => (r.days_of_cover == null ? '—' : r.days_of_cover.toFixed(1)) },
            { key: 'c20', header: 'On hand', render: (r) => r.on_hand_units.toLocaleString('en-IN') },
            { key: 'c21', header: 'Forecast 30d', render: (r) => r.forecast_30d_units.toLocaleString('en-IN') },
            { key: 'c22', header: 'Suggested qty', render: (r) => r.suggested_reorder_qty.toLocaleString('en-IN') },
            { key: 'c23', header: 'Est. cost', render: (r) => formatRupees(r.estimated_reorder_cost_rupees) },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">90-day demand by part</h2>
        <DataTable
          rows={byPart}
          rowKey={(r) => r.id}
          columns={[
            { key: 'c24', header: 'Part', render: (r) => r.part_name },
            { key: 'c25', header: 'Risk', render: (r) => r.risk_band },
            { key: 'c26', header: 'Units 90d', render: (r) => r.units_90d.toLocaleString('en-IN') },
            { key: 'c27', header: 'Orders 90d', render: (r) => r.orders_90d.toLocaleString('en-IN') },
            { key: 'c28', header: 'Cost 90d', render: (r) => formatRupees(r.cost_90d_rupees) },
            { key: 'c29', header: 'Daily burn', render: (r) => Number(r.daily_burn).toFixed(2) },
            { key: 'c30', header: 'Forecast 30d', render: (r) => r.forecast_30d_units.toLocaleString('en-IN') },
            { key: 'c31', header: 'On hand', render: (r) => r.on_hand_units.toLocaleString('en-IN') },
            { key: 'c32', header: 'Days cover', render: (r) => (r.days_of_cover == null ? '—' : Number(r.days_of_cover).toFixed(1)) },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Stockout risk (DOC {"<"} 7)</h2>
        <DataTable
          rows={stockout}
          rowKey={(r) => r.id}
          columns={[
            { key: 'c33', header: 'Part', render: (r) => r.part_name },
            { key: 'c34', header: 'On hand', render: (r) => r.on_hand_units.toLocaleString('en-IN') },
            { key: 'c35', header: 'Daily burn', render: (r) => Number(r.daily_burn).toFixed(2) },
            { key: 'c36', header: 'Days to stockout', render: (r) => (r.days_to_stockout == null ? '0' : Number(r.days_to_stockout).toFixed(1)) },
            { key: 'c37', header: 'Last order', render: (r) => new Date(r.last_order_at).toLocaleDateString('en-IN') },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Overstocked (DOC {">"} 180)</h2>
        <DataTable
          rows={overstock}
          rowKey={(r) => r.id}
          columns={[
            { key: 'c38', header: 'Part', render: (r) => r.part_name },
            { key: 'c39', header: 'On hand', render: (r) => r.on_hand_units.toLocaleString('en-IN') },
            { key: 'c40', header: 'On-hand value', render: (r) => formatRupees(r.on_hand_value_rupees) },
            { key: 'c41', header: 'Days of cover', render: (r) => Number(r.days_of_cover).toFixed(1) },
            { key: 'c42', header: 'Excess units', render: (r) => r.excess_units.toLocaleString('en-IN') },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Weekly demand trend (13 wk)</h2>
        <DataTable
          rows={weekly}
          rowKey={(r) => r.id}
          columns={[
            { key: 'c43', header: 'Week start', render: (r) => new Date(r.week_start).toLocaleDateString('en-IN') },
            { key: 'c44', header: 'Units', render: (r) => r.units_consumed.toLocaleString('en-IN') },
            { key: 'c45', header: 'Orders', render: (r) => r.orders_count.toLocaleString('en-IN') },
            { key: 'c46', header: 'Cost', render: (r) => formatRupees(r.cost_rupees) },
            { key: 'c47', header: 'Distinct parts', render: (r) => r.distinct_parts.toLocaleString('en-IN') },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent re-order actions</h2>
        <DataTable
          rows={actions}
          rowKey={(r) => r.id}
          columns={[
            { key: 'c48', header: 'When', render: (r) => new Date(r.acted_at).toLocaleString('en-IN') },
            { key: 'c49', header: 'Part', render: (r) => r.part_name },
            { key: 'c50', header: 'Action', render: (r) => r.action },
            { key: 'c51', header: 'Qty', render: (r) => (r.qty_adjusted == null ? '—' : r.qty_adjusted.toLocaleString('en-IN')) },
            { key: 'c52', header: 'Note', render: (r) => r.note ?? '—' },
          ]}
        />
      </section>
    </div>
  );
}
