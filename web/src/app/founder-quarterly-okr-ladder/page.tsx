import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyOkrLadderPage() {
  const sb = await getSupabaseServerClient();

  const [okrsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_okrs_r1914'),
    sb.rpc('active_okrs_r1914'),
    sb.rpc('recent_progress_r1914'),
  ]);

  const okrs = (okrsRes.data ?? []) as any[];
  const active = (activeRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const okrCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => <span>{r.quarter_label ?? ''}</span> },
    { key: 'objective_md', header: 'Objective', render: (r: any) => <span style={{ maxWidth: 360, display: 'inline-block' }}>{r.objective_md ?? ''}</span> },
    { key: 'target_score', header: 'Target', render: (r: any) => <span>{r.target_score ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? ''}</span> },
    { key: 'started_at', header: 'Started', render: (r: any) => <span>{r.started_at ? new Date(r.started_at).toLocaleDateString() : ''}</span> },
    { key: 'completed_at', header: 'Completed', render: (r: any) => <span>{r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '—'}</span> },
    { key: 'final_score', header: 'Final', render: (r: any) => <span>{r.final_score ?? '—'}</span> },
  ];

  const activeCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => <span>{r.quarter_label ?? ''}</span> },
    { key: 'objective_md', header: 'Objective', render: (r: any) => <span style={{ maxWidth: 360, display: 'inline-block' }}>{r.objective_md ?? ''}</span> },
    { key: 'target_score', header: 'Target', render: (r: any) => <span>{r.target_score ?? 0}</span> },
    { key: 'latest_score', header: 'Latest score', render: (r: any) => <span>{r.latest_score ?? '—'}</span> },
    { key: 'started_at', header: 'Started', render: (r: any) => <span>{r.started_at ? new Date(r.started_at).toLocaleDateString() : ''}</span> },
  ];

  const progressCols: Column<any>[] = [
    { key: 'log_at', header: 'Logged', render: (r: any) => <span>{r.log_at ? new Date(r.log_at).toLocaleString() : ''}</span> },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => <span>{r.quarter_label ?? ''}</span> },
    { key: 'progress_score', header: 'Score', render: (r: any) => <span>{r.progress_score ?? 0}</span> },
    { key: 'blocker_md', header: 'Blocker', render: (r: any) => <span style={{ maxWidth: 320, display: 'inline-block' }}>{r.blocker_md ?? '—'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '—'}</span> },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Quarterly OKR Ladder</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track quarterly OKRs and key results progress. Founder-only view of objectives, target scores, and progress logs over time.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active OKRs (at least one open quarter)</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All OKRs</h2>
        <DataTable rows={okrs} columns={okrCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent progress logs</h2>
        <DataTable rows={recent} columns={progressCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
