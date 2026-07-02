import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorQuarterlyKpiDashboardPage() {
  const sb = await getSupabaseServerClient();

  const [kpisRes, milestonesRes, latestRes, trendRes, summaryRes] = await Promise.all([
    sb.rpc('list_investor_kpis_r1789'),
    sb.rpc('list_investor_kpi_milestones_r1789'),
    sb.rpc('latest_investor_kpi_summary_r1789'),
    sb.rpc('investor_kpi_trend_comparison_r1789'),
    sb.rpc('investor_kpi_milestone_summary_r1789'),
  ]);

  const kpis: any[] = Array.isArray(kpisRes.data) ? kpisRes.data : [];
  const milestones: any[] = Array.isArray(milestonesRes.data) ? milestonesRes.data : [];
  const latest: any[] = Array.isArray(latestRes.data) ? latestRes.data : [];
  const trends: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const milestoneSummary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];

  const kpiCols: Column<any>[] = [
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: any) => String(r.fiscal_quarter ?? '') },
    { key: 'revenue_rupees', header: 'Revenue (₹)', render: (r: any) => Number(r.revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'customer_count', header: 'Customers', render: (r: any) => String(r.customer_count ?? 0) },
    { key: 'churn_rate_pct', header: 'Churn %', render: (r: any) => `${Number(r.churn_rate_pct ?? 0).toFixed(2)}%` },
    { key: 'nps_score', header: 'NPS', render: (r: any) => String(r.nps_score ?? 0) },
    { key: 'headcount', header: 'Headcount', render: (r: any) => String(r.headcount ?? 0) },
    { key: 'runway_months', header: 'Runway (mo)', render: (r: any) => String(r.runway_months ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'snapshot_taken_at', header: 'Snapshot', render: (r: any) => r.snapshot_taken_at ? new Date(r.snapshot_taken_at).toLocaleString() : '' },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: any) => String(r.fiscal_quarter ?? '') },
    { key: 'milestone', header: 'Milestone', render: (r: any) => String(r.milestone ?? '').replace(/_/g, ' ') },
    { key: 'achieved', header: 'Achieved', render: (r: any) => r.achieved ? 'Yes' : 'No' },
    { key: 'achieved_at', header: 'Achieved At', render: (r: any) => r.achieved_at ? new Date(r.achieved_at).toLocaleString() : '' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: any) => String(r.fiscal_quarter ?? '') },
    { key: 'revenue_rupees', header: 'Revenue (₹)', render: (r: any) => Number(r.revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'prev_revenue_rupees', header: 'Prev Revenue (₹)', render: (r: any) => Number(r.prev_revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'revenue_delta_rupees', header: 'Revenue Δ', render: (r: any) => Number(r.revenue_delta_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'customer_count', header: 'Customers', render: (r: any) => String(r.customer_count ?? 0) },
    { key: 'customer_delta', header: 'Customer Δ', render: (r: any) => String(r.customer_delta ?? 0) },
    { key: 'churn_rate_pct', header: 'Churn %', render: (r: any) => `${Number(r.churn_rate_pct ?? 0).toFixed(2)}%` },
    { key: 'nps_score', header: 'NPS', render: (r: any) => String(r.nps_score ?? 0) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'milestone', header: 'Milestone', render: (r: any) => String(r.milestone ?? '').replace(/_/g, ' ') },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'achieved_count', header: 'Achieved', render: (r: any) => String(r.achieved_count ?? 0) },
    { key: 'first_achieved_at', header: 'First Achieved', render: (r: any) => r.first_achieved_at ? new Date(r.first_achieved_at).toLocaleString() : '' },
  ];

  const latestRow = latest[0] || null;

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Quarterly KPI Dashboard</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Quarterly investor-facing KPIs: revenue, churn, NPS, headcount & runway. Track milestone achievements across quarters.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Latest Quarter Summary</h2>
        {latestRow ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Quarter</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{String(latestRow.fiscal_quarter ?? '')}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Revenue</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>₹{Number(latestRow.revenue_rupees ?? 0).toLocaleString('en-IN')}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Customers</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{String(latestRow.customer_count ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Churn</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{Number(latestRow.churn_rate_pct ?? 0).toFixed(2)}%</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>NPS</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{String(latestRow.nps_score ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Headcount</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{String(latestRow.headcount ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Runway</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{String(latestRow.runway_months ?? 0)} mo</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Status</div>
              <div style={{ fontSize: 18, fontWeight: 600 }}>{String(latestRow.status ?? '')}</div>
            </div>
          </div>
        ) : (
          <p style={{ color: '#777' }}>No KPI snapshots yet.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly KPI Snapshots</h2>
        <DataTable rows={kpis} columns={kpiCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Trend Comparison (Quarter-over-Quarter)</h2>
        <DataTable rows={trends} columns={trendCols} rowKey={(r: any, i: number) => String(r.fiscal_quarter ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Milestone Alerts</h2>
        <DataTable rows={milestones} columns={milestoneCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Milestone Summary</h2>
        <DataTable rows={milestoneSummary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.milestone ?? i)} />
      </section>
    </main>
  );
}
