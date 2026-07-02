import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Distribution = {
  id: string;
  region_label: string;
  period_label: string;
  total_jobs: number;
  active_engineers: number;
  avg_jobs_per_engineer: number;
  distribution_status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  dist_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [distsRes, criticalRes, actionsRes] = await Promise.all([
    sb.rpc('list_distributions_r2080'),
    sb.rpc('critical_distributions_r2080'),
    sb.rpc('recent_actions_r2080', { p_limit: 50 }),
  ]);

  const dists: Distribution[] = (distsRes.data as Distribution[]) || [];
  const critical: Distribution[] = (criticalRes.data as Distribution[]) || [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) || [];

  const distCols: Column<Distribution>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'active_engineers', header: 'Active Engineers', render: (r: any) => String(r.active_engineers ?? 0) },
    { key: 'avg_jobs_per_engineer', header: 'Avg Jobs / Engineer', render: (r: any) => String(r.avg_jobs_per_engineer ?? 0) },
    { key: 'distribution_status', header: 'Status', render: (r: any) => String(r.distribution_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const criticalCols: Column<Distribution>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'active_engineers', header: 'Engineers', render: (r: any) => String(r.active_engineers ?? 0) },
    { key: 'avg_jobs_per_engineer', header: 'Avg per Eng', render: (r: any) => String(r.avg_jobs_per_engineer ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'dist_id', header: 'Distribution', render: (r: any) => String(r.dist_id ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Workload Distribution</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track how repair-job volume spreads across engineers per region and period. Flag concentrated
        or critical pockets and log rebalance actions taken by the ops team.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Distributions</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Most recent snapshots first. Status flags whether load is balanced, concentrated, skewed, or critical.
        </p>
        <DataTable
          rows={dists}
          columns={distCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical Distributions</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Regions and periods currently marked critical. Treat as priority rebalance candidates.
        </p>
        <DataTable
          rows={critical}
          columns={criticalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <p style={{ color: '#666', marginBottom: 12 }}>
          Latest interventions logged against any distribution snapshot.
        </p>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
