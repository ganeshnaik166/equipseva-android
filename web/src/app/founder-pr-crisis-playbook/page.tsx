import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPrCrisisPlaybookPage() {
  const sb = await getSupabaseServerClient();

  const [crisesRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_crises_r2030'),
    sb.rpc('active_crises_r2030'),
    sb.rpc('recent_actions_r2030'),
  ]);

  const crises: any[] = Array.isArray(crisesRes.data) ? crisesRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const fmt = (v: any) => (v ? new Date(v).toLocaleString() : '—');

  const allCols: Column<any>[] = [
    { key: 'crisis_label', header: 'Label', render: (r: any) => r.crisis_label ?? '—' },
    { key: 'crisis_severity', header: 'Severity', render: (r: any) => r.crisis_severity ?? '—' },
    { key: 'crisis_category', header: 'Category', render: (r: any) => r.crisis_category ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmt(r.opened_at) },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmt(r.closed_at) },
  ];

  const activeCols: Column<any>[] = [
    { key: 'crisis_label', header: 'Label', render: (r: any) => r.crisis_label ?? '—' },
    { key: 'crisis_severity', header: 'Severity', render: (r: any) => r.crisis_severity ?? '—' },
    { key: 'crisis_category', header: 'Category', render: (r: any) => r.crisis_category ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmt(r.opened_at) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'crisis_label', header: 'Crisis', render: (r: any) => r.crisis_label ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmt(r.taken_at) },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.5rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Founder PR Crisis Playbook
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Round 2030. Track PR crisis events plus playbook actions taken to contain them.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>
          Active crises
        </h2>
        <p style={{ color: '#777', fontSize: '0.9rem', marginBottom: '0.5rem' }}>
          Open or escalated, sorted by severity then opened time.
        </p>
        <DataTable
          rows={active}
          columns={activeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>
          All crises
        </h2>
        <p style={{ color: '#777', fontSize: '0.9rem', marginBottom: '0.5rem' }}>
          Recent 200 entries across all statuses.
        </p>
        <DataTable
          rows={crises}
          columns={allCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>
          Recent actions
        </h2>
        <p style={{ color: '#777', fontSize: '0.9rem', marginBottom: '0.5rem' }}>
          Latest 100 actions logged across all crises.
        </p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
