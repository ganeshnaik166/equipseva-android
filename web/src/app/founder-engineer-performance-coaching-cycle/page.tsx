import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cyclesRes, activeRes, milestonesRes] = await Promise.all([
    sb.rpc('list_cycles_r2148', { p_limit: 200 }),
    sb.rpc('active_cycles_r2148'),
    sb.rpc('recent_milestones_r2148', { p_limit: 50 }),
  ]);

  const cycles: any[] = Array.isArray(cyclesRes.data) ? cyclesRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const milestones: any[] = Array.isArray(milestonesRes.data) ? milestonesRes.data : [];

  const cycleCols: Column<any>[] = [
    { key: 'id', header: 'Cycle', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'cycle_focus', header: 'Focus', render: (r: any) => String(r.cycle_focus ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleString() : '' },
    { key: 'expected_complete_at', header: 'Expected', render: (r: any) => r.expected_complete_at ? new Date(r.expected_complete_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'id', header: 'Cycle', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'cycle_focus', header: 'Focus', render: (r: any) => String(r.cycle_focus ?? '') },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleString() : '' },
    { key: 'expected_complete_at', header: 'Expected', render: (r: any) => r.expected_complete_at ? new Date(r.expected_complete_at).toLocaleString() : '' },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'cycle_id', header: 'Cycle', render: (r: any) => String(r.cycle_id ?? '').slice(0, 8) },
    { key: 'milestone_type', header: 'Type', render: (r: any) => String(r.milestone_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'score', header: 'Score', render: (r: any) => r.score == null ? '' : String(r.score) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Engineer Performance Coaching Cycle</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Founder console for coaching cycles, milestones, and status transitions. Round r2148.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active Cycles</h2>
        <p style={{ color: '#666', marginBottom: 10 }}>Cycles currently in progress.</p>
        <DataTable
          rows={active}
          columns={activeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Milestones</h2>
        <p style={{ color: '#666', marginBottom: 10 }}>Latest coaching milestones logged across all cycles.</p>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Cycles</h2>
        <p style={{ color: '#666', marginBottom: 10 }}>Full coaching cycle history with focus areas and status.</p>
        <DataTable
          rows={cycles}
          columns={cycleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
