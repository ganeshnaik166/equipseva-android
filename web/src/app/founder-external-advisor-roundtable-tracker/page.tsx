import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [summary, rts, advice, byDomain, byQuarter, overdue, topAdv] = await Promise.all([
    sb.rpc('r2253_summary'),
    sb.rpc('r2253_roundtables'),
    sb.rpc('r2253_advice_items'),
    sb.rpc('r2253_by_domain'),
    sb.rpc('r2253_by_quarter'),
    sb.rpc('r2253_overdue_advice'),
    sb.rpc('r2253_top_advisors'),
  ]);

  const s = (summary.data && summary.data[0]) || {};

  const rtCols: Column<any>[] = [
    { key: 'advisor_name', header: 'Advisor', render: (r) => r.advisor_name },
    { key: 'advisor_domain', header: 'Domain', render: (r) => r.advisor_domain },
    { key: 'advisor_seniority', header: 'Seniority', render: (r) => r.advisor_seniority },
    { key: 'meeting_quarter', header: 'Quarter', render: (r) => r.meeting_quarter },
    { key: 'meeting_held_on', header: 'Date', render: (r) => r.meeting_held_on },
    { key: 'meeting_format', header: 'Format', render: (r) => r.meeting_format },
    { key: 'topics_covered', header: 'Topics', render: (r) => `${r.topics_covered}/${r.topics_planned}` },
    { key: 'advice_quality_score', header: 'Quality', render: (r) => r.advice_quality_score ?? '—' },
    { key: 'attendance_status', header: 'Attendance', render: (r) => r.attendance_status },
  ];

  const adviceCols: Column<any>[] = [
    { key: 'advisor_name', header: 'Advisor', render: (r) => r.advisor_name },
    { key: 'topic', header: 'Topic', render: (r) => r.topic },
    { key: 'advice_category', header: 'Category', render: (r) => r.advice_category },
    { key: 'priority', header: 'Priority', render: (r) => r.priority.toUpperCase() },
    { key: 'follow_through_status', header: 'Status', render: (r) => r.follow_through_status },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date ?? '—' },
    { key: 'advice_summary', header: 'Summary', render: (r) => r.advice_summary },
  ];

  const domainCols: Column<any>[] = [
    { key: 'advisor_domain', header: 'Domain', render: (r) => r.advisor_domain },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
    { key: 'advice_count', header: 'Advice logged', render: (r) => r.advice_count },
    { key: 'done_count', header: 'Closed', render: (r) => r.done_count },
    { key: 'follow_through_rate', header: 'Follow-through %', render: (r) => (r.follow_through_rate ?? 0) + '%' },
  ];

  const quarterCols: Column<any>[] = [
    { key: 'meeting_quarter', header: 'Quarter', render: (r) => r.meeting_quarter },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
    { key: 'attended', header: 'Attended', render: (r) => r.attended },
    { key: 'avg_quality', header: 'Avg quality', render: (r) => r.avg_quality ?? '—' },
    { key: 'advice_logged', header: 'Advice logged', render: (r) => r.advice_logged },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'advisor_name', header: 'Advisor', render: (r) => r.advisor_name },
    { key: 'topic', header: 'Topic', render: (r) => r.topic },
    { key: 'priority', header: 'Priority', render: (r) => r.priority.toUpperCase() },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date },
    { key: 'days_overdue', header: 'Days overdue', render: (r) => r.days_overdue },
  ];

  const topCols: Column<any>[] = [
    { key: 'advisor_name', header: 'Advisor', render: (r) => r.advisor_name },
    { key: 'advisor_domain', header: 'Domain', render: (r) => r.advisor_domain },
    { key: 'sessions', header: 'Sessions', render: (r) => r.sessions },
    { key: 'avg_quality', header: 'Avg quality', render: (r) => r.avg_quality ?? '—' },
    { key: 'advice_done', header: 'Closed advice', render: (r) => r.advice_done },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>External advisor roundtable tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quarterly advisor sessions, advice items raised, and follow-through on commitments
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Roundtables" value={s.total_roundtables ?? 0} />
        <Card label="Advice items" value={s.total_advice_items ?? 0} />
        <Card label="Open items" value={s.open_items ?? 0} />
        <Card label="Done items" value={s.done_items ?? 0} />
        <Card label="P0 open" value={s.p0_open ?? 0} />
        <Card label="Avg quality" value={s.avg_quality ?? '—'} />
        <Card label="Attendance %" value={(s.attendance_rate ?? 0) + '%'} />
        <Card label="Follow-through %" value={(s.follow_through_rate ?? 0) + '%'} />
      </div>

      <Section title="Roundtables">
        <DataTable columns={rtCols} rows={rts.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Advice items (priority order)">
        <DataTable columns={adviceCols} rows={advice.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Overdue advice items">
        <DataTable columns={overdueCols} rows={overdue.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="By advisor domain">
        <DataTable columns={domainCols} rows={byDomain.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="By quarter">
        <DataTable columns={quarterCols} rows={byQuarter.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Top advisors by quality">
        <DataTable columns={topCols} rows={topAdv.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </div>
  );
}
