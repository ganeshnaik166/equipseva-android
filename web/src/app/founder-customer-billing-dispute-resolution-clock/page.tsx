import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [openD, aging, paths, cats, csat, stale, kpi] = await Promise.all([
    sb.rpc('r2260_open_disputes'),
    sb.rpc('r2260_aging_buckets'),
    sb.rpc('r2260_resolution_path_mix'),
    sb.rpc('r2260_category_breakdown'),
    sb.rpc('r2260_csat_post_resolution'),
    sb.rpc('r2260_stale_disputes'),
    sb.rpc('r2260_kpi_summary'),
  ]);

  const openRows = (openD.data ?? []) as any[];
  const agingRows = (aging.data ?? []) as any[];
  const pathRows = (paths.data ?? []) as any[];
  const catRows = (cats.data ?? []) as any[];
  const csatRows = (csat.data ?? []) as any[];
  const staleRows = (stale.data ?? []) as any[];
  const kpiRows = (kpi.data ?? []) as any[];

  const openCols: Column<any>[] = [
    { key: 'invoice_ref', header: 'Invoice', render: (r) => r.invoice_ref },
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'amount_rupees', header: 'Amount (Rs)', render: (r) => `Rs ${r.amount_rupees}` },
    { key: 'days_open', header: 'Days Open', render: (r) => r.days_open },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'assigned', header: 'Assigned', render: (r) => r.assigned },
  ];

  const agingCols: Column<any>[] = [
    { key: 'bucket', header: 'Age Bucket', render: (r) => r.bucket },
    { key: 'dispute_count', header: 'Disputes', render: (r) => r.dispute_count },
    { key: 'total_amount_rupees', header: 'Total (Rs)', render: (r) => `Rs ${r.total_amount_rupees}` },
  ];

  const pathCols: Column<any>[] = [
    { key: 'path', header: 'Resolution Path', render: (r) => r.path },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
    { key: 'total_refund_rupees', header: 'Refund (Rs)', render: (r) => `Rs ${r.total_refund_rupees}` },
    { key: 'avg_days_to_resolve', header: 'Avg Days', render: (r) => r.avg_days_to_resolve ?? 'n/a' },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
    { key: 'total_disputed_rupees', header: 'Disputed (Rs)', render: (r) => `Rs ${r.total_disputed_rupees}` },
  ];

  const csatCols: Column<any>[] = [
    { key: 'metric', header: 'CSAT Metric', render: (r) => r.metric },
    { key: 'value', header: 'Value', render: (r) => r.value },
  ];

  const staleCols: Column<any>[] = [
    { key: 'invoice_ref', header: 'Invoice', render: (r) => r.invoice_ref },
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email },
    { key: 'days_open', header: 'Days Open', render: (r) => r.days_open },
    { key: 'amount_rupees', header: 'Amount (Rs)', render: (r) => `Rs ${r.amount_rupees}` },
    { key: 'assigned', header: 'Assigned', render: (r) => r.assigned },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const kpiCols: Column<any>[] = [
    { key: 'metric', header: 'KPI', render: (r) => r.metric },
    { key: 'value', header: 'Value', render: (r) => r.value },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Billing-Dispute Resolution Clock
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Open billing disputes &amp; days-open clock, resolution paths, and post-resolution CSAT. Stale alert fires when days-open &gt;= 15.
      </p>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 16, marginBottom: 8 }}>KPI Summary</h2>
      <DataTable columns={kpiCols} rows={kpiRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Aging Buckets</h2>
      <DataTable columns={agingCols} rows={agingRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Open Disputes (clock running)</h2>
      <DataTable columns={openCols} rows={openRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Stale Disputes (&gt; 15 days)</h2>
      <DataTable columns={staleCols} rows={staleRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Resolution Path Mix</h2>
      <DataTable columns={pathCols} rows={pathRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Category Breakdown</h2>
      <DataTable columns={catCols} rows={catRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Post-Resolution CSAT</h2>
      <DataTable columns={csatCols} rows={csatRows} rowKey={(_, i) => String(i)} />
    </div>
  );
}
