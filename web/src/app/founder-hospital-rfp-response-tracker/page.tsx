import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rfpsRes, eventsRes, stageRes, aggRes] = await Promise.all([
    sb.rpc('list_rfps_r2207'),
    sb.rpc('recent_actions_r2207'),
    sb.rpc('top_stage_r2207'),
    sb.rpc('aggregate_rfp_r2207'),
  ]);

  const rfps = (rfpsRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const stages = (stageRes.data ?? []) as any[];
  const agg = ((aggRes.data ?? [])[0] ?? {}) as any;

  const rfpCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'title', header: 'RFP Title', render: (r: any) => r.rfp_title },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'bid', header: 'Bid (Rs)', render: (r: any) => (r.bid_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'win', header: 'Win %', render: (r: any) => `${r.win_probability_pct ?? 0}%` },
    { key: 'expected', header: 'Expected (Rs)', render: (r: any) => (r.expected_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'days', header: 'Days to decision', render: (r: any) => r.days_to_decision ?? '—' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'event', header: 'Event', render: (r: any) => r.event_type },
    { key: 'detail', header: 'Detail', render: (r: any) => r.detail ?? '—' },
    { key: 'at', header: 'At', render: (r: any) => new Date(r.created_at).toLocaleString('en-IN') },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'count', header: 'RFPs', render: (r: any) => r.rfp_count },
    { key: 'bid', header: 'Total bid (Rs)', render: (r: any) => (r.total_bid_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'expected', header: 'Weighted (Rs)', render: (r: any) => (r.total_expected_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'avg', header: 'Avg win %', render: (r: any) => `${r.avg_win_pct ?? 0}%` },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1>Hospital RFP response tracker</h1>
      <p>Active hospital RFPs, win probability, value at stake & days to decision.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, margin: '16px 0' }}>
        <div><strong>Active RFPs:</strong> {agg.active_rfp_count ?? 0}</div>
        <div><strong>Value at stake:</strong> Rs {(agg.total_value_at_stake_rupees ?? 0).toLocaleString('en-IN')}</div>
        <div><strong>Weighted pipeline:</strong> Rs {(agg.weighted_pipeline_rupees ?? 0).toLocaleString('en-IN')}</div>
        <div><strong>Avg days to decision:</strong> {agg.avg_days_to_decision ?? '0'}</div>
        <div><strong>Closing &lt;= 7d:</strong> {agg.closing_within_7d ?? 0}</div>
        <div><strong>Awarded (30d):</strong> {agg.awarded_30d_count ?? 0}</div>
        <div><strong>Awarded value (30d):</strong> Rs {(agg.awarded_30d_value_rupees ?? 0).toLocaleString('en-IN')}</div>
      </section>

      <h2>Active & pending RFPs</h2>
      <DataTable columns={rfpCols} rows={rfps} rowKey={(_, i) => String(i)} />

      <h2>Stage breakdown</h2>
      <DataTable columns={stageCols} rows={stages} rowKey={(_, i) => String(i)} />

      <h2>Recent events</h2>
      <DataTable columns={eventCols} rows={events} rowKey={(_, i) => String(i)} />
    </div>
  );
}
