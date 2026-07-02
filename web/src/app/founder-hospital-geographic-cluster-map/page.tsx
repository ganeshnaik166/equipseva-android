import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalGeographicClusterMapPage() {
  const sb = await getSupabaseServerClient();

  const [clustersRes, summaryRes, denseRes, orphansRes] = await Promise.all([
    sb.rpc('r1703_list_clusters'),
    sb.rpc('r1703_cluster_efficiency_summary'),
    sb.rpc('r1703_top_dense_clusters'),
    sb.rpc('r1703_hospitals_without_cluster'),
  ]);

  const clusters: any[] = Array.isArray(clustersRes.data) ? clustersRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const dense: any[] = Array.isArray(denseRes.data) ? denseRes.data : [];
  const orphans: any[] = Array.isArray(orphansRes.data) ? orphansRes.data : [];

  const clusterCols: Column<any>[] = [
    { key: 'cluster_label', header: 'Label', render: (r: any) => String(r.cluster_label ?? '') },
    { key: 'city', header: 'City', render: (r: any) => String(r.city ?? '') },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? 0) },
    { key: 'avg_distance_km', header: 'Avg dist (km)', render: (r: any) => String(r.avg_distance_km ?? 0) },
    { key: 'recommended_engineer_count', header: 'Rec. engineers', render: (r: any) => String(r.recommended_engineer_count ?? 0) },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '' },
  ];

  const denseCols: Column<any>[] = [
    { key: 'cluster_label', header: 'Label', render: (r: any) => String(r.cluster_label ?? '') },
    { key: 'city', header: 'City', render: (r: any) => String(r.city ?? '') },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? 0) },
    { key: 'avg_distance_km', header: 'Avg dist (km)', render: (r: any) => String(r.avg_distance_km ?? 0) },
    { key: 'density_score', header: 'Density score', render: (r: any) => String(r.density_score ?? 0) },
  ];

  const orphanCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'city', header: 'City', render: (r: any) => String(r.city ?? '') },
    { key: 'active_amc', header: 'AMC active', render: (r: any) => r.active_amc ? 'Yes' : 'No' },
    { key: 'hospital_user_id', header: 'User ID', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Geographic Cluster Map</h1>
        <p className="text-sm text-gray-600 mt-2">
          Dense hospital clusters per city. Drives routing efficiency, engineer staffing recommendations,
          and surfaces orphan hospitals not yet assigned to a cluster.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Network summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Total clusters</div>
            <div className="text-xl font-semibold">{summary?.total_clusters ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Clustered hospitals</div>
            <div className="text-xl font-semibold">{summary?.total_clustered_hospitals ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Avg hospitals/cluster</div>
            <div className="text-xl font-semibold">{summary?.avg_hospitals_per_cluster ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Avg distance (km)</div>
            <div className="text-xl font-semibold">{summary?.avg_distance_overall_km ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Rec. engineers total</div>
            <div className="text-xl font-semibold">{summary?.total_recommended_engineers ?? 0}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">All clusters</h2>
        <DataTable rows={clusters} columns={clusterCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Top dense clusters (density score)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Density score &gt;= hospitals per km. Higher means tighter clusters and lower routing cost.
        </p>
        <DataTable rows={dense} columns={denseCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Hospitals without a cluster</h2>
        <p className="text-xs text-gray-500 mb-2">
          Unassigned hospitals. Assign to nearest cluster or define a new one when count &gt; 3 in a region.
        </p>
        <DataTable rows={orphans} columns={orphanCols} rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)} />
      </section>
    </main>
  );
}
