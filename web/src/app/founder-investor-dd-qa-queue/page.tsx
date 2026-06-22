import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [qRes, evRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_investor_dd_questions_r2210'),
    sb.rpc('recent_actions_r2210'),
    sb.rpc('top_investors_r2210'),
    sb.rpc('aggregate_dd_queue_r2210'),
  ]);

  const questions: any[] = Array.isArray(qRes.data) ? qRes.data : [];
  const events: any[] = Array.isArray(evRes.data) ? evRes.data : [];
  const investors: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const agg: any = Array.isArray(aggRes.data) && aggRes.data.length > 0 ? aggRes.data[0] : {};

  const qCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '-') },
    { key: 'question_topic', header: 'Topic', render: (r: any) => String(r.question_topic ?? '') },
    { key: 'question_text', header: 'Question', render: (r: any) => String(r.question_text ?? '').slice(0, 80) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? 'unassigned') },
    { key: 'asked_on', header: 'Asked', render: (r: any) => String(r.asked_on ?? '') },
    { key: 'days_open', header: 'Days open', render: (r: any) => String(r.days_open ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '') },
    { key: 'due_on', header: 'Due', render: (r: any) => String(r.due_on ?? '-') },
  ];

  const evCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString() },
    { key: 'event_type', header: 'Event', render: (r: any) => String(r.event_type ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'note', header: 'Note', render: (r: any) => String(r.note ?? '').slice(0, 100) },
  ];

  const invCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '') },
    { key: 'investor_firm', header: 'Firm', render: (r: any) => String(r.investor_firm ?? '-') },
    { key: 'total_questions', header: 'Total Q', render: (r: any) => String(r.total_questions ?? 0) },
    { key: 'open_questions', header: 'Open', render: (r: any) => String(r.open_questions ?? 0) },
    { key: 'answered_questions', header: 'Answered', render: (r: any) => String(r.answered_questions ?? 0) },
    { key: 'avg_days_to_answer', header: 'Avg days to answer', render: (r: any) => String(r.avg_days_to_answer ?? '-') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Investor due-diligence Q&A queue
      </h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Track open DD questions from prospective investors — owner, days open, response status.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Stat label="Total questions" value={agg.total_questions ?? 0} />
        <Stat label="Open" value={agg.open_count ?? 0} />
        <Stat label="In progress" value={agg.in_progress_count ?? 0} />
        <Stat label="Answered" value={agg.answered_count ?? 0} />
        <Stat label="Blocked" value={agg.blocked_count ?? 0} />
        <Stat label="Urgent & open" value={agg.urgent_open ?? 0} />
        <Stat label="Overdue" value={agg.overdue_count ?? 0} />
        <Stat label="Avg days open" value={agg.avg_days_open ?? 0} />
        <Stat label="Oldest open (days)" value={agg.oldest_open_days ?? 0} />
        <Stat label="Unique investors" value={agg.unique_investors ?? 0} />
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Open queue</h2>
      <DataTable
        rows={questions}
        columns={qCols}
        rowKey={(_, i) => String(i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Top investors by activity</h2>
      <DataTable
        rows={investors}
        columns={invCols}
        rowKey={(_, i) => String(i)}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Recent events</h2>
      <DataTable
        rows={events}
        columns={evCols}
        rowKey={(_, i) => String(i)}
      />
    </main>
  );
}

function Stat({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{String(value)}</div>
    </div>
  );
}
