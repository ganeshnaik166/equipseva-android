import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [heatmapsRes, zonesRes, patternsRes] = await Promise.all([
    sb.rpc('list_heatmaps_r1991'),
    sb.rpc('spike_zones_r1991'),
    sb.rpc('recent_patterns_r1991'),
  ]);

  const heatmaps: any[] = Array.isArray(heatmapsRes.data) ? heatmapsRes.data : [];
  const zones: any[] = Array.isArray(zonesRes.data) ? zonesRes.data : [];
  const patterns: any[] = Array.isArray(patternsRes.data) ? patternsRes.data : [];

  const heatmapCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'day_of_week', header: 'Day', render: (r: any) => String(r.day_of_week ?? '').toUpperCase() },
    { key: 'cancellation_count', header: 'Cancellations', render: (r: any) => String(r.cancellation_count ?? 0) },
    { key: 'sample_period_label', header: 'Sample Period', render: (r: any) => String(r.sample_period_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const zoneCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'day_of_week', header: 'Day', render: (r: any) => String(r.day_of_week ?? '').toUpperCase() },
    { key: 'total_cancellations', header: 'Total Cancellations', render: (r: any) => String(r.total_cancellations ?? 0) },
    { key: 'hotspots', header: 'Hotspots (at least 5)', render: (r: any) => String(r.hotspots ?? 0) },
  ];

  const patternCols: Column<any>[] = [
    { key: 'pattern_type', header: 'Pattern', render: (r: any) => String(r.pattern_type ?? '') },
    { key: 'observed_at', header: 'Observed', render: (r: any) => r.observed_at ? new Date(r.observed_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 120) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Service Cancellation Heatmap</h1>
        <p className="text-sm text-gray-600">
          Cancellations by day and region. Spot recurring spikes and escalate when counts stay above
          threshold across consecutive weeks.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Heatmap snapshots</h2>
        <p className="text-sm text-gray-600">Recent captures by region and weekday.</p>
        <DataTable
          rows={heatmaps}
          columns={heatmapCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Spike zones</h2>
        <p className="text-sm text-gray-600">Aggregated active heatmap rows. Hotspots count rows where cancellations stay at or above five.</p>
        <DataTable
          rows={zones}
          columns={zoneCols}
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent patterns</h2>
        <p className="text-sm text-gray-600">Latest founder annotations and escalations.</p>
        <DataTable
          rows={patterns}
          columns={patternCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
