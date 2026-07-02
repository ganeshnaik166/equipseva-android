import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Founder1200ShipReflectionPage() {
  const sb = await getSupabaseServerClient();

  const [reflectionsRes, recentSignalsRes, topSignalsRes] = await Promise.all([
    sb.rpc('list_reflections_r2026'),
    sb.rpc('recent_signals_r2026'),
    sb.rpc('top_signals_r2026'),
  ]);

  const reflections: any[] = reflectionsRes.data ?? [];
  const recentSignals: any[] = recentSignalsRes.data ?? [];
  const topSignals: any[] = topSignalsRes.data ?? [];

  const reflectionColumns: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => r.milestone_label },
    { key: 'written_at', header: 'Written', render: (r: any) => r.written_at ? new Date(r.written_at).toLocaleDateString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'summary_md', header: 'Summary', render: (r: any) => (r.summary_md ?? '').slice(0, 120) },
    { key: 'wins', header: 'Top Wins', render: (r: any) => (r.top_three_wins_md ?? '').slice(0, 100) },
    { key: 'misses', header: 'Top Misses', render: (r: any) => (r.top_three_misses_md ?? '').slice(0, 100) },
    { key: 'takeaways', header: 'Takeaways', render: (r: any) => (r.founder_personal_takeaways_md ?? '').slice(0, 100) },
    { key: 'next_500', header: 'Next 500 Plan', render: (r: any) => (r.next_500_ship_plan_md ?? '').slice(0, 100) },
  ];

  const recentSignalColumns: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => r.milestone_label },
    { key: 'signal_type', header: 'Type', render: (r: any) => r.signal_type },
    { key: 'signal_md', header: 'Signal', render: (r: any) => (r.signal_md ?? '').slice(0, 160) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const topSignalColumns: Column<any>[] = [
    { key: 'signal_type', header: 'Signal Type', render: (r: any) => r.signal_type },
    { key: 'signal_count', header: 'Count', render: (r: any) => String(r.signal_count ?? 0) },
    { key: 'latest_at', header: 'Latest', render: (r: any) => r.latest_at ? new Date(r.latest_at).toLocaleString() : '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder 1200-Ship Reflection</h1>
        <p className="text-sm text-gray-600">Milestone retrospective. Capture wins, misses, personal takeaways, and the plan for the next 500 ships.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reflections</h2>
        <DataTable
          rows={reflections}
          columns={reflectionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Signals</h2>
        <DataTable
          rows={recentSignals}
          columns={recentSignalColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Signal Types</h2>
        <DataTable
          rows={topSignals}
          columns={topSignalColumns}
          rowKey={(r: any, i: number) => String(r.signal_type ?? i)}
        />
      </section>
    </div>
  );
}
