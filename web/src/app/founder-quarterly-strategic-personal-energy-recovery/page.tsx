import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Activity = {
  id: string;
  activity_name: string;
  category: string;
  hours_invested: number;
  energy_before_score: number;
  energy_after_score: number;
  energy_delta: number;
  correlation_with_output: number;
  commit_next_quarter: boolean;
  verdict: string;
  notes: string | null;
};

type Kpis = {
  total_activities: number;
  total_hours: number;
  avg_energy_delta: number;
  avg_correlation: number;
  commit_count: number;
  drop_count: number;
  double_down_count: number;
};

type CategoryRow = {
  category: string;
  activities: number;
  hours: number;
  avg_delta: number;
  avg_correlation: number;
};

type TopRow = {
  activity_name: string;
  category: string;
  correlation_with_output: number;
  energy_delta: number;
  hours_invested: number;
};

type DropRow = {
  activity_name: string;
  category: string;
  correlation_with_output: number;
  energy_delta: number;
  notes: string | null;
};

type WeeklyRow = {
  week_starting: string;
  activity_name: string;
  hours_this_week: number;
  energy_rating_end_of_week: number;
  output_units_shipped: number;
  consistency_flag: string;
  reflection_note: string | null;
};

type ConsistencyRow = {
  consistency_flag: string;
  weeks: number;
  total_hours: number;
  total_output: number;
  avg_energy: number;
};

type VerdictRow = {
  verdict: string;
  activities: number;
  hours: number;
  avg_correlation: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [acts, kpis, cats, tops, drops, weekly, consist, verdicts] = await Promise.all([
    supabase.rpc('f_r2865_energy_activities'),
    supabase.rpc('f_r2865_energy_kpis'),
    supabase.rpc('f_r2865_energy_by_category'),
    supabase.rpc('f_r2865_energy_top_double_down'),
    supabase.rpc('f_r2865_energy_drops'),
    supabase.rpc('f_r2865_energy_weekly_log'),
    supabase.rpc('f_r2865_energy_consistency_summary'),
    supabase.rpc('f_r2865_energy_quarter_verdict'),
  ]);

  const activities: Activity[] = (acts.data as Activity[]) ?? [];
  const k: Kpis | null = ((kpis.data as Kpis[]) ?? [])[0] ?? null;
  const categories: CategoryRow[] = (cats.data as CategoryRow[]) ?? [];
  const topRows: TopRow[] = (tops.data as TopRow[]) ?? [];
  const dropRows: DropRow[] = (drops.data as DropRow[]) ?? [];
  const weeklyRows: WeeklyRow[] = (weekly.data as WeeklyRow[]) ?? [];
  const consistency: ConsistencyRow[] = (consist.data as ConsistencyRow[]) ?? [];
  const verdictRows: VerdictRow[] = (verdicts.data as VerdictRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Quarterly Strategic Personal Energy Recovery</h1>
        <p className="text-sm text-gray-600">
          Activities × hours × energy delta × correlation × commit × verdict.
          Founder-only. Higher correlation values (closer to +1) =&gt; double down next quarter.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Activities tracked" value={k?.total_activities ?? 0} />
        <KpiCard label="Total hours invested" value={Number(k?.total_hours ?? 0).toFixed(1)} />
        <KpiCard label="Avg energy delta" value={Number(k?.avg_energy_delta ?? 0).toFixed(2)} />
        <KpiCard label="Avg correlation" value={Number(k?.avg_correlation ?? 0).toFixed(3)} />
        <KpiCard label="Committed next Q" value={k?.commit_count ?? 0} />
        <KpiCard label="Double-down" value={k?.double_down_count ?? 0} />
        <KpiCard label="Dropping" value={k?.drop_count ?? 0} />
        <KpiCard label="Net signal" value={Number(k?.avg_correlation ?? 0) >= 0.3 ? 'STRONG' : 'WEAK'} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All recovery activities</h2>
        <DataTable
          rows={activities}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'activity_name', header: 'Activity', render: (r: Activity) => r.activity_name },
            { key: 'category', header: 'Category', render: (r: Activity) => r.category },
            { key: 'hours_invested', header: 'Hours', render: (r: Activity) => Number(r.hours_invested).toFixed(1) },
            { key: 'energy_before_score', header: 'Before', render: (r: Activity) => r.energy_before_score },
            { key: 'energy_after_score', header: 'After', render: (r: Activity) => r.energy_after_score },
            { key: 'energy_delta', header: 'Delta', render: (r: Activity) => r.energy_delta },
            { key: 'correlation_with_output', header: 'Corr', render: (r: Activity) => Number(r.correlation_with_output).toFixed(3) },
            { key: 'commit_next_quarter', header: 'Commit', render: (r: Activity) => (r.commit_next_quarter ? 'YES' : 'no') },
            { key: 'verdict', header: 'Verdict', render: (r: Activity) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: Activity) => r.notes ?? '' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">By category</h2>
        <DataTable
          rows={categories}
          rowKey={(r, i) => String(r.category ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'category', header: 'Category', render: (r: CategoryRow) => r.category },
            { key: 'activities', header: 'Activities', render: (r: CategoryRow) => r.activities },
            { key: 'hours', header: 'Hours', render: (r: CategoryRow) => Number(r.hours).toFixed(1) },
            { key: 'avg_delta', header: 'Avg delta', render: (r: CategoryRow) => Number(r.avg_delta).toFixed(2) },
            { key: 'avg_correlation', header: 'Avg corr', render: (r: CategoryRow) => Number(r.avg_correlation).toFixed(3) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top double-downs (corr &gt;= 0.5)</h2>
        <DataTable
          rows={topRows}
          rowKey={(r, i) => String(r.activity_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'activity_name', header: 'Activity', render: (r: TopRow) => r.activity_name },
            { key: 'category', header: 'Category', render: (r: TopRow) => r.category },
            { key: 'correlation_with_output', header: 'Corr', render: (r: TopRow) => Number(r.correlation_with_output).toFixed(3) },
            { key: 'energy_delta', header: 'Delta', render: (r: TopRow) => r.energy_delta },
            { key: 'hours_invested', header: 'Hours', render: (r: TopRow) => Number(r.hours_invested).toFixed(1) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Drop & reduce list</h2>
        <DataTable
          rows={dropRows}
          rowKey={(r, i) => String(r.activity_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'activity_name', header: 'Activity', render: (r: DropRow) => r.activity_name },
            { key: 'category', header: 'Category', render: (r: DropRow) => r.category },
            { key: 'correlation_with_output', header: 'Corr', render: (r: DropRow) => Number(r.correlation_with_output).toFixed(3) },
            { key: 'energy_delta', header: 'Delta', render: (r: DropRow) => r.energy_delta },
            { key: 'notes', header: 'Notes', render: (r: DropRow) => r.notes ?? '' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Weekly log</h2>
        <DataTable
          rows={weeklyRows}
          rowKey={(r, i) => String((r.week_starting ?? '') + ':' + (r.activity_name ?? i))}
          emptyMessage="No data"
          columns={[
            { key: 'week_starting', header: 'Week', render: (r: WeeklyRow) => r.week_starting },
            { key: 'activity_name', header: 'Activity', render: (r: WeeklyRow) => r.activity_name },
            { key: 'hours_this_week', header: 'Hours', render: (r: WeeklyRow) => Number(r.hours_this_week).toFixed(1) },
            { key: 'energy_rating_end_of_week', header: 'Energy', render: (r: WeeklyRow) => r.energy_rating_end_of_week },
            { key: 'output_units_shipped', header: 'Output', render: (r: WeeklyRow) => r.output_units_shipped },
            { key: 'consistency_flag', header: 'Flag', render: (r: WeeklyRow) => r.consistency_flag },
            { key: 'reflection_note', header: 'Reflection', render: (r: WeeklyRow) => r.reflection_note ?? '' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Consistency vs output</h2>
        <DataTable
          rows={consistency}
          rowKey={(r, i) => String(r.consistency_flag ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'consistency_flag', header: 'Flag', render: (r: ConsistencyRow) => r.consistency_flag },
            { key: 'weeks', header: 'Weeks', render: (r: ConsistencyRow) => r.weeks },
            { key: 'total_hours', header: 'Hours', render: (r: ConsistencyRow) => Number(r.total_hours).toFixed(1) },
            { key: 'total_output', header: 'Output', render: (r: ConsistencyRow) => r.total_output },
            { key: 'avg_energy', header: 'Avg energy', render: (r: ConsistencyRow) => Number(r.avg_energy).toFixed(2) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Verdict roll-up</h2>
        <DataTable
          rows={verdictRows}
          rowKey={(r, i) => String(r.verdict ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'activities', header: 'Activities', render: (r: VerdictRow) => r.activities },
            { key: 'hours', header: 'Hours', render: (r: VerdictRow) => Number(r.hours).toFixed(1) },
            { key: 'avg_correlation', header: 'Avg corr', render: (r: VerdictRow) => Number(r.avg_correlation).toFixed(3) },
          ]}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}
