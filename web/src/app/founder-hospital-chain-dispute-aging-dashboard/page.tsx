import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainDisputeAgingDashboardPage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';
  const isFounder = email === 'marketingtools@getphyllo.com';

  if (!isFounder) {
    return (
      <main style={{ padding: 24 }}>
        <h1>Forbidden</h1>
        <p>Founder access only.</p>
      </main>
    );
  }

  const [kpis, rollup, buckets, hotList, timeline, typeMix, activity] = await Promise.all([
    supabase.rpc('r2363_dashboard_kpis'),
    supabase.rpc('r2363_chain_rollup'),
    supabase.rpc('r2363_age_buckets'),
    supabase.rpc('r2363_escalation_hot_list'),
    supabase.rpc('r2363_resolution_timeline'),
    supabase.rpc('r2363_type_mix'),
    supabase.rpc('r2363_recent_activity'),
  ]);

  const k = (kpis.data?.[0]) ?? {
    total_open: 0, total_escalated: 0, total_amount_open_rupees: 0,
    avg_open_age_days: 0, resolved_last_30d: 0, avg_resolution_days_30d: 0, chains_with_open: 0,
  };

  const rollupCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'in_review_count', header: 'In Review', render: (r: any) => r.in_review_count },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => r.escalated_count },
    { key: 'total_amount_rupees', header: 'Open Amount', render: (r: any) => `Rs ${Number(r.total_amount_rupees).toLocaleString('en-IN')}` },
    { key: 'bucket_0_7', header: '0-7d', render: (r: any) => r.bucket_0_7 },
    { key: 'bucket_8_30', header: '8-30d', render: (r: any) => r.bucket_8_30 },
    { key: 'bucket_31_60', header: '31-60d', render: (r: any) => r.bucket_31_60 },
    { key: 'bucket_61_plus', header: '61+d', render: (r: any) => r.bucket_61_plus },
    { key: 'oldest_open_days', header: 'Oldest (d)', render: (r: any) => Number(r.oldest_open_days).toFixed(1) },
  ];

  const bucketCols: Column<any>[] = [
    { key: 'bucket', header: 'Age Bucket', render: (r: any) => r.bucket },
    { key: 'dispute_count', header: 'Count', render: (r: any) => r.dispute_count },
    { key: 'total_amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.total_amount_rupees).toLocaleString('en-IN')}` },
  ];

  const hotCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'hospital_branch', header: 'Branch', render: (r: any) => r.hospital_branch },
    { key: 'dispute_ref', header: 'Ref', render: (r: any) => r.dispute_ref },
    { key: 'dispute_type', header: 'Type', render: (r: any) => r.dispute_type },
    { key: 'severity', header: 'Sev', render: (r: any) => r.severity?.toUpperCase() },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'amount_disputed_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.amount_disputed_rupees).toLocaleString('en-IN')}` },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => Number(r.age_days).toFixed(1) },
    { key: 'last_activity_at', header: 'Last Activity', render: (r: any) => new Date(r.last_activity_at).toLocaleString('en-IN') },
  ];

  const timelineCols: Column<any>[] = [
    { key: 'resolved_date', header: 'Date', render: (r: any) => r.resolved_date },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => r.resolved_count },
    { key: 'avg_age_days', header: 'Avg Age (d)', render: (r: any) => Number(r.avg_age_days).toFixed(1) },
    { key: 'total_amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.total_amount_rupees).toLocaleString('en-IN')}` },
  ];

  const typeCols: Column<any>[] = [
    { key: 'dispute_type', header: 'Type', render: (r: any) => r.dispute_type },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'total_amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.total_amount_rupees).toLocaleString('en-IN')}` },
    { key: 'avg_age_days', header: 'Avg Age (d)', render: (r: any) => Number(r.avg_age_days).toFixed(1) },
  ];

  const activityCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => new Date(r.occurred_at).toLocaleString('en-IN') },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'dispute_ref', header: 'Ref', render: (r: any) => r.dispute_ref },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '-' },
  ];

  const kpiCard = (label: string, value: string) => (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, minWidth: 160 }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Dispute Aging Dashboard
      </h1>
      <p style={{ color: '#6b7280', marginBottom: 16 }}>
        Open disputes per chain & age buckets & resolution timeline & escalation hot list.
      </p>

      <section style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 24 }}>
        {kpiCard('Open Disputes', String(k.total_open))}
        {kpiCard('Escalated', String(k.total_escalated))}
        {kpiCard('Open Amount', `Rs ${Number(k.total_amount_open_rupees).toLocaleString('en-IN')}`)}
        {kpiCard('Avg Open Age', `${Number(k.avg_open_age_days).toFixed(1)} d`)}
        {kpiCard('Resolved 30d', String(k.resolved_last_30d))}
        {kpiCard('Avg Resolution 30d', `${Number(k.avg_resolution_days_30d).toFixed(1)} d`)}
        {kpiCard('Chains w/ Open', String(k.chains_with_open))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Per-Chain Rollup</h2>
        <DataTable
          rows={rollup.data ?? []}
          columns={rollupCols}
          emptyMessage="No chains with disputes."
          rowKey={(r: any) => r.chain_id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Age Buckets (All Chains)</h2>
        <DataTable
          rows={buckets.data ?? []}
          columns={bucketCols}
          emptyMessage="No open disputes."
          rowKey={(r: any) => r.bucket}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Escalation Hot List</h2>
        <DataTable
          rows={hotList.data ?? []}
          columns={hotCols}
          emptyMessage="No escalations >= P1 or >30 days old."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Resolution Timeline (90d)</h2>
        <DataTable
          rows={timeline.data ?? []}
          columns={timelineCols}
          emptyMessage="No resolutions in last 90 days."
          rowKey={(r: any) => r.resolved_date}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Dispute Type Mix</h2>
        <DataTable
          rows={typeMix.data ?? []}
          columns={typeCols}
          emptyMessage="No open disputes."
          rowKey={(r: any) => r.dispute_type}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Activity</h2>
        <DataTable
          rows={activity.data ?? []}
          columns={activityCols}
          emptyMessage="No recent activity."
          rowKey={(r: any) => r.event_id}
        />
      </section>
    </main>
  );
}
