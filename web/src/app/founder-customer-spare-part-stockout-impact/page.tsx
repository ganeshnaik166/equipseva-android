import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    stockouts,
    scorecard,
    topSuppliers,
    topHospitals,
    refundBal,
    trend,
    escBreak,
  ] = await Promise.all([
    sb.rpc('list_stockouts_r2416'),
    sb.rpc('supplier_scorecard_r2416'),
    sb.rpc('top_offending_suppliers_r2416'),
    sb.rpc('top_impacted_hospitals_r2416'),
    sb.rpc('refund_balance_r2416'),
    sb.rpc('monthly_downtime_trend_r2416'),
    sb.rpc('escalation_breakdown_r2416'),
  ]);

  const stockoutRows = (stockouts.data ?? []) as any[];
  const scoreRows = (scorecard.data ?? []) as any[];
  const topSupplierRows = (topSuppliers.data ?? []) as any[];
  const topHospitalRows = (topHospitals.data ?? []) as any[];
  const refundRows = (refundBal.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const escRows = (escBreak.data ?? []) as any[];

  const stockoutCols: Column<any>[] = [
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name },
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'stockout_started_at', header: 'Started', render: (r: any) => new Date(r.stockout_started_at).toLocaleString() },
    { key: 'stockout_resolved_at', header: 'Resolved', render: (r: any) => r.stockout_resolved_at ? new Date(r.stockout_resolved_at).toLocaleString() : 'open' },
    { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: any) => Number(r.downtime_minutes) },
    { key: 'slo_breached', header: 'SLO breach', render: (r: any) => r.slo_breached ? 'yes' : 'no' },
    { key: 'customer_escalation_kind', header: 'Escalation', render: (r: any) => r.customer_escalation_kind },
    { key: 'refund_required_rupees', header: 'Refund req', render: (r: any) => `Rs ${Number(r.refund_required_rupees).toLocaleString()}` },
    { key: 'refund_paid_rupees', header: 'Refund paid', render: (r: any) => `Rs ${Number(r.refund_paid_rupees).toLocaleString()}` },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const scoreCols: Column<any>[] = [
    { key: 'supplier_name', header: 'Supplier', render: (r: any) => r.supplier_name },
    { key: 'stockouts_30d', header: 'Stockouts 30d', render: (r: any) => Number(r.stockouts_30d) },
    { key: 'total_downtime_minutes_30d', header: 'Downtime 30d (min)', render: (r: any) => Number(r.total_downtime_minutes_30d) },
    { key: 'slo_breaches_30d', header: 'SLO breaches 30d', render: (r: any) => Number(r.slo_breaches_30d) },
    { key: 'avg_resolution_hours', header: 'Avg resolution (h)', render: (r: any) => Number(r.avg_resolution_hours).toFixed(2) },
    { key: 'refund_owed_rupees', header: 'Refund owed', render: (r: any) => `Rs ${Number(r.refund_owed_rupees).toLocaleString()}` },
    { key: 'refund_paid_rupees', header: 'Refund paid', render: (r: any) => `Rs ${Number(r.refund_paid_rupees).toLocaleString()}` },
    { key: 'last_stockout_at', header: 'Last stockout', render: (r: any) => r.last_stockout_at ? new Date(r.last_stockout_at).toLocaleString() : '-' },
    { key: 'action_taken', header: 'Action', render: (r: any) => r.action_taken ?? '-' },
  ];

  const topSupplierCols: Column<any>[] = [
    { key: 'supplier_name', header: 'Supplier', render: (r: any) => r.supplier_name },
    { key: 'stockout_count', header: 'Stockouts', render: (r: any) => Number(r.stockout_count) },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => Number(r.total_downtime_minutes) },
    { key: 'slo_breach_count', header: 'SLO breaches', render: (r: any) => Number(r.slo_breach_count) },
    { key: 'refund_required_rupees', header: 'Refund req', render: (r: any) => `Rs ${Number(r.refund_required_rupees).toLocaleString()}` },
  ];

  const topHospitalCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital user id', render: (r: any) => String(r.hospital_user_id) },
    { key: 'stockout_count', header: 'Stockouts', render: (r: any) => Number(r.stockout_count) },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => Number(r.total_downtime_minutes) },
    { key: 'slo_breach_count', header: 'SLO breaches', render: (r: any) => Number(r.slo_breach_count) },
    { key: 'exec_escalations', header: 'Exec escalations', render: (r: any) => Number(r.exec_escalations) },
  ];

  const refundCols: Column<any>[] = [
    { key: 'total_refund_required_rupees', header: 'Refund required', render: (r: any) => `Rs ${Number(r.total_refund_required_rupees).toLocaleString()}` },
    { key: 'total_refund_paid_rupees', header: 'Refund paid', render: (r: any) => `Rs ${Number(r.total_refund_paid_rupees).toLocaleString()}` },
    { key: 'total_refund_outstanding_rupees', header: 'Outstanding', render: (r: any) => `Rs ${Number(r.total_refund_outstanding_rupees).toLocaleString()}` },
    { key: 'stockouts_with_refund', header: 'Stockouts w/ refund', render: (r: any) => Number(r.stockouts_with_refund) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'stockout_count', header: 'Stockouts', render: (r: any) => Number(r.stockout_count) },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => Number(r.total_downtime_minutes) },
    { key: 'slo_breach_count', header: 'SLO breaches', render: (r: any) => Number(r.slo_breach_count) },
    { key: 'refund_required_rupees', header: 'Refund req', render: (r: any) => `Rs ${Number(r.refund_required_rupees).toLocaleString()}` },
  ];

  const escCols: Column<any>[] = [
    { key: 'customer_escalation_kind', header: 'Escalation kind', render: (r: any) => r.customer_escalation_kind },
    { key: 'stockout_count', header: 'Stockouts', render: (r: any) => Number(r.stockout_count) },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => Number(r.total_downtime_minutes) },
    { key: 'total_refund_required_rupees', header: 'Refund req', render: (r: any) => `Rs ${Number(r.total_refund_required_rupees).toLocaleString()}` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Spare Part Stockout Impact</h1>
        <p className="text-sm text-gray-600 mt-1">
          Stockouts × downtime × SLO breach × customer escalation × supplier accountability.
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-2">Refund balance</h2>
        <DataTable
          rows={refundRows}
          columns={refundCols}
          emptyMessage="No refund data yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">All stockouts</h2>
        <DataTable
          rows={stockoutRows}
          columns={stockoutCols}
          emptyMessage="No stockouts logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Supplier scorecard (30d)</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No scorecard rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Top offending suppliers</h2>
        <DataTable
          rows={topSupplierRows}
          columns={topSupplierCols}
          emptyMessage="No supplier data."
          rowKey={(r: any, i: number) => String(r.supplier_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Top impacted hospitals</h2>
        <DataTable
          rows={topHospitalRows}
          columns={topHospitalCols}
          emptyMessage="No hospital impact yet."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Monthly downtime trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No monthly trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Escalation breakdown</h2>
        <DataTable
          rows={escRows}
          columns={escCols}
          emptyMessage="No escalations logged."
          rowKey={(r: any, i: number) => String(r.customer_escalation_kind ?? i)}
        />
      </section>
    </main>
  );
}
