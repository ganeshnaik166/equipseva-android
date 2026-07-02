import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerSparePartCourierCostTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    dispatchesRes,
    actionsRes,
    topCostRes,
    courierSummaryRes,
    outlierDistRes,
    monthlyTrendRes,
    supplierBreakdownRes,
  ] = await Promise.all([
    supabase.rpc('list_dispatches_r2570'),
    supabase.rpc('list_outlier_actions_r2570'),
    supabase.rpc('top_cost_couriers_r2570'),
    supabase.rpc('courier_kind_summary_r2570'),
    supabase.rpc('outlier_flag_distribution_r2570'),
    supabase.rpc('monthly_cost_trend_r2570'),
    supabase.rpc('supplier_courier_breakdown_r2570'),
  ]);

  const dispatches = (dispatchesRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topCost = (topCostRes.data ?? []) as any[];
  const courierSummary = (courierSummaryRes.data ?? []) as any[];
  const outlierDist = (outlierDistRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const supplierBreakdown = (supplierBreakdownRes.data ?? []) as any[];

  const dispatchCols: Column<any>[] = [
    { key: 'dispatched_at', header: 'Dispatched', render: (r: any) => new Date(r.dispatched_at).toLocaleString() },
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku },
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name },
    { key: 'courier_kind', header: 'Courier', render: (r: any) => r.courier_kind },
    { key: 'cost_rupees', header: 'Cost (Rs)', render: (r: any) => r.cost_rupees },
    { key: 'distance_km', header: 'Distance (km)', render: (r: any) => r.distance_km },
    { key: 'time_to_delivery_hours', header: 'TTD (h)', render: (r: any) => r.time_to_delivery_hours },
    { key: 'outlier_flag', header: 'Outlier', render: (r: any) => r.outlier_flag },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku },
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topCostCols: Column<any>[] = [
    { key: 'courier_kind', header: 'Courier', render: (r: any) => r.courier_kind },
    { key: 'dispatches', header: 'Dispatches', render: (r: any) => r.dispatches },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)', render: (r: any) => r.total_cost_rupees },
    { key: 'avg_cost_rupees', header: 'Avg Cost (Rs)', render: (r: any) => r.avg_cost_rupees },
    { key: 'avg_distance_km', header: 'Avg Distance (km)', render: (r: any) => r.avg_distance_km },
    { key: 'avg_ttd_hours', header: 'Avg TTD (h)', render: (r: any) => r.avg_ttd_hours },
  ];

  const courierSummaryCols: Column<any>[] = [
    { key: 'courier_kind', header: 'Courier', render: (r: any) => r.courier_kind },
    { key: 'dispatches', header: 'Dispatches', render: (r: any) => r.dispatches },
    { key: 'delivered_cnt', header: 'Delivered', render: (r: any) => r.delivered_cnt },
    { key: 'missed_cnt', header: 'Missed', render: (r: any) => r.missed_cnt },
    { key: 'disputed_cnt', header: 'Disputed', render: (r: any) => r.disputed_cnt },
    { key: 'returned_cnt', header: 'Returned', render: (r: any) => r.returned_cnt },
    { key: 'avg_ttd_hours', header: 'Avg TTD (h)', render: (r: any) => r.avg_ttd_hours },
  ];

  const outlierDistCols: Column<any>[] = [
    { key: 'outlier_flag', header: 'Flag', render: (r: any) => r.outlier_flag },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)', render: (r: any) => r.total_cost_rupees },
    { key: 'avg_ttd_hours', header: 'Avg TTD (h)', render: (r: any) => r.avg_ttd_hours },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'dispatches', header: 'Dispatches', render: (r: any) => r.dispatches },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)', render: (r: any) => r.total_cost_rupees },
    { key: 'avg_cost_rupees', header: 'Avg Cost (Rs)', render: (r: any) => r.avg_cost_rupees },
    { key: 'avg_ttd_hours', header: 'Avg TTD (h)', render: (r: any) => r.avg_ttd_hours },
    { key: 'outlier_cnt', header: 'Outliers', render: (r: any) => r.outlier_cnt },
  ];

  const supplierBreakdownCols: Column<any>[] = [
    { key: 'supplier_org_id', header: 'Supplier Org', render: (r: any) => r.supplier_org_id ?? '-' },
    { key: 'courier_kind', header: 'Courier', render: (r: any) => r.courier_kind },
    { key: 'dispatches', header: 'Dispatches', render: (r: any) => r.dispatches },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)', render: (r: any) => r.total_cost_rupees },
    { key: 'avg_ttd_hours', header: 'Avg TTD (h)', render: (r: any) => r.avg_ttd_hours },
    { key: 'outlier_cnt', header: 'Outliers', render: (r: any) => r.outlier_cnt },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Spare-Part Courier Cost Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Per-dispatch courier kind & cost vs distance vs time-to-delivery. Outlier flags (expensive / slow / missing /
        damaged) drive supplier reviews, lane switches, cost audits, refund chases & escalations.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Dispatches</h2>
        <DataTable
          rows={dispatches}
          columns={dispatchCols}
          emptyMessage="No dispatches logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Outlier Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No outlier actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Cost Couriers</h2>
        <DataTable
          rows={topCost}
          columns={topCostCols}
          emptyMessage="No cost data yet"
          rowKey={(r: any, i: number) => String(r.courier_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Courier Kind Summary</h2>
        <DataTable
          rows={courierSummary}
          columns={courierSummaryCols}
          emptyMessage="No courier data yet"
          rowKey={(r: any, i: number) => String(r.courier_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Outlier Flag Distribution</h2>
        <DataTable
          rows={outlierDist}
          columns={outlierDistCols}
          emptyMessage="No outliers yet"
          rowKey={(r: any, i: number) => String(r.outlier_flag ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Cost Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No trend data yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Supplier x Courier Breakdown</h2>
        <DataTable
          rows={supplierBreakdown}
          columns={supplierBreakdownCols}
          emptyMessage="No supplier breakdown yet"
          rowKey={(r: any, i: number) => String((r.supplier_org_id ?? 'na') + '|' + (r.courier_kind ?? '') + '|' + i)}
        />
      </section>
    </div>
  );
}
