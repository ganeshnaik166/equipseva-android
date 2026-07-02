import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [testsRes, outcomesRes, topRes, retentionRes, funnelRes, trendRes, ownerRes] = await Promise.all([
    sb.rpc('list_tests_r2627'),
    sb.rpc('list_outcomes_r2627'),
    sb.rpc('top_net_positive_focus_r2627'),
    sb.rpc('retention_summary_r2627'),
    sb.rpc('status_funnel_r2627'),
    sb.rpc('quarterly_test_trend_r2627'),
    sb.rpc('owner_load_r2627'),
  ]);

  const tests: any[] = Array.isArray(testsRes.data) ? testsRes.data : [];
  const outcomes: any[] = Array.isArray(outcomesRes.data) ? outcomesRes.data : [];
  const topFocus: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const retention: any[] = Array.isArray(retentionRes.data) ? retentionRes.data : [];
  const funnel: any[] = Array.isArray(funnelRes.data) ? funnelRes.data : [];
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const owners: any[] = Array.isArray(ownerRes.data) ? ownerRes.data : [];

  const fmtRupees = (n: any) => '₹' + Number(n ?? 0).toLocaleString('en-IN');
  const fmtPct = (n: any) => `${Number(n ?? 0).toFixed(2)}%`;
  const fmtDate = (d: any) => (d ? new Date(d).toLocaleString() : '—');

  const activeCount = tests.filter((t) => t.status === 'active').length;
  const completedCount = tests.filter((t) => t.status === 'completed').length;
  const totalDelta = tests.reduce((s, t) => s + Number(t.delta_rupees ?? 0), 0);
  const avgRetention = tests.length > 0
    ? tests.reduce((s, t) => s + Number(t.retention_pct ?? 0), 0) / tests.length
    : 0;

  const testColumns: Column<any>[] = [
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'test_increase_pct', header: 'Test +%', render: (r: any) => fmtPct(r.test_increase_pct) },
    { key: 'baseline_revenue_rupees', header: 'Baseline', render: (r: any) => fmtRupees(r.baseline_revenue_rupees) },
    { key: 'actual_revenue_rupees', header: 'Actual', render: (r: any) => fmtRupees(r.actual_revenue_rupees) },
    { key: 'delta_rupees', header: 'Delta', render: (r: any) => fmtRupees(r.delta_rupees) },
    { key: 'churn_count', header: 'Churn', render: (r: any) => String(r.churn_count ?? 0) },
    { key: 'retention_pct', header: 'Retention', render: (r: any) => fmtPct(r.retention_pct) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes ?? '').slice(0, 120) },
  ];

  const outcomeColumns: Column<any>[] = [
    { key: 'outcome_at', header: 'Outcome At', render: (r: any) => fmtDate(r.outcome_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'outcome_kind', header: 'Kind', render: (r: any) => r.outcome_kind },
    { key: 'rationale_md', header: 'Rationale', render: (r: any) => (r.rationale_md ?? '').slice(0, 160) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes ?? '').slice(0, 120) },
  ];

  const topColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'net_positive_count', header: 'Net-Positive Outcomes', render: (r: any) => String(r.net_positive_count ?? 0) },
    { key: 'total_delta_rupees', header: 'Total Delta', render: (r: any) => fmtRupees(r.total_delta_rupees) },
    { key: 'avg_retention_pct', header: 'Avg Retention', render: (r: any) => fmtPct(r.avg_retention_pct) },
  ];

  const retentionColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'test_count', header: 'Tests', render: (r: any) => String(r.test_count ?? 0) },
    { key: 'total_churn', header: 'Total Churn', render: (r: any) => String(r.total_churn ?? 0) },
    { key: 'avg_retention_pct', header: 'Avg Retention', render: (r: any) => fmtPct(r.avg_retention_pct) },
    { key: 'avg_test_increase_pct', header: 'Avg Uplift', render: (r: any) => fmtPct(r.avg_test_increase_pct) },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'test_count', header: 'Tests', render: (r: any) => String(r.test_count ?? 0) },
    { key: 'total_baseline_rupees', header: 'Baseline', render: (r: any) => fmtRupees(r.total_baseline_rupees) },
    { key: 'total_actual_rupees', header: 'Actual', render: (r: any) => fmtRupees(r.total_actual_rupees) },
    { key: 'total_delta_rupees', header: 'Delta', render: (r: any) => fmtRupees(r.total_delta_rupees) },
    { key: 'avg_retention_pct', header: 'Avg Retention', render: (r: any) => fmtPct(r.avg_retention_pct) },
  ];

  const ownerColumns: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'test_count', header: 'Tests', render: (r: any) => String(r.test_count ?? 0) },
    { key: 'outcome_count', header: 'Outcomes', render: (r: any) => String(r.outcome_count ?? 0) },
    { key: 'open_outcome_count', header: 'Open Outcomes', render: (r: any) => String(r.open_outcome_count ?? 0) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Quarterly Pricing Power Test</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quarterly campaigns testing pricing-power on multi-site chains > baseline. Track uplift, churn, retention and pick net-positive segments to scale.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active Tests</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{activeCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Completed Tests</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{completedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Delta</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(totalDelta)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Retention</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtPct(avgRetention)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Tests</h2>
        <DataTable
          rows={tests}
          columns={testColumns}
          emptyMessage="No pricing-power tests yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeColumns}
          emptyMessage="No outcomes logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Net-Positive Focus</h2>
        <DataTable
          rows={topFocus}
          columns={topColumns}
          emptyMessage="No focus data yet."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Retention Summary by Status</h2>
        <DataTable
          rows={retention}
          columns={retentionColumns}
          emptyMessage="No retention data yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          emptyMessage="No funnel data yet."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Quarterly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No quarterly data yet."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Owner Load</h2>
        <DataTable
          rows={owners}
          columns={ownerColumns}
          emptyMessage="No owner data yet."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
