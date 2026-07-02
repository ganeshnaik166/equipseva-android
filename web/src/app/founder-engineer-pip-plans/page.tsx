import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerPipPlansPage() {
  const sb = await getSupabaseServerClient();

  const [pipsRes, activeRes, milestonesRes] = await Promise.all([
    sb.rpc('list_pips_r1952'),
    sb.rpc('active_pips_r1952'),
    sb.rpc('recent_milestones_r1952'),
  ]);

  const pips: any[] = Array.isArray(pipsRes.data) ? pipsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const milestones: any[] = Array.isArray(milestonesRes.data) ? milestonesRes.data : [];

  const pipColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id ?? '-'}</span> },
    { key: 'pip_reason', header: 'Reason', render: (r: any) => <span>{String(r.pip_reason ?? '-')}</span> },
    { key: 'pip_duration_days', header: 'Days', render: (r: any) => <span>{String(r.pip_duration_days ?? '-')}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{String(r.status ?? '-')}</span> },
    { key: 'started_at', header: 'Started', render: (r: any) => <span>{r.started_at ? new Date(r.started_at).toLocaleDateString() : '-'}</span> },
    { key: 'ended_at', header: 'Ended', render: (r: any) => <span>{r.ended_at ? new Date(r.ended_at).toLocaleDateString() : '-'}</span> },
    { key: 'target_metrics_md', header: 'Targets', render: (r: any) => <span>{r.target_metrics_md ? String(r.target_metrics_md).slice(0, 100) : '-'}</span> },
  ];

  const activeColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id ?? '-'}</span> },
    { key: 'pip_reason', header: 'Reason', render: (r: any) => <span>{String(r.pip_reason ?? '-')}</span> },
    { key: 'pip_duration_days', header: 'Plan Days', render: (r: any) => <span>{String(r.pip_duration_days ?? '-')}</span> },
    { key: 'days_elapsed', header: 'Days Elapsed', render: (r: any) => <span>{String(r.days_elapsed ?? 0)}</span> },
    { key: 'started_at', header: 'Started', render: (r: any) => <span>{r.started_at ? new Date(r.started_at).toLocaleDateString() : '-'}</span> },
  ];

  const milestoneColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? '-'}</span> },
    { key: 'milestone_type', header: 'Type', render: (r: any) => <span>{String(r.milestone_type ?? '-')}</span> },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => <span>{r.reviewed_at ? new Date(r.reviewed_at).toLocaleString() : '-'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '-'}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span>{r.score == null ? '-' : String(r.score)}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span>{r.notes_md ? String(r.notes_md).slice(0, 120) : '-'}</span> },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>Engineer Performance Improvement Plans</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track PIPs for engineers with repeat complaints, quality drops, no-shows, safety violations, or expertise gaps.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>Active PIPs</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Plans currently in progress (status active or extended). Review weekly at minimum.
        </p>
        <DataTable
          rows={active}
          columns={activeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>All PIP Plans</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Full history of PIPs across all engineers. Up to 200 most recent.
        </p>
        <DataTable
          rows={pips}
          columns={pipColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>Recent Milestone Reviews</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Latest weekly and monthly review entries logged against active PIPs. Score is on a scale of at least zero.
        </p>
        <DataTable
          rows={milestones}
          columns={milestoneColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
