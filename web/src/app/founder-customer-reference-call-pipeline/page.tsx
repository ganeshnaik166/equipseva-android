import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [requestsRes, callsRes, actionsRes, aggRes] = await Promise.all([
    sb.rpc('list_reference_requests_r2220'),
    sb.rpc('top_reference_calls_r2220'),
    sb.rpc('recent_actions_reference_r2220'),
    sb.rpc('aggregate_reference_pipeline_r2220'),
  ]);

  const requests: any[] = Array.isArray(requestsRes.data) ? requestsRes.data : [];
  const calls: any[] = Array.isArray(callsRes.data) ? callsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const agg: any = Array.isArray(aggRes.data) ? aggRes.data[0] : aggRes.data;

  const requestCols: Column<any>[] = [
    { key: 'prospect_org_name', header: 'Prospect Org', render: (r: any) => String(r.prospect_org_name ?? '') },
    { key: 'prospect_contact_name', header: 'Contact', render: (r: any) => String(r.prospect_contact_name ?? '') },
    { key: 'deal_size_rupees', header: 'Deal Size', render: (r: any) => `Rs.${Number(r.deal_size_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'deal_stage', header: 'Stage', render: (r: any) => String(r.deal_stage ?? '') },
    { key: 'reference_topic', header: 'Topic', render: (r: any) => String(r.reference_topic ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'matched_reference_org', header: 'Matched Ref', render: (r: any) => String(r.matched_reference_org ?? '-') },
    { key: 'requested_at', header: 'Requested', render: (r: any) => r.requested_at ? new Date(r.requested_at).toLocaleDateString() : '-' },
  ];

  const callCols: Column<any>[] = [
    { key: 'scheduled_at', header: 'Scheduled', render: (r: any) => r.scheduled_at ? new Date(r.scheduled_at).toLocaleString() : '-' },
    { key: 'duration_minutes', header: 'Duration (min)', render: (r: any) => String(r.duration_minutes ?? 0) },
    { key: 'call_outcome', header: 'Outcome', render: (r: any) => String(r.call_outcome ?? '') },
    { key: 'prospect_sentiment', header: 'Prospect Sentiment', render: (r: any) => String(r.prospect_sentiment ?? '-') },
    { key: 'reference_sentiment', header: 'Ref Sentiment', render: (r: any) => String(r.reference_sentiment ?? '-') },
    { key: 'conversion_impact', header: 'Conversion', render: (r: any) => String(r.conversion_impact ?? '') },
    { key: 'closed_won_amount_rupees', header: 'Won Amount', render: (r: any) => `Rs.${Number(r.closed_won_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'thanked', header: 'Thanked', render: (r: any) => r.reference_thank_you_sent ? 'Yes' : 'No' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Customer Reference Call Pipeline</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track prospective customers requesting references, match willing existing customers, schedule calls & measure conversion impact.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#f9fafb' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Requests</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{agg?.total_requests ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#f9fafb' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Matched</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{agg?.matched_requests ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#f9fafb' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Completed Calls</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{agg?.completed_calls ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#ecfdf5' }}>
          <div style={{ fontSize: 12, color: '#065f46' }}>Closed Won</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#065f46' }}>{agg?.closed_won_count ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#ecfdf5' }}>
          <div style={{ fontSize: 12, color: '#065f46' }}>Won Pipeline</div>
          <div style={{ fontSize: 20, fontWeight: 700, color: '#065f46' }}>Rs.{Number(agg?.closed_won_total_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#f9fafb' }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg Duration</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{agg?.avg_duration_minutes ?? 0} min</div>
        </div>
      </section>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 12 }}>Reference Requests</h2>
      <DataTable columns={requestCols} rows={requests} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32, marginBottom: 12 }}>Top Reference Calls (by Won Amount)</h2>
      <DataTable columns={callCols} rows={calls} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 32, marginBottom: 12 }}>Recent Founder Actions</h2>
      <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
    </main>
  );
}
