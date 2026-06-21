import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInboxTriagePage() {
  const sb = await getSupabaseServerClient();

  const [triageRes, summaryRes, metricRes, decisionsRes] = await Promise.all([
    sb.rpc('list_triage_r1802'),
    sb.rpc('urgency_summary_r1802'),
    sb.rpc('inbox_zero_metric_r1802'),
    sb.rpc('list_decisions_r1802', { p_triage_id: null }),
  ]);

  const triage: any[] = Array.isArray(triageRes.data) ? triageRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const metric: any = Array.isArray(metricRes.data) && metricRes.data.length > 0 ? metricRes.data[0] : null;
  const decisions: any[] = Array.isArray(decisionsRes.data) ? decisionsRes.data : [];

  const triageCols: Column<any>[] = [
    { key: 'received_at', header: 'Received', render: (r: any) => r.received_at ? new Date(r.received_at).toLocaleString() : '-' },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '-') },
    { key: 'from_name', header: 'From', render: (r: any) => String(r.from_name ?? '-') },
    { key: 'from_email', header: 'Email', render: (r: any) => String(r.from_email ?? '-') },
    { key: 'subject', header: 'Subject', render: (r: any) => String(r.subject ?? '-') },
    { key: 'urgency', header: 'Urgency', render: (r: any) => String(r.urgency ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'founder_note', header: 'Note', render: (r: any) => String(r.founder_note ?? '-') },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'urgency', header: 'Urgency', render: (r: any) => String(r.urgency ?? '-') },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => String(r.resolved_count ?? 0) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision_at', header: 'When', render: (r: any) => r.decision_at ? new Date(r.decision_at).toLocaleString() : '-' },
    { key: 'triage_id', header: 'Triage', render: (r: any) => String(r.triage_id ?? '-').slice(0, 8) },
    { key: 'decision', header: 'Decision', render: (r: any) => String(r.decision ?? '-') },
    { key: 'delegated_to_email', header: 'Delegated To', render: (r: any) => String(r.delegated_to_email ?? '-') },
    { key: 'decision_note', header: 'Note', render: (r: any) => String(r.decision_note ?? '-') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Inbox Triage</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Personal inbound across email, WhatsApp, LinkedIn, SMS, phone & in-person. Triage to inbox zero.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Inbox Zero Metric</h2>
        {metric ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Total</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(metric.total_msgs ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Open</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(metric.open_msgs ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Archived</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(metric.archived_msgs ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Inbox Zero %</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(metric.inbox_zero_pct ?? 0)}%</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Critical Open</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(metric.critical_open ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <div style={{ fontSize: 12, color: '#777' }}>Oldest Open</div>
              <div style={{ fontSize: 14, fontWeight: 600 }}>
                {metric.oldest_open_received_at ? new Date(metric.oldest_open_received_at).toLocaleString() : '-'}
              </div>
            </div>
          </div>
        ) : (
          <p style={{ color: '#777' }}>No metric data.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Urgency Summary</h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.urgency ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Triage Queue</h2>
        <DataTable rows={triage} columns={triageCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Decisions</h2>
        <DataTable rows={decisions} columns={decisionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
