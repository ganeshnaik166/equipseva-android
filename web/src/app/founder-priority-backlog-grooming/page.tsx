import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, inboxRes, activeRes, deferredRes, catRes, completionRes, eventsRes] = await Promise.all([
    sb.rpc('fbg_summary_r2245'),
    sb.rpc('fbg_inbox_top_r2245', { p_limit: 50 }),
    sb.rpc('fbg_active_r2245'),
    sb.rpc('fbg_deferred_due_r2245'),
    sb.rpc('fbg_category_breakdown_r2245'),
    sb.rpc('fbg_completion_log_r2245', { p_days: 30 }),
    sb.rpc('fbg_events_recent_r2245', { p_limit: 40 }),
  ]);

  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] ?? {} : summaryRes.data ?? {};
  const inboxRows: any[] = Array.isArray(inboxRes.data) ? inboxRes.data : [];
  const activeRows: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const deferredRows: any[] = Array.isArray(deferredRes.data) ? deferredRes.data : [];
  const catRows: any[] = Array.isArray(catRes.data) ? catRes.data : [];
  const completionRows: any[] = Array.isArray(completionRes.data) ? completionRes.data : [];
  const eventRows: any[] = Array.isArray(eventsRes.data) ? eventsRes.data : [];

  const inboxCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '') },
    { key: 'source', header: 'Source', render: (r: any) => String(r.source ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '').toUpperCase() },
    { key: 'ice_score', header: 'ICE', render: (r: any) => Number(r.ice_score ?? 0).toFixed(2) },
    { key: 'raised_by_email', header: 'Raised By', render: (r: any) => String(r.raised_by_email ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '').toUpperCase() },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'ice_score', header: 'ICE', render: (r: any) => Number(r.ice_score ?? 0).toFixed(2) },
    { key: 'assignee_email', header: 'Assignee', render: (r: any) => String(r.assignee_email ?? 'unassigned') },
    { key: 'effort_days', header: 'Effort (d)', render: (r: any) => r.effort_days != null ? Number(r.effort_days).toFixed(1) : '-' },
    { key: 'expected_value_rupees', header: 'Expected Value', render: (r: any) => r.expected_value_rupees != null ? '₹' + Number(r.expected_value_rupees).toLocaleString('en-IN') : '-' },
    { key: 'groomed_at', header: 'Groomed', render: (r: any) => r.groomed_at ? new Date(r.groomed_at).toLocaleDateString() : '-' },
  ];

  const deferredCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '').toUpperCase() },
    { key: 'ice_score', header: 'ICE', render: (r: any) => Number(r.ice_score ?? 0).toFixed(2) },
    { key: 'defer_until', header: 'Defer Until', render: (r: any) => r.defer_until ? new Date(r.defer_until).toLocaleDateString() : '-' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count ?? 0) },
    { key: 'avg_ice', header: 'Avg ICE', render: (r: any) => Number(r.avg_ice ?? 0).toFixed(2) },
    { key: 'top_priority', header: 'Top Priority', render: (r: any) => String(r.top_priority ?? '-').toUpperCase() },
  ];

  const completionCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'priority', header: 'Priority', render: (r: any) => String(r.priority ?? '').toUpperCase() },
    { key: 'ice_score', header: 'ICE', render: (r: any) => Number(r.ice_score ?? 0).toFixed(2) },
    { key: 'outcome_note', header: 'Outcome', render: (r: any) => String(r.outcome_note ?? '') },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleString() : '-' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'item_title', header: 'Item', render: (r: any) => String(r.item_title ?? '') },
    { key: 'event_type', header: 'Event', render: (r: any) => String(r.event_type ?? '') },
    { key: 'old_value', header: 'From', render: (r: any) => String(r.old_value ?? '') },
    { key: 'new_value', header: 'To', render: (r: any) => String(r.new_value ?? '') },
    { key: 'note', header: 'Note', render: (r: any) => String(r.note ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Founder Priority Backlog Grooming</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Incoming founder-only requests and ideas. Triage, prioritize (ICE), assign or defer, and log completion.
        High ICE (score &gt;= 5.0) bubbles to the top automatically.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 28 }}>
        <Stat label="Inbox" value={summary.inbox_count} hint="Untriaged" />
        <Stat label="Triaged" value={summary.triaged_count} hint="Scored, awaiting assign" />
        <Stat label="In Progress" value={summary.in_progress_count} hint="Active work" />
        <Stat label="Deferred" value={summary.deferred_count} hint="Park for later" />
        <Stat label="Done (lifetime)" value={summary.done_count} hint="Completion log" />
        <Stat label="P0 Open" value={summary.p0_open} hint="Drop-everything" />
        <Stat label="P1 Open" value={summary.p1_open} hint="This week" />
        <Stat label="Avg ICE Open" value={Number(summary.avg_ice_open ?? 0).toFixed(2)} hint="Higher is better" />
        <Stat label="High ICE Open" value={summary.high_ice_open} hint="ICE &gt;= 5.0" />
      </div>

      <Section title="Inbox — top scored untriaged" subtitle="Sort by ICE score descending. Triage these first.">
        <DataTable columns={inboxCols} rows={inboxRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Active queue" subtitle="Assigned and in-progress items, sorted by priority then ICE.">
        <DataTable columns={activeCols} rows={activeRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Deferred — due for re-review" subtitle="Items past their defer-until date. Re-score or drop.">
        <DataTable columns={deferredCols} rows={deferredRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Category breakdown" subtitle="Where the backlog concentrates.">
        <DataTable columns={catCols} rows={catRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Completion log (last 30 days)" subtitle="What got shipped recently.">
        <DataTable columns={completionCols} rows={completionRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Recent activity trail" subtitle="Last 40 grooming events.">
        <DataTable columns={eventCols} rows={eventRows} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function Stat({ label, value, hint }: { label: string; value: any; hint: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value ?? 0}</div>
      <div style={{ fontSize: 11, color: '#9ca3af', marginTop: 2 }}>{hint}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>{title}</h2>
      {subtitle && <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>{subtitle}</p>}
      {children}
    </div>
  );
}
