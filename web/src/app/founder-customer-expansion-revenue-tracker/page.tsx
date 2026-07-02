import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, byTypeRes, topRes, monthlyRes, recentRes, playbooksRes] = await Promise.all([
    sb.rpc('cust_exp_summary_r2228'),
    sb.rpc('cust_exp_by_type_r2228'),
    sb.rpc('cust_exp_top_accounts_r2228'),
    sb.rpc('cust_exp_monthly_r2228'),
    sb.rpc('cust_exp_recent_events_r2228'),
    sb.rpc('cust_exp_playbooks_r2228'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {}) as any;
  const byType = (byTypeRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];
  const playbooks = (playbooksRes.data ?? []) as any[];

  const byTypeCols: Column<any>[] = [
    { key: 'expansion_type', header: 'Type', render: (r: any) => String(r.expansion_type ?? '') },
    { key: 'events', header: 'Events', render: (r: any) => String(r.events ?? 0) },
    { key: 'mrr_delta', header: 'MRR Delta', render: (r: any) => `Rs ${Number(r.mrr_delta ?? 0).toLocaleString('en-IN')}` },
    { key: 'avg_lift', header: 'Avg Lift', render: (r: any) => `Rs ${Number(r.avg_lift ?? 0).toLocaleString('en-IN')}` },
  ];

  const topCols: Column<any>[] = [
    { key: 'org_name', header: 'Account', render: (r: any) => String(r.org_name ?? '(unknown)') },
    { key: 'events', header: 'Events', render: (r: any) => String(r.events ?? 0) },
    { key: 'total_delta', header: 'MRR Delta', render: (r: any) => `Rs ${Number(r.total_delta ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_one_time', header: 'One-time', render: (r: any) => `Rs ${Number(r.total_one_time ?? 0).toLocaleString('en-IN')}` },
    { key: 'last_event', header: 'Last', render: (r: any) => r.last_event ? new Date(r.last_event).toLocaleDateString() : '' },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '') },
    { key: 'events', header: 'Events', render: (r: any) => String(r.events ?? 0) },
    { key: 'mrr_delta', header: 'MRR Delta', render: (r: any) => `Rs ${Number(r.mrr_delta ?? 0).toLocaleString('en-IN')}` },
    { key: 'one_time', header: 'One-time', render: (r: any) => `Rs ${Number(r.one_time ?? 0).toLocaleString('en-IN')}` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'org_name', header: 'Account', render: (r: any) => String(r.org_name ?? '(unknown)') },
    { key: 'expansion_type', header: 'Type', render: (r: any) => String(r.expansion_type ?? '') },
    { key: 'mrr_delta', header: 'MRR Delta', render: (r: any) => `Rs ${Number(r.mrr_delta ?? 0).toLocaleString('en-IN')}` },
    { key: 'one_time', header: 'One-time', render: (r: any) => `Rs ${Number(r.one_time ?? 0).toLocaleString('en-IN')}` },
    { key: 'source', header: 'Source', render: (r: any) => String(r.source ?? '') },
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ? new Date(r.occurred_at).toLocaleDateString() : '' },
  ];

  const playbookCols: Column<any>[] = [
    { key: 'playbook_name', header: 'Playbook', render: (r: any) => String(r.playbook_name ?? '') },
    { key: 'target_segment', header: 'Segment', render: (r: any) => String(r.target_segment ?? '') },
    { key: 'trigger_signal', header: 'Trigger', render: (r: any) => String(r.trigger_signal ?? '') },
    { key: 'expected_lift', header: 'Expected Lift', render: (r: any) => `Rs ${Number(r.expected_lift ?? 0).toLocaleString('en-IN')}` },
    { key: 'conv_rate', header: 'Conv %', render: (r: any) => `${Number(r.conv_rate ?? 0).toFixed(1)}%` },
    { key: 'active', header: 'Active', render: (r: any) => r.active ? 'yes' : 'no' },
    { key: 'owner', header: 'Owner', render: (r: any) => String(r.owner ?? '') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Customer Expansion Revenue Tracker</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Existing customers buying more — new sites, AMC tier-ups, new equipment classes, MRR delta over last 90 days.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Events (90d)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_events ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>MRR Delta (90d)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>Rs {Number(summary.total_mrr_delta ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>One-time Revenue</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>Rs {Number(summary.total_one_time ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Organic %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(summary.organic_pct ?? 0).toFixed(1)}%</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Avg MRR Lift</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>Rs {Number(summary.avg_mrr_lift ?? 0).toLocaleString('en-IN')}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By Expansion Type</h2>
        <DataTable columns={byTypeCols} rows={byType} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Expanding Accounts</h2>
        <DataTable columns={topCols} rows={top} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Trend (12mo)</h2>
        <DataTable columns={monthlyCols} rows={monthly} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Expansion Events</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expansion Playbooks</h2>
        <DataTable columns={playbookCols} rows={playbooks} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}