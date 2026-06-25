import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    leakageRes,
    actionsRes,
    topFocusRes,
    kindDistRes,
    statusFunnelRes,
    quarterTrendRes,
    summaryRes,
  ] = await Promise.all([
    supabase.rpc('list_leakage_r2651'),
    supabase.rpc('list_recovery_actions_r2651'),
    supabase.rpc('top_leakage_focus_r2651'),
    supabase.rpc('leakage_kind_distribution_r2651'),
    supabase.rpc('status_funnel_r2651'),
    supabase.rpc('quarterly_leakage_trend_r2651'),
    supabase.rpc('total_leakage_summary_r2651'),
  ]);

  const leakage = (leakageRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topFocus = (topFocusRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const quarterTrend = (quarterTrendRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];

  const leakageCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'leakage_kind', header: 'Kind', render: (r: any) => r.leakage_kind },
    { key: 'leakage_rupees', header: 'Rupees', render: (r: any) => `₹${Number(r.leakage_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString('en-IN') },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'leakage_kind', header: 'Kind', render: (r: any) => r.leakage_kind },
    { key: 'leakage_rupees', header: 'Rupees', render: (r: any) => `₹${Number(r.leakage_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'leakage_kind', header: 'Kind', render: (r: any) => r.leakage_kind },
    { key: 'leakage_count', header: 'Count', render: (r: any) => String(r.leakage_count) },
    { key: 'total_rupees', header: 'Total Rupees', render: (r: any) => `₹${Number(r.total_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'leakage_count', header: 'Count', render: (r: any) => String(r.leakage_count) },
    { key: 'total_rupees', header: 'Rupees', render: (r: any) => `₹${Number(r.total_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'leakage_count', header: 'Count', render: (r: any) => String(r.leakage_count) },
    { key: 'total_rupees', header: 'Rupees', render: (r: any) => `₹${Number(r.total_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'total_leakage_count', header: 'Items', render: (r: any) => String(r.total_leakage_count) },
    { key: 'total_rupees', header: 'Total', render: (r: any) => `₹${Number(r.total_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'open_rupees', header: 'Open + Review', render: (r: any) => `₹${Number(r.open_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'recovered_rupees', header: 'Recovered', render: (r: any) => `₹${Number(r.recovered_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Chain Quarterly Revenue Leakage Audit
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track quarterly revenue leakage across hospital chains &amp; drive recovery actions.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No summary yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Leakage Focus</h2>
        <DataTable
          rows={topFocus}
          columns={focusCols}
          emptyMessage="No open leakage"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Leakage Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindCols}
          emptyMessage="No leakage recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusCols}
          emptyMessage="No items"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Quarterly Trend</h2>
        <DataTable
          rows={quarterTrend}
          columns={trendCols}
          emptyMessage="No quarters"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Leakage Records</h2>
        <DataTable
          rows={leakage}
          columns={leakageCols}
          emptyMessage="No leakage logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recovery Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No actions yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
