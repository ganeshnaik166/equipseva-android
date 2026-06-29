import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type DensitySummary = { density_band: string; hospital_count: number; total_visits: number; avg_density: number };
type TopDense = { hospital_code: string; hospital_name: string; city: string; visit_count: number; density_score: number; peak_weekday: string };
type CityRollup = { city: string; hospitals: number; total_visits: number; congested: number; avg_dwell: number };
type SlotStatus = { slot_status: string; slot_count: number; total_gain: number; avg_travel: number };
type EngBoard = { engineer_code: string; engineer_name: string; total_slots: number; approved_slots: number; total_gain: number; total_travel: number };
type PriorityConflict = { priority: string; slot_count: number; conflicts: number; avg_gain: number };
type DenseMatch = { hospital_code: string; hospital_name: string; density_score: number; scheduled_slots: number; total_gain: number; congestion_flag: boolean };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [a, b, c, d, e, f, g] = await Promise.all([
    supabase.rpc('r2976_density_summary'),
    supabase.rpc('r2976_top_dense_hospitals'),
    supabase.rpc('r2976_city_rollup'),
    supabase.rpc('r2976_schedule_status_breakdown'),
    supabase.rpc('r2976_engineer_optimization_board'),
    supabase.rpc('r2976_priority_conflicts'),
    supabase.rpc('r2976_dense_hospital_schedule_match'),
  ]);

  const density: DensitySummary[] = (a.data as DensitySummary[]) ?? [];
  const top: TopDense[] = (b.data as TopDense[]) ?? [];
  const city: CityRollup[] = (c.data as CityRollup[]) ?? [];
  const status: SlotStatus[] = (d.data as SlotStatus[]) ?? [];
  const engBoard: EngBoard[] = (e.data as EngBoard[]) ?? [];
  const priority: PriorityConflict[] = (f.data as PriorityConflict[]) ?? [];
  const match: DenseMatch[] = (g.data as DenseMatch[]) ?? [];

  const densityCols: Column<DensitySummary>[] = [
    { key: 'density_band', header: 'Band' },
    { key: 'hospital_count', header: 'Hospitals' },
    { key: 'total_visits', header: 'Total Visits' },
    { key: 'avg_density', header: 'Avg Density' },
  ];

  const topCols: Column<TopDense>[] = [
    { key: 'hospital_code', header: 'Code' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'city', header: 'City' },
    { key: 'visit_count', header: 'Visits' },
    { key: 'density_score', header: 'Density' },
    { key: 'peak_weekday', header: 'Peak Day' },
  ];

  const cityCols: Column<CityRollup>[] = [
    { key: 'city', header: 'City' },
    { key: 'hospitals', header: 'Hospitals' },
    { key: 'total_visits', header: 'Visits' },
    { key: 'congested', header: 'Congested' },
    { key: 'avg_dwell', header: 'Avg Dwell (min)' },
  ];

  const statusCols: Column<SlotStatus>[] = [
    { key: 'slot_status', header: 'Status' },
    { key: 'slot_count', header: 'Slots' },
    { key: 'total_gain', header: 'Total Gain (min)' },
    { key: 'avg_travel', header: 'Avg Travel (km)' },
  ];

  const engCols: Column<EngBoard>[] = [
    { key: 'engineer_code', header: 'Code' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_slots', header: 'Slots' },
    { key: 'approved_slots', header: 'Approved' },
    { key: 'total_gain', header: 'Gain (min)' },
    { key: 'total_travel', header: 'Travel (km)' },
  ];

  const priorityCols: Column<PriorityConflict>[] = [
    { key: 'priority', header: 'Priority' },
    { key: 'slot_count', header: 'Slots' },
    { key: 'conflicts', header: 'Conflicts' },
    { key: 'avg_gain', header: 'Avg Gain' },
  ];

  const matchCols: Column<DenseMatch>[] = [
    { key: 'hospital_code', header: 'Code' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'density_score', header: 'Density' },
    { key: 'scheduled_slots', header: 'Slots' },
    { key: 'total_gain', header: 'Gain (min)' },
    { key: 'congestion_flag', header: 'Congested', render: (r: DenseMatch) => r.congestion_flag ? 'yes' : 'no' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Hospital Foot-Traffic Density &amp; Visit-Schedule Optimization</h1>
        <p className="text-sm text-gray-600">Round r2976 — density bands &gt;= moderate flagged for schedule re-routing.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Density band summary</h2>
        <DataTable rows={density} columns={densityCols} emptyMessage="No density data" rowKey={(r, i) => String((r as DensitySummary).density_band ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top dense hospitals</h2>
        <DataTable rows={top} columns={topCols} emptyMessage="No hospitals" rowKey={(r, i) => String((r as TopDense).hospital_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City rollup</h2>
        <DataTable rows={city} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String((r as CityRollup).city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Schedule status breakdown</h2>
        <DataTable rows={status} columns={statusCols} emptyMessage="No slots" rowKey={(r, i) => String((r as SlotStatus).slot_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer optimization board</h2>
        <DataTable rows={engBoard} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as EngBoard).engineer_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Priority & conflicts</h2>
        <DataTable rows={priority} columns={priorityCols} emptyMessage="No priorities" rowKey={(r, i) => String((r as PriorityConflict).priority ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dense hospital schedule match</h2>
        <DataTable rows={match} columns={matchCols} emptyMessage="No matches" rowKey={(r, i) => String((r as DenseMatch).hospital_code ?? i)} />
      </section>
    </div>
  );
}
