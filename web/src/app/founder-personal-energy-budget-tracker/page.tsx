import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalEnergyBudgetTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    todayRes,
    recentRes,
    categoryRes,
    dailyRes,
    drainRes,
    reflectionsRes,
    rollingRes,
  ] = await Promise.all([
    supabase.rpc('founder_energy_today_r2357'),
    supabase.rpc('founder_energy_recent_spend_r2357'),
    supabase.rpc('founder_energy_category_breakdown_r2357'),
    supabase.rpc('founder_energy_daily_totals_r2357'),
    supabase.rpc('founder_energy_drain_distribution_r2357'),
    supabase.rpc('founder_energy_reflections_r2357'),
    supabase.rpc('founder_energy_rolling_stats_r2357'),
  ]);

  const today = (todayRes.data ?? [])[0] ?? null;
  const recent = recentRes.data ?? [];
  const categories = categoryRes.data ?? [];
  const daily = dailyRes.data ?? [];
  const drain = drainRes.data ?? [];
  const reflections = reflectionsRes.data ?? [];
  const rolling = (rollingRes.data ?? [])[0] ?? null;

  const recentCols: Column<any>[] = [
    { key: 'spend_date', header: 'Date', render: (r) => r.spend_date },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'energy_units', header: 'Units', render: (r) => r.energy_units },
    { key: 'duration_minutes', header: 'Minutes', render: (r) => r.duration_minutes },
    { key: 'perceived_drain', header: 'Drain', render: (r) => r.perceived_drain },
    { key: 'note', header: 'Note', render: (r) => r.note ?? '—' },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'total_units', header: 'Units (7d)', render: (r) => r.total_units },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'entries', header: 'Entries', render: (r) => r.entries },
    { key: 'avg_units', header: 'Avg/Entry', render: (r) => r.avg_units },
    { key: 'high_drain_pct', header: 'High-drain %', render: (r) => `${r.high_drain_pct ?? 0}%` },
  ];

  const dailyCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r) => r.day },
    { key: 'total_spent', header: 'Spent', render: (r) => r.total_spent },
    { key: 'daily_budget', header: 'Budget', render: (r) => r.daily_budget },
    { key: 'surplus_deficit', header: 'Surplus/Deficit', render: (r) => r.surplus_deficit },
    { key: 'entries', header: 'Entries', render: (r) => r.entries },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const drainCols: Column<any>[] = [
    { key: 'perceived_drain', header: 'Drain Level', render: (r) => r.perceived_drain },
    { key: 'entries', header: 'Entries', render: (r) => r.entries },
    { key: 'total_units', header: 'Total Units', render: (r) => r.total_units },
    { key: 'pct_of_total', header: '% of Total', render: (r) => `${r.pct_of_total ?? 0}%` },
  ];

  const reflectionCols: Column<any>[] = [
    { key: 'budget_date', header: 'Date', render: (r) => r.budget_date },
    { key: 'daily_budget_units', header: 'Budget', render: (r) => r.daily_budget_units },
    { key: 'surplus_deficit', header: 'Net', render: (r) => r.surplus_deficit },
    { key: 'reflection', header: 'Reflection', render: (r) => r.reflection ?? '—' },
    { key: 'recovery_planned', header: 'Recovery', render: (r) => r.recovery_planned ?? '—' },
    { key: 'closed_at', header: 'Closed', render: (r) => r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Personal Energy Budget Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Daily energy spend across categories & surplus/deficit reflection log.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Today Budget</div>
          <div className="text-xl font-semibold">{today?.daily_budget_units ?? 100}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Spent Today</div>
          <div className="text-xl font-semibold">{today?.total_spent ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Surplus / Deficit</div>
          <div className={`text-xl font-semibold ${(today?.surplus_deficit ?? 0) < 0 ? 'text-red-600' : 'text-green-600'}`}>
            {today?.surplus_deficit ?? 0}
          </div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Entries Today</div>
          <div className="text-xl font-semibold">{today?.entries_logged ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Top Category</div>
          <div className="text-xl font-semibold">{today?.top_category ?? '—'}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">7d Total</div>
          <div className="text-lg font-semibold">{rolling?.total_units ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">Avg Daily (7d)</div>
          <div className="text-lg font-semibold">{rolling?.avg_daily ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">Days in Deficit</div>
          <div className="text-lg font-semibold">{rolling?.days_in_deficit ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">Days Logged</div>
          <div className="text-lg font-semibold">{rolling?.days_logged ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">Highest Day</div>
          <div className="text-sm font-semibold">
            {rolling?.highest_day ?? '—'} ({rolling?.highest_units ?? 0})
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Spend Entries (14d)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          emptyMessage="No energy spend logged yet."
          rowKey={(r) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category Breakdown (7d)</h2>
        <DataTable
          rows={categories}
          columns={catCols}
          emptyMessage="No category data."
          rowKey={(r) => r.category}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Daily Totals (14d)</h2>
        <DataTable
          rows={daily}
          columns={dailyCols}
          emptyMessage="No daily totals."
          rowKey={(r) => r.day}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Drain Distribution (7d)</h2>
        <DataTable
          rows={drain}
          columns={drainCols}
          emptyMessage="No drain data."
          rowKey={(r) => r.perceived_drain}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reflections (closed days)</h2>
        <DataTable
          rows={reflections}
          columns={reflectionCols}
          emptyMessage="No closed reflections yet."
          rowKey={(r) => r.budget_date}
        />
      </section>
    </div>
  );
}
