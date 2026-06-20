import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: any }) {
  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-zinc-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-zinc-900">{value ?? "—"}</div>
    </div>
  );
}

function fmtHrs(n: any) {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!isFinite(v)) return "—";
  return v.toFixed(1) + "h";
}

function fmtPct(n: any) {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!isFinite(v)) return "—";
  return (v >= 0 ? "+" : "") + v.toFixed(1) + "%";
}

function fmtDate(s: any) {
  if (!s) return "—";
  try { return new Date(s).toISOString().slice(0, 10); } catch { return String(s); }
}

export default async function FounderTimeTrackingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpiRes, weeklyRes, categoryRes, bottleneckRes, recentRes, dailyRes, targetsRes] = await Promise.all([
    supabase.rpc('founder_time_kpis'),
    supabase.rpc('founder_time_weekly_breakdown'),
    supabase.rpc('founder_time_category_summary'),
    supabase.rpc('founder_time_bottleneck_entries'),
    supabase.rpc('founder_time_recent_entries'),
    supabase.rpc('founder_time_daily_totals'),
    supabase.rpc('founder_time_targets_overview'),
  ]);

  const k: any = (kpiRes.data && kpiRes.data[0]) || {};
  const weekly: any[] = weeklyRes.data || [];
  const category: any[] = categoryRes.data || [];
  const bottleneck: any[] = bottleneckRes.data || [];
  const recent: any[] = recentRes.data || [];
  const daily: any[] = dailyRes.data || [];
  const targets: any[] = targetsRes.data || [];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'category', header: 'Category', render: (r: any) => <span className="font-mono text-xs uppercase">{r.category}</span> },
    { key: 'hours', header: 'Hours', render: (r: any) => fmtHrs(r.hours) },
    { key: 'target_hours', header: 'Target', render: (r: any) => fmtHrs(r.target_hours) },
    { key: 'variance_hours', header: 'Variance', render: (r: any) => fmtHrs(r.variance_hours) },
    { key: 'variance_pct', header: 'Var %', render: (r: any) => fmtPct(r.variance_pct) },
    { key: 'entry_count', header: 'Entries', render: (r: any) => r.entry_count ?? "—" },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => <span className="font-mono text-xs uppercase">{r.category}</span> },
    { key: 'hours_7d', header: 'Last 7d', render: (r: any) => fmtHrs(r.hours_7d) },
    { key: 'hours_30d', header: 'Last 30d', render: (r: any) => fmtHrs(r.hours_30d) },
    { key: 'hours_90d', header: 'Last 90d', render: (r: any) => fmtHrs(r.hours_90d) },
    { key: 'target_weekly', header: 'Target/wk', render: (r: any) => fmtHrs(r.target_weekly) },
    { key: 'bottleneck_hours', header: 'Bottleneck 30d', render: (r: any) => fmtHrs(r.bottleneck_hours) },
    { key: 'unplanned_hours', header: 'Unplanned 30d', render: (r: any) => fmtHrs(r.unplanned_hours) },
    { key: 'status', header: 'Status', render: (r: any) => {
      const s = r.status;
      const cls = s === 'overshoot' ? 'bg-red-100 text-red-700' : s === 'undershoot' ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700';
      return <span className={`rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{s ?? "—"}</span>;
    } },
  ];

  const bottleneckCols: Column<any>[] = [
    { key: 'entry_date', header: 'Date', render: (r: any) => fmtDate(r.entry_date) },
    { key: 'category', header: 'Category', render: (r: any) => <span className="font-mono text-xs uppercase">{r.category}</span> },
    { key: 'hours', header: 'Hours', render: (r: any) => fmtHrs(r.hours) },
    { key: 'energy_level', header: 'Energy', render: (r: any) => r.energy_level ?? "—" },
    { key: 'was_planned', header: 'Planned?', render: (r: any) => r.was_planned ? 'yes' : 'no' },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs text-zinc-600">{r.note ?? "—"}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'entry_date', header: 'Date', render: (r: any) => fmtDate(r.entry_date) },
    { key: 'category', header: 'Category', render: (r: any) => <span className="font-mono text-xs uppercase">{r.category}</span> },
    { key: 'hours', header: 'Hours', render: (r: any) => fmtHrs(r.hours) },
    { key: 'energy_level', header: 'Energy', render: (r: any) => r.energy_level ?? "—" },
    { key: 'is_bottleneck', header: 'Bottleneck', render: (r: any) => r.is_bottleneck ? 'yes' : 'no' },
    { key: 'was_planned', header: 'Planned', render: (r: any) => r.was_planned ? 'yes' : 'no' },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs text-zinc-600">{r.note ?? "—"}</span> },
  ];

  const dailyCols: Column<any>[] = [
    { key: 'entry_date', header: 'Date', render: (r: any) => fmtDate(r.entry_date) },
    { key: 'total_hours', header: 'Total', render: (r: any) => fmtHrs(r.total_hours) },
    { key: 'entry_count', header: 'Entries', render: (r: any) => r.entry_count ?? "—" },
    { key: 'bottleneck_hours', header: 'Bottleneck', render: (r: any) => fmtHrs(r.bottleneck_hours) },
    { key: 'drained_hours', header: 'Drained', render: (r: any) => fmtHrs(r.drained_hours) },
  ];

  const targetsCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => <span className="font-mono text-xs uppercase">{r.category}</span> },
    { key: 'target_weekly_hours', header: 'Target/wk', render: (r: any) => fmtHrs(r.target_weekly_hours) },
    { key: 'rationale', header: 'Rationale', render: (r: any) => <span className="text-xs text-zinc-600">{r.rationale ?? "—"}</span> },
    { key: 'updated_at', header: 'Updated', render: (r: any) => fmtDate(r.updated_at) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold text-zinc-900">Founder Time-Tracking Ledger</h1>
        <p className="mt-1 text-sm text-zinc-600">Where founder hours actually go vs intended allocation. Surfaces bottleneck categories and energy drains. r1478.</p>
      </header>

      <section className="mb-6 grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Hours last 7d" value={fmtHrs(k.total_hours_7d)} />
        <Kpi label="Hours last 30d" value={fmtHrs(k.total_hours_30d)} />
        <Kpi label="Hours last 90d" value={fmtHrs(k.total_hours_90d)} />
        <Kpi label="Entries 30d" value={k.total_entries_30d ?? "—"} />
        <Kpi label="Avg daily hours" value={fmtHrs(k.avg_daily_hours_30d)} />
        <Kpi label="Bottleneck hours 30d" value={fmtHrs(k.bottleneck_hours_30d)} />
        <Kpi label="Unplanned hours 30d" value={fmtHrs(k.unplanned_hours_30d)} />
        <Kpi label="Drained hours 30d" value={fmtHrs(k.drained_hours_30d)} />
        <Kpi label="Top category 30d" value={k.top_category_30d ?? "—"} />
        <Kpi label="Top cat hours" value={fmtHrs(k.top_category_hours_30d)} />
        <Kpi label="Bottom category 30d" value={k.bottom_category_30d ?? "—"} />
        <Kpi label="Bottom cat hours" value={fmtHrs(k.bottom_category_hours_30d)} />
        <Kpi label="Variance vs target" value={fmtPct(k.variance_vs_target_pct)} />
        <Kpi label="Cats overshooting" value={k.categories_overshooting ?? "—"} />
        <Kpi label="Cats undershooting" value={k.categories_undershooting ?? "—"} />
        <Kpi label="Days logged 30d" value={k.days_logged_30d ?? "—"} />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-900">Category summary (where bottleneck lives)</h2>
        <DataTable<any> columns={categoryCols} rows={category} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-900">Weekly breakdown vs target (12 weeks)</h2>
        <DataTable<any> columns={weeklyCols} rows={weekly} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-900">Bottleneck-flagged entries (60d)</h2>
        <DataTable<any> columns={bottleneckCols} rows={bottleneck} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-900">Recent entries</h2>
        <DataTable<any> columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-900">Daily totals (30d)</h2>
        <DataTable<any> columns={dailyCols} rows={daily} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-zinc-900">Weekly targets</h2>
        <DataTable<any> columns={targetsCols} rows={targets} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
