import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [coveragesRes, gapsRes, recentRes] = await Promise.all([
    sb.rpc('list_coverages_r2020'),
    sb.rpc('gap_regions_r2020'),
    sb.rpc('recent_actions_r2020'),
  ]);

  const coverages: any[] = (coveragesRes.data as any[]) || [];
  const gaps: any[] = (gapsRes.data as any[]) || [];
  const recents: any[] = (recentRes.data as any[]) || [];

  const coverageCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => r.region_label },
    { key: 'total_engineers', header: 'Total', render: (r: any) => r.total_engineers },
    { key: 'active_engineers', header: 'Active', render: (r: any) => r.active_engineers },
    { key: 'coverage_quality', header: 'Quality', render: (r: any) => r.coverage_quality },
    { key: 'area_sq_km', header: 'Area sq km', render: (r: any) => r.area_sq_km },
    { key: 'density_score', header: 'Density', render: (r: any) => r.density_score },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '') },
  ];

  const gapCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => r.region_label },
    { key: 'coverage_quality', header: 'Quality', render: (r: any) => r.coverage_quality },
    { key: 'density_score', header: 'Density', render: (r: any) => r.density_score },
    { key: 'active_engineers', header: 'Active engineers', render: (r: any) => r.active_engineers },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<any>[] = [
    { key: 'coverage_id', header: 'Coverage', render: (r: any) => r.coverage_id },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '' },
    { key: 'taken_at', header: 'When', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md || '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Geographic Coverage Map</h1>
        <p className="text-sm text-gray-600">Founder console — round r2020. Geographic coverage analysis across regions.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All coverage regions</h2>
        <DataTable rows={coverages} columns={coverageCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Gap regions (poor or gap quality)</h2>
        <DataTable rows={gaps} columns={gapCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent coverage actions</h2>
        <DataTable rows={recents} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
