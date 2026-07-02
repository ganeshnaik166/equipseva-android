import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Cluster = {
  id: string;
  cluster_label: string;
  region_label: string;
  hospital_count: number;
  current_engineers: number;
  optimal_engineers: number;
  optimization_status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  cluster_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const clustersRes = await sb.rpc('list_clusters_r2103');
  const needsRes = await sb.rpc('needs_adjustment_r2103');
  const recentRes = await sb.rpc('recent_actions_r2103');

  const clusters: Cluster[] = (clustersRes.data as Cluster[] | null) ?? [];
  const needs: Cluster[] = (needsRes.data as Cluster[] | null) ?? [];
  const recent: ActionRow[] = (recentRes.data as ActionRow[] | null) ?? [];

  const clusterCols: Column<Cluster>[] = [
    { key: 'cluster_label', header: 'Cluster', render: (r: any) => r.cluster_label },
    { key: 'region_label', header: 'Region', render: (r: any) => r.region_label },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count) },
    { key: 'current_engineers', header: 'Current engineers', render: (r: any) => String(r.current_engineers) },
    { key: 'optimal_engineers', header: 'Optimal engineers', render: (r: any) => String(r.optimal_engineers) },
    { key: 'optimization_status', header: 'Status', render: (r: any) => r.optimization_status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'cluster_id', header: 'Cluster id', render: (r: any) => String(r.cluster_id).slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Geographic Cluster Optimization</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Optimize geographic clustering for service coverage. Track hospital clusters, engineer staffing levels, and adjustment actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All clusters</h2>
        <DataTable
          rows={clusters}
          columns={clusterCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Clusters needing adjustment</h2>
        <p style={{ color: '#777', fontSize: 13, marginBottom: 8 }}>
          Clusters flagged as needs adjustment, overstaffed, or understaffed.
        </p>
        <DataTable
          rows={needs}
          columns={clusterCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent cluster actions</h2>
        <DataTable
          rows={recent}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
