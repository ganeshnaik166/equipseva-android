import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

const FOUNDER_EMAIL = 'marketingtools@getphyllo.com';

function rupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function num(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user || user.email !== FOUNDER_EMAIL) redirect('/login');

  const [queue, summary, byType, overdue, recent, topImpact, events] = await Promise.all([
    supabase.rpc('fhfpdq_r2373_list_queue'),
    supabase.rpc('fhfpdq_r2373_summary'),
    supabase.rpc('fhfpdq_r2373_by_type'),
    supabase.rpc('fhfpdq_r2373_overdue'),
    supabase.rpc('fhfpdq_r2373_recent_decisions', { p_limit: 25 }),
    supabase.rpc('fhfpdq_r2373_top_impact', { p_limit: 10 }),
    supabase.rpc('fhfpdq_r2373_recent_events', { p_limit: 50 }),
  ]);

  const s = (summary.data && summary.data[0]) || {};

  const queueCols: Column<any>[] = [
    { key: 'subject_name', header: 'Person', render: (r) => r.subject_name },
    { key: 'subject_role', header: 'Role', render: (r) => r.subject_role },
    { key: 'decision_type', header: 'Decision', render: (r) => r.decision_type },
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'days_waiting', header: 'Days waiting', render: (r) => num(r.days_waiting) },
    { key: 'days_to_deadline', header: 'Days to deadline', render: (r) => r.days_to_deadline === null || r.days_to_deadline === undefined ? '-' : num(r.days_to_deadline) },
    { key: 'blast_radius_users', header: 'Blast radius', render: (r) => num(r.blast_radius_users) },
    { key: 'monthly_cost_delta_rupees', header: 'Monthly cost', render: (r) => rupees(r.monthly_cost_delta_rupees) },
    { key: 'rationale', header: 'Rationale', render: (r) => r.rationale ?? '-' },
  ];

  const typeCols: Column<any>[] = [
    { key: 'decision_type', header: 'Type', render: (r) => r.decision_type },
    { key: 'pending_count', header: 'Pending', render: (r) => num(r.pending_count) },
    { key: 'avg_days_waiting', header: 'Avg days waiting', render: (r) => Number(r.avg_days_waiting ?? 0).toFixed(1) },
    { key: 'total_blast_radius', header: 'Blast radius', render: (r) => num(r.total_blast_radius) },
    { key: 'total_cost_delta', header: 'Cost delta', render: (r) => rupees(r.total_cost_delta) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'subject_name', header: 'Person', render: (r) => r.subject_name },
    { key: 'subject_role', header: 'Role', render: (r) => r.subject_role },
    { key: 'decision_type', header: 'Decision', render: (r) => r.decision_type },
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'decision_deadline_at', header: 'Deadline', render: (r) => r.decision_deadline_at ? new Date(r.decision_deadline_at).toLocaleDateString() : '-' },
    { key: 'days_overdue', header: 'Days overdue', render: (r) => num(r.days_overdue) },
    { key: 'downstream_impact', header: 'Impact', render: (r) => r.downstream_impact ?? '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'subject_name', header: 'Person', render: (r) => r.subject_name },
    { key: 'subject_role', header: 'Role', render: (r) => r.subject_role },
    { key: 'decision_type', header: 'Decision', render: (r) => r.decision_type },
    { key: 'decision_status', header: 'Outcome', render: (r) => r.decision_status },
    { key: 'decided_at', header: 'Decided', render: (r) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '-' },
    { key: 'decided_by_email', header: 'By', render: (r) => r.decided_by_email ?? '-' },
    { key: 'days_to_close', header: 'Days to close', render: (r) => r.days_to_close === null || r.days_to_close === undefined ? '-' : num(r.days_to_close) },
  ];

  const impactCols: Column<any>[] = [
    { key: 'subject_name', header: 'Person', render: (r) => r.subject_name },
    { key: 'decision_type', header: 'Decision', render: (r) => r.decision_type },
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'blast_radius_users', header: 'Blast radius', render: (r) => num(r.blast_radius_users) },
    { key: 'monthly_cost_delta_rupees', header: 'Monthly cost', render: (r) => rupees(r.monthly_cost_delta_rupees) },
    { key: 'downstream_impact', header: 'Impact', render: (r) => r.downstream_impact ?? '-' },
  ];

  const evCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r) => new Date(r.recorded_at).toLocaleString() },
    { key: 'subject_name', header: 'Person', render: (r) => r.subject_name },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'event_actor_email', header: 'Actor', render: (r) => r.event_actor_email ?? '-' },
    { key: 'event_note', header: 'Note', render: (r) => r.event_note ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, marginBottom: 8 }}>Weekly Hire / Fire / Promote Decisions Queue</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Pending people decisions ranked by urgency & deadline. Shows days waiting, deadline countdown & downstream impact so founder can clear the queue weekly.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Pending total</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{num(s.pending_total)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fecaca', background: '#fef2f2', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Critical pending</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{num(s.pending_critical)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fed7aa', background: '#fff7ed', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Overdue</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{num(s.pending_overdue)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Avg days waiting</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{Number(s.avg_days_waiting ?? 0).toFixed(1)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Decided this week</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{num(s.decisions_this_week)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Monthly cost delta</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{rupees(s.total_monthly_cost_delta)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Total blast radius</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{num(s.total_blast_radius)}</div>
        </div>
      </section>

      <h2 style={{ fontSize: 18, margin: '24px 0 8px' }}>Pending queue (urgency & deadline ordered)</h2>
      <DataTable
        columns={queueCols}
        rows={queue.data ?? []}
        rowKey={(r: any) => r.id}
        emptyMessage="No pending people decisions."
      />

      <h2 style={{ fontSize: 18, margin: '24px 0 8px' }}>By decision type</h2>
      <DataTable
        columns={typeCols}
        rows={byType.data ?? []}
        rowKey={(r: any) => r.decision_type}
        emptyMessage="No pending types."
      />

      <h2 style={{ fontSize: 18, margin: '24px 0 8px' }}>Overdue (past deadline)</h2>
      <DataTable
        columns={overdueCols}
        rows={overdue.data ?? []}
        rowKey={(r: any) => r.id}
        emptyMessage="Nothing overdue."
      />

      <h2 style={{ fontSize: 18, margin: '24px 0 8px' }}>Highest-impact pending</h2>
      <DataTable
        columns={impactCols}
        rows={topImpact.data ?? []}
        rowKey={(r: any) => r.id}
        emptyMessage="No high-impact pending decisions."
      />

      <h2 style={{ fontSize: 18, margin: '24px 0 8px' }}>Recently decided</h2>
      <DataTable
        columns={recentCols}
        rows={recent.data ?? []}
        rowKey={(r: any) => r.id}
        emptyMessage="No recent decisions."
      />

      <h2 style={{ fontSize: 18, margin: '24px 0 8px' }}>Recent activity</h2>
      <DataTable
        columns={evCols}
        rows={events.data ?? []}
        rowKey={(r: any, i: number) => String(r.recorded_at) + ':' + i}
        emptyMessage="No activity yet."
      />
    </main>
  );
}
