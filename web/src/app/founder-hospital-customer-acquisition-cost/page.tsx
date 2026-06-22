import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalCustomerAcquisitionCostPage() {
  const sb = await getSupabaseServerClient();

  const [metricsRes, latestRes, trendRes, topSegRes] = await Promise.all([
    sb.rpc('list_cac_metrics_r1875', { p_limit: 50 }),
    sb.rpc('latest_cac_r1875'),
    sb.rpc('cac_trend_r1875', { p_limit: 12 }),
    sb.rpc('top_cost_segment_r1875'),
  ]);

  const metrics: any[] = Array.isArray(metricsRes.data) ? metricsRes.data : [];
  const latestRows: any[] = Array.isArray(latestRes.data) ? latestRes.data : [];
  const latest: any = latestRows[0] ?? null;
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const topSegments: any[] = Array.isArray(topSegRes.data) ? topSegRes.data : [];

  const fmtRupees = (v: any) => {
    const n = Number(v ?? 0);
    return '₹ ' + n.toLocaleString('en-IN');
  };
  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');
  const fmtTs = (v: any) => (v ? new Date(v).toLocaleString() : '—');

  const metricsColumns: Column<any>[] = [
    { key: 'period', header: 'Period', render: (r: any) => `${fmtDate(r.snapshot_period_start)} to ${fmtDate(r.snapshot_period_end)}` },
    { key: 'sales', header: 'Sales Spend', render: (r: any) => fmtRupees(r.total_sales_spend_rupees) },
    { key: 'marketing', header: 'Marketing Spend', render: (r: any) => fmtRupees(r.total_marketing_spend_rupees) },
    { key: 'founder_time', header: 'Founder Time', render: (r: any) => fmtRupees(r.total_founder_time_value_rupees) },
    { key: 'new_cust', header: 'New Customers', render: (r: any) => String(r.new_customers_acquired ?? 0) },
    { key: 'cac', header: 'CAC', render: (r: any) => fmtRupees(r.cac_rupees) },
    { key: 'payback', header: 'Payback (mo)', render: (r: any) => String(r.payback_months ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtTs(r.recorded_at) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'period_start', header: 'Period Start', render: (r: any) => fmtDate(r.period_start) },
    { key: 'period_end', header: 'Period End', render: (r: any) => fmtDate(r.period_end) },
    { key: 'cac', header: 'CAC', render: (r: any) => fmtRupees(r.cac_rupees) },
    { key: 'new_cust', header: 'New Customers', render: (r: any) => String(r.new_customers_acquired ?? 0) },
    { key: 'payback', header: 'Payback (mo)', render: (r: any) => String(r.payback_months ?? 0) },
  ];

  const topSegColumns: Column<any>[] = [
    { key: 'segment', header: 'Segment', render: (r: any) => String(r.segment ?? '—') },
    { key: 'customers', header: 'Customers', render: (r: any) => String(r.customers_acquired ?? 0) },
    { key: 'seg_cac', header: 'Segment CAC', render: (r: any) => fmtRupees(r.segment_cac_rupees) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtTs(r.recorded_at) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Hospital Customer Acquisition Cost</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Round 1875 — CAC per hospital tracker (sales & marketing spend divided by new customers acquired).
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Current Snapshot</h2>
        {latest ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
            <div style={{ padding: 12, border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ color: '#666', fontSize: 12 }}>CAC</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtRupees(latest.cac_rupees)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ color: '#666', fontSize: 12 }}>New Customers</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{String(latest.new_customers_acquired ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Total Spend</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtRupees(latest.total_spend_rupees)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Payback (months)</div>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{String(latest.payback_months ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Period</div>
              <div style={{ fontSize: 14, fontWeight: 600 }}>
                {fmtDate(latest.snapshot_period_start)} → {fmtDate(latest.snapshot_period_end)}
              </div>
            </div>
          </div>
        ) : (
          <div style={{ color: '#666' }}>No current snapshot — call take_cac_snapshot_r1875 to record one.</div>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>CAC Snapshots ({metrics.length})</h2>
        <DataTable rows={metrics} columns={metricsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>CAC Trend ({trend.length})</h2>
        <DataTable rows={trend} columns={trendColumns} rowKey={(r: any, i: number) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Cost Segments ({topSegments.length})</h2>
        <DataTable rows={topSegments} columns={topSegColumns} rowKey={(r: any, i: number) => String(r.metric_id ?? i) + '-' + String(i)} />
      </section>
    </main>
  );
}
