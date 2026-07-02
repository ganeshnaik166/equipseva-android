import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerCallbackTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    callbacksRes,
    looseEndsRes,
    topEngineersRes,
    successRes,
    topicRes,
    csatRes,
    looseFocusRes,
  ] = await Promise.all([
    supabase.rpc('list_callbacks_r2522'),
    supabase.rpc('list_loose_ends_r2522'),
    supabase.rpc('top_callback_engineers_r2522'),
    supabase.rpc('success_kind_summary_r2522'),
    supabase.rpc('topic_kind_breakdown_r2522'),
    supabase.rpc('csat_distribution_r2522'),
    supabase.rpc('top_loose_end_focus_r2522'),
  ]);

  const callbacks = callbacksRes.data ?? [];
  const looseEnds = looseEndsRes.data ?? [];
  const topEngineers = topEngineersRes.data ?? [];
  const success = successRes.data ?? [];
  const topic = topicRes.data ?? [];
  const csat = csatRes.data ?? [];
  const looseFocus = looseFocusRes.data ?? [];

  const callbackCols: Column<any>[] = [
    { key: 'callback_at', header: 'When', render: (r: any) => new Date(r.callback_at).toLocaleDateString() },
    { key: 'visit_external_ref', header: 'Visit Ref', render: (r: any) => r.visit_external_ref ?? '—' },
    { key: 'topic_kind', header: 'Topic', render: (r: any) => r.topic_kind },
    { key: 'success_kind', header: 'Outcome', render: (r: any) => r.success_kind },
    { key: 'csat_score', header: 'CSAT /10', render: (r: any) => String(r.csat_score) },
    { key: 'upsell_opportunity_rupees', header: 'Upsell Rs', render: (r: any) => String(r.upsell_opportunity_rupees) },
    { key: 'loose_ends_count', header: 'Loose Ends', render: (r: any) => String(r.loose_ends_count) },
    { key: 'resolution_count', header: 'Resolutions', render: (r: any) => String(r.resolution_count) },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => String(r.resolved_count) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const looseEndCols: Column<any>[] = [
    { key: 'callback_at', header: 'When', render: (r: any) => new Date(r.callback_at).toLocaleDateString() },
    { key: 'visit_external_ref', header: 'Visit Ref', render: (r: any) => r.visit_external_ref ?? '—' },
    { key: 'loose_end_kind', header: 'Kind', render: (r: any) => r.loose_end_kind },
    { key: 'resolved_at', header: 'Resolved At', render: (r: any) => (r.resolved_at ? new Date(r.resolved_at).toLocaleDateString() : '—') },
    { key: 'resolution_summary', header: 'Summary', render: (r: any) => r.resolution_summary ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topEngineerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'callback_count', header: 'Callbacks', render: (r: any) => String(r.callback_count) },
    { key: 'connected_count', header: 'Connected', render: (r: any) => String(r.connected_count) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => (r.avg_csat == null ? '—' : String(r.avg_csat)) },
    { key: 'total_upsell_rupees', header: 'Upsell Rs', render: (r: any) => String(r.total_upsell_rupees) },
    { key: 'total_loose_ends', header: 'Loose Ends', render: (r: any) => String(r.total_loose_ends) },
  ];

  const successCols: Column<any>[] = [
    { key: 'success_kind', header: 'Outcome', render: (r: any) => r.success_kind },
    { key: 'callback_count', header: 'Count', render: (r: any) => String(r.callback_count) },
    { key: 'avg_csat', header: 'Avg CSAT (connected)', render: (r: any) => (r.avg_csat == null ? '—' : String(r.avg_csat)) },
    { key: 'share_pct', header: 'Share %', render: (r: any) => String(r.share_pct) },
  ];

  const topicCols: Column<any>[] = [
    { key: 'topic_kind', header: 'Topic', render: (r: any) => r.topic_kind },
    { key: 'callback_count', header: 'Count', render: (r: any) => String(r.callback_count) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => (r.avg_csat == null ? '—' : String(r.avg_csat)) },
    { key: 'total_upsell_rupees', header: 'Upsell Rs', render: (r: any) => String(r.total_upsell_rupees) },
    { key: 'total_loose_ends', header: 'Loose Ends', render: (r: any) => String(r.total_loose_ends) },
  ];

  const csatCols: Column<any>[] = [
    { key: 'csat_bucket', header: 'Bucket', render: (r: any) => r.csat_bucket },
    { key: 'callback_count', header: 'Count', render: (r: any) => String(r.callback_count) },
    { key: 'share_pct', header: 'Share %', render: (r: any) => String(r.share_pct) },
  ];

  const looseFocusCols: Column<any>[] = [
    { key: 'loose_end_kind', header: 'Kind', render: (r: any) => r.loose_end_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => String(r.in_progress_count) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => String(r.dropped_count) },
    { key: 'resolution_pct', header: 'Resolution %', render: (r: any) => String(r.resolution_pct) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Customer Callback Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Post-visit callbacks > topic > outcome > CSAT > upsell & loose-end resolution.
      </p>

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '16px 0 8px' }}>Callbacks</h2>
      <DataTable
        rows={callbacks}
        columns={callbackCols}
        emptyMessage="No callbacks recorded yet."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Loose Ends</h2>
      <DataTable
        rows={looseEnds}
        columns={looseEndCols}
        emptyMessage="No loose ends recorded yet."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Top Callback Engineers</h2>
      <DataTable
        rows={topEngineers}
        columns={topEngineerCols}
        emptyMessage="No engineer activity."
        rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
      />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Outcome Summary</h2>
      <DataTable
        rows={success}
        columns={successCols}
        emptyMessage="No outcomes."
        rowKey={(r: any, i: number) => String(r.success_kind ?? i)}
      />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Topic Breakdown</h2>
      <DataTable
        rows={topic}
        columns={topicCols}
        emptyMessage="No topic data."
        rowKey={(r: any, i: number) => String(r.topic_kind ?? i)}
      />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>CSAT Distribution</h2>
      <DataTable
        rows={csat}
        columns={csatCols}
        emptyMessage="No CSAT data."
        rowKey={(r: any, i: number) => String(r.csat_bucket ?? i)}
      />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Top Loose-End Focus Areas</h2>
      <DataTable
        rows={looseFocus}
        columns={looseFocusCols}
        emptyMessage="No loose-end data."
        rowKey={(r: any, i: number) => String(r.loose_end_kind ?? i)}
      />
    </div>
  );
}
