import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    stockRes,
    historyRes,
    urgentRes,
    supplierRes,
    topHospRes,
    autoRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('list_stock_levels_r2444'),
    supabase.rpc('list_reorder_history_r2444'),
    supabase.rpc('urgent_reorders_r2444'),
    supabase.rpc('supplier_fulfillment_summary_r2444'),
    supabase.rpc('top_consuming_hospitals_r2444'),
    supabase.rpc('auto_reorder_summary_r2444'),
    supabase.rpc('weekly_stockout_risk_r2444'),
  ]);

  const stock = (stockRes.data ?? []) as any[];
  const history = (historyRes.data ?? []) as any[];
  const urgent = (urgentRes.data ?? []) as any[];
  const supplier = (supplierRes.data ?? []) as any[];
  const topHosp = (topHospRes.data ?? []) as any[];
  const auto = (autoRes.data ?? []) as any[];
  const risk = (riskRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleString() : '-');
  const fmtRupees = (v: any) =>
    v === null || v === undefined ? '-' : '₹' + Number(v).toLocaleString('en-IN');

  const stockCols: Column<any>[] = [
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku },
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'on_hand_count', header: 'On Hand', render: (r: any) => r.on_hand_count },
    { key: 'consumption_per_week', header: 'Per Week', render: (r: any) => r.consumption_per_week },
    { key: 'stock_days_remaining', header: 'Days Left', render: (r: any) => r.stock_days_remaining },
    { key: 'reorder_threshold_count', header: 'Threshold', render: (r: any) => r.reorder_threshold_count },
    { key: 'auto_reorder_enabled', header: 'Auto', render: (r: any) => (r.auto_reorder_enabled ? 'yes' : 'no') },
    { key: 'reorder_status', header: 'Status', render: (r: any) => r.reorder_status },
    { key: 'supplier_name', header: 'Supplier', render: (r: any) => r.supplier_name ?? '-' },
    { key: 'last_reorder_at', header: 'Last Reorder', render: (r: any) => fmtDate(r.last_reorder_at) },
  ];

  const historyCols: Column<any>[] = [
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku },
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name },
    { key: 'ordered_at', header: 'Ordered', render: (r: any) => fmtDate(r.ordered_at) },
    { key: 'ordered_qty', header: 'Qty', render: (r: any) => r.ordered_qty },
    { key: 'fulfillment_status', header: 'Status', render: (r: any) => r.fulfillment_status },
    { key: 'fulfilled_at', header: 'Fulfilled', render: (r: any) => fmtDate(r.fulfilled_at) },
    { key: 'days_to_fulfill', header: 'Days', render: (r: any) => r.days_to_fulfill ?? '-' },
    { key: 'cost_rupees', header: 'Cost', render: (r: any) => fmtRupees(r.cost_rupees) },
    { key: 'supplier_name', header: 'Supplier', render: (r: any) => r.supplier_name ?? '-' },
  ];

  const urgentCols: Column<any>[] = [
    { key: 'urgency', header: 'Urgency', render: (r: any) => r.urgency },
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku },
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'on_hand_count', header: 'On Hand', render: (r: any) => r.on_hand_count },
    { key: 'stock_days_remaining', header: 'Days Left', render: (r: any) => r.stock_days_remaining },
    { key: 'auto_reorder_enabled', header: 'Auto', render: (r: any) => (r.auto_reorder_enabled ? 'yes' : 'no') },
    { key: 'reorder_status', header: 'Status', render: (r: any) => r.reorder_status },
    { key: 'supplier_name', header: 'Supplier', render: (r: any) => r.supplier_name ?? '-' },
  ];

  const supplierCols: Column<any>[] = [
    { key: 'supplier_name', header: 'Supplier', render: (r: any) => r.supplier_name ?? '-' },
    { key: 'total_orders', header: 'Total Orders', render: (r: any) => r.total_orders },
    { key: 'delivered_count', header: 'Delivered', render: (r: any) => r.delivered_count },
    { key: 'in_transit_count', header: 'In Transit', render: (r: any) => r.in_transit_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
    { key: 'cancelled_count', header: 'Cancelled', render: (r: any) => r.cancelled_count },
    { key: 'avg_days_to_fulfill', header: 'Avg Days', render: (r: any) => r.avg_days_to_fulfill ?? '-' },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => fmtRupees(r.total_cost_rupees) },
  ];

  const topHospCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'total_skus', header: 'SKUs', render: (r: any) => r.total_skus },
    { key: 'total_weekly_consumption', header: 'Weekly Use', render: (r: any) => r.total_weekly_consumption },
    { key: 'urgent_skus', header: 'Urgent SKUs (<=7d)', render: (r: any) => r.urgent_skus },
    { key: 'auto_enabled_skus', header: 'Auto Enabled', render: (r: any) => r.auto_enabled_skus },
  ];

  const autoCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'sku_count', header: 'SKU Count', render: (r: any) => r.sku_count },
    { key: 'total_on_hand', header: 'On Hand', render: (r: any) => r.total_on_hand },
    { key: 'total_weekly_consumption', header: 'Weekly Use', render: (r: any) => r.total_weekly_consumption },
  ];

  const riskCols: Column<any>[] = [
    { key: 'risk_bucket', header: 'Risk Bucket', render: (r: any) => r.risk_bucket },
    { key: 'sku_count', header: 'SKU Count', render: (r: any) => r.sku_count },
    { key: 'total_weekly_consumption', header: 'Weekly Use', render: (r: any) => r.total_weekly_consumption },
    { key: 'auto_enabled_count', header: 'Auto Enabled', render: (r: any) => r.auto_enabled_count },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Customer Spare-Parts Just-In-Time Watch
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Hospital × spare part × consumption rate × stock days remaining × auto-reorder × supplier fulfillment.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Urgent Reorders (<=7 days)</h2>
        <DataTable
          rows={urgent}
          columns={urgentCols}
          emptyMessage="No urgent reorders"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Weekly Stockout Risk Buckets</h2>
        <DataTable
          rows={risk}
          columns={riskCols}
          emptyMessage="No risk data"
          rowKey={(r: any, i: number) => String(r.risk_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Auto-Reorder Summary</h2>
        <DataTable
          rows={auto}
          columns={autoCols}
          emptyMessage="No auto-reorder data"
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Consuming Hospitals</h2>
        <DataTable
          rows={topHosp}
          columns={topHospCols}
          emptyMessage="No hospital consumption data"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Supplier Fulfillment Summary</h2>
        <DataTable
          rows={supplier}
          columns={supplierCols}
          emptyMessage="No supplier data"
          rowKey={(r: any, i: number) => String(r.supplier_org_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Stock Levels</h2>
        <DataTable
          rows={stock}
          columns={stockCols}
          emptyMessage="No stock data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Reorder History</h2>
        <DataTable
          rows={history}
          columns={historyCols}
          emptyMessage="No reorder history"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
