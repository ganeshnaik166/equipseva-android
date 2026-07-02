import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [benchRes, coachingRes, slowRes, fastRes, catRes] = await Promise.all([
    sb.rpc('list_benchmarks_r1808', { p_limit: 200 }),
    sb.rpc('list_coaching_r1808', { p_limit: 200 }),
    sb.rpc('slowest_engineers_r1808', { p_limit: 20 }),
    sb.rpc('fastest_engineers_r1808', { p_limit: 20 }),
    sb.rpc('category_average_speed_r1808'),
  ]);

  const benchmarks: any[] = (benchRes.data as any[]) ?? [];
  const coaching: any[] = (coachingRes.data as any[]) ?? [];
  const slowest: any[] = (slowRes.data as any[]) ?? [];
  const fastest: any[] = (fastRes.data as any[]) ?? [];
  const categories: any[] = (catRes.data as any[]) ?? [];

  const errs = [benchRes.error, coachingRes.error, slowRes.error, fastRes.error, catRes.error].filter(Boolean);

  const benchCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id}</span> },
    { key: 'category', header: 'Category', render: (r: any) => <span>{r.equipment_category}</span> },
    { key: 'avg', header: 'Avg min', render: (r: any) => <span>{r.avg_repair_minutes}</span> },
    { key: 'med', header: 'Peer median', render: (r: any) => <span>{r.peer_median_minutes}</span> },
    { key: 'dev', header: 'Deviation %', render: (r: any) => <span>{Number(r.deviation_pct ?? 0).toFixed(2)}%</span> },
    { key: 'sample', header: 'Sample', render: (r: any) => <span>{r.sample_size}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span> },
    { key: 'recorded', header: 'Recorded', render: (r: any) => <span>{r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—'}</span> },
  ];

  const coachCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? '—'}</span> },
    { key: 'category', header: 'Category', render: (r: any) => <span>{r.equipment_category ?? '—'}</span> },
    { key: 'action', header: 'Action', render: (r: any) => <span>{r.coaching_action}</span> },
    { key: 'by', header: 'By', render: (r: any) => <span>{r.by_email ?? '—'}</span> },
    { key: 'taken', header: 'Taken', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : '—'}</span> },
    { key: 'follow', header: 'Follow-up', render: (r: any) => <span>{r.follow_up_date ?? '—'}</span> },
  ];

  const slowCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id}</span> },
    { key: 'dev', header: 'Avg deviation %', render: (r: any) => <span>{Number(r.avg_deviation_pct ?? 0).toFixed(2)}%</span> },
    { key: 'bench', header: 'Benchmarks', render: (r: any) => <span>{r.benchmark_count}</span> },
    { key: 'crit', header: 'Critically slow', render: (r: any) => <span>{r.critical_count}</span> },
  ];

  const fastCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id}</span> },
    { key: 'dev', header: 'Avg deviation %', render: (r: any) => <span>{Number(r.avg_deviation_pct ?? 0).toFixed(2)}%</span> },
    { key: 'bench', header: 'Benchmarks', render: (r: any) => <span>{r.benchmark_count}</span> },
    { key: 'faster', header: 'Faster count', render: (r: any) => <span>{r.faster_count}</span> },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => <span>{r.equipment_category}</span> },
    { key: 'avg', header: 'Avg minutes', render: (r: any) => <span>{Number(r.category_avg_minutes ?? 0).toFixed(2)}</span> },
    { key: 'med', header: 'Median minutes', render: (r: any) => <span>{Number(r.category_median_minutes ?? 0).toFixed(2)}</span> },
    { key: 'engineers', header: 'Engineers', render: (r: any) => <span>{r.engineer_count}</span> },
    { key: 'samples', header: 'Samples', render: (r: any) => <span>{r.total_samples}</span> },
  ];

  return (
    <div className="space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Repair Time Benchmark</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Repair completion time vs peer median per equipment category. Engineers &gt;10% slower than peer median get flagged; &gt;50% triggers critically_slow status.
        </p>
      </header>

      {errs.length > 0 && (
        <div className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">
          {errs.map((e: any, i: number) => (
            <div key={i}>{e?.message ?? String(e)}</div>
          ))}
        </div>
      )}

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Benchmarks</h2>
        <DataTable
          rows={benchmarks}
          columns={benchCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No benchmarks recorded yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Slowest engineers</h2>
        <DataTable
          rows={slowest}
          columns={slowCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
          emptyMessage="No data."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Fastest engineers</h2>
        <DataTable
          rows={fastest}
          columns={fastCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
          emptyMessage="No data."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Category average speed</h2>
        <DataTable
          rows={categories}
          columns={catCols}
          rowKey={(r: any, i: number) => String(r.equipment_category ?? i)}
          emptyMessage="No category data."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Coaching log</h2>
        <DataTable
          rows={coaching}
          columns={coachCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No coaching actions logged."
        />
      </section>
    </div>
  );
}
