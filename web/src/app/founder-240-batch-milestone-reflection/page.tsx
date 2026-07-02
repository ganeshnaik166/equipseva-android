import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [eraRes, winsRes, lessonsRes, kpiRes, commitRes, catRes, themeRes] = await Promise.all([
    sb.rpc('founder_240_retro_era_summary_r2265'),
    sb.rpc('founder_240_retro_biggest_wins_r2265'),
    sb.rpc('founder_240_retro_lessons_r2265'),
    sb.rpc('founder_240_retro_kpis_r2265'),
    sb.rpc('founder_240_retro_commitments_r2265'),
    sb.rpc('founder_240_retro_commitment_categories_r2265'),
    sb.rpc('founder_240_retro_theme_distribution_r2265'),
  ]);

  const eras = (eraRes.data ?? []) as any[];
  const wins = (winsRes.data ?? []) as any[];
  const lessons = (lessonsRes.data ?? []) as any[];
  const kpis = ((kpiRes.data ?? [])[0] ?? {}) as any;
  const commitments = (commitRes.data ?? []) as any[];
  const categories = (catRes.data ?? []) as any[];
  const themes = (themeRes.data ?? []) as any[];

  const eraCols: Column<any>[] = [
    { key: 'era_label', header: 'Era', render: (r) => r.era_label },
    { key: 'theme', header: 'Theme', render: (r) => r.theme },
    { key: 'batch_range', header: 'Batches', render: (r) => r.batch_range },
    { key: 'ships_in_range', header: 'Ships', render: (r) => r.ships_in_range },
    { key: 'heavy_ships_in_range', header: 'Heavy', render: (r) => r.heavy_ships_in_range },
    { key: 'velocity_score', header: 'Velocity', render: (r) => r.velocity_score },
    { key: 'quality_score', header: 'Quality', render: (r) => r.quality_score },
  ];

  const winCols: Column<any>[] = [
    { key: 'era_label', header: 'Era', render: (r) => r.era_label },
    { key: 'biggest_win', header: 'Biggest win', render: (r) => r.biggest_win },
    { key: 'quality_score', header: 'Quality', render: (r) => r.quality_score },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'era_label', header: 'Era', render: (r) => r.era_label },
    { key: 'biggest_miss', header: 'Biggest miss', render: (r) => r.biggest_miss },
    { key: 'what_we_would_do_differently', header: 'Would do differently', render: (r) => r.what_we_would_do_differently },
  ];

  const commitCols: Column<any>[] = [
    { key: 'priority_rank', header: 'Rank', render: (r) => r.priority_rank },
    { key: 'commitment_title', header: 'Commitment', render: (r) => r.commitment_title },
    { key: 'commitment_category', header: 'Category', render: (r) => r.commitment_category },
    { key: 'current_state', header: 'Now', render: (r) => r.current_state },
    { key: 'target_state', header: 'Target', render: (r) => r.target_state },
    { key: 'target_batch', header: 'By batch', render: (r) => r.target_batch },
    { key: 'effort_estimate', header: 'Effort', render: (r) => r.effort_estimate },
    { key: 'is_kept', header: 'Kept?', render: (r) => (r.is_kept ? 'yes' : 'no') },
  ];

  const catCols: Column<any>[] = [
    { key: 'commitment_category', header: 'Category', render: (r) => r.commitment_category },
    { key: 'commitment_count', header: 'Count', render: (r) => r.commitment_count },
    { key: 'avg_priority', header: 'Avg priority (lower = hotter)', render: (r) => r.avg_priority },
    { key: 'kept_count', header: 'Kept', render: (r) => r.kept_count },
  ];

  const themeCols: Column<any>[] = [
    { key: 'theme', header: 'Theme', render: (r) => r.theme },
    { key: 'era_count', header: 'Eras', render: (r) => r.era_count },
    { key: 'total_ships', header: 'Ships', render: (r) => r.total_ships },
    { key: 'total_heavy_ships', header: 'Heavy ships', render: (r) => r.total_heavy_ships },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">240-batch milestone reflection</h1>
        <p className="text-sm text-neutral-600">
          What changed across 240 batches, biggest wins & misses, and the next-240 plan.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <Kpi label="Total ships" value={kpis.total_ships ?? 0} />
        <Kpi label="Heavy ships" value={kpis.total_heavy_ships ?? 0} />
        <Kpi label="Eras" value={kpis.eras_count ?? 0} />
        <Kpi label="Avg velocity" value={kpis.avg_velocity ?? 0} />
        <Kpi label="Avg quality" value={kpis.avg_quality ?? 0} />
        <Kpi label="Heavy %" value={kpis.heavy_pct ?? 0} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Era summary (8 eras &gt;= 30 batches each)</h2>
        <DataTable columns={eraCols} rows={eras} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Biggest wins (quality &gt;= 80 surfaces first)</h2>
        <DataTable columns={winCols} rows={wins} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Lessons learned & what we would do differently</h2>
        <DataTable columns={lessonCols} rows={lessons} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Next-240 commitments (priority 1 = hottest)</h2>
        <DataTable columns={commitCols} rows={commitments} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Commitments by category</h2>
        <DataTable columns={catCols} rows={categories} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Theme distribution across 240 batches</h2>
        <DataTable columns={themeCols} rows={themes} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-neutral-200 p-3">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  );
}
