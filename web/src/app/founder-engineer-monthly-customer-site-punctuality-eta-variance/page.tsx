import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MonthlyRow = { engineer_code: string; month_label: string; total_visits: number; punctuality_pct: number; variance_minutes: number; tier: string };
type TopRow = { engineer_code: string; punctuality_pct: number; on_time_visits: number; total_visits: number };
type LateRow = { engineer_code: string; late_visits: number; variance_minutes: number; punctuality_pct: number };
type TierRow = { tier: string; engineer_count: number; avg_variance: number; avg_punctuality: number };
type VisitRow = { engineer_code: string; hospital_name: string; city: string; scheduled_at: string; variance_minutes: number; status: string; customer_rating: number };
type LateVisitRow = { engineer_code: string; hospital_name: string; variance_minutes: number; customer_rating: number; notes: string };
type KpiRow = { total_engineers: number; avg_punctuality: number; avg_variance: number; total_visits: number; late_visits_total: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [summary, top, late, tier, recent, late30, kpis] = await Promise.all([
    supabase.rpc('rpc_r2902_monthly_summary'),
    supabase.rpc('rpc_r2902_top_punctual'),
    supabase.rpc('rpc_r2902_chronic_late'),
    supabase.rpc('rpc_r2902_variance_by_tier'),
    supabase.rpc('rpc_r2902_recent_visits'),
    supabase.rpc('rpc_r2902_late_visits_30plus'),
    supabase.rpc('rpc_r2902_kpis'),
  ]);

  const summaryRows: MonthlyRow[] = summary.data ?? [];
  const topRows: TopRow[] = top.data ?? [];
  const lateRows: LateRow[] = late.data ?? [];
  const tierRows: TierRow[] = tier.data ?? [];
  const recentRows: VisitRow[] = recent.data ?? [];
  const late30Rows: LateVisitRow[] = late30.data ?? [];
  const k: KpiRow = (kpis.data ?? [{}])[0] ?? {} as KpiRow;

  const summaryCols: Column<MonthlyRow>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'month_label', header: 'Month' },
    { key: 'total_visits', header: 'Visits' },
    { key: 'punctuality_pct', header: 'Punctuality %', render: (r) => `${r.punctuality_pct}%` },
    { key: 'variance_minutes', header: 'Variance (min)' },
    { key: 'tier', header: 'Tier' },
  ];
  const topCols: Column<TopRow>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'punctuality_pct', header: 'Punctuality %', render: (r) => `${r.punctuality_pct}%` },
    { key: 'on_time_visits', header: 'On-time' },
    { key: 'total_visits', header: 'Total' },
  ];
  const lateCols: Column<LateRow>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'late_visits', header: 'Late visits' },
    { key: 'variance_minutes', header: 'Avg variance' },
    { key: 'punctuality_pct', header: 'Punctuality %', render: (r) => `${r.punctuality_pct}%` },
  ];
  const tierCols: Column<TierRow>[] = [
    { key: 'tier', header: 'Tier' },
    { key: 'engineer_count', header: 'Engineers' },
    { key: 'avg_variance', header: 'Avg variance' },
    { key: 'avg_punctuality', header: 'Avg punctuality %' },
  ];
  const recentCols: Column<VisitRow>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'city', header: 'City' },
    { key: 'scheduled_at', header: 'Scheduled' },
    { key: 'variance_minutes', header: 'Variance' },
    { key: 'status', header: 'Status' },
    { key: 'customer_rating', header: 'Rating' },
  ];
  const late30Cols: Column<LateVisitRow>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'variance_minutes', header: 'Variance (min)' },
    { key: 'customer_rating', header: 'Rating' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Site Punctuality & ETA-vs-Actual Variance</h1>
        <p className="text-gray-600">Round r2902 · Batch 400 milestone · Field-team punctuality & ETA accuracy across hospital site visits.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded border p-4"><div className="text-xs text-gray-500">Engineers</div><div className="text-2xl font-semibold">{k.total_engineers ?? 0}</div></div>
        <div className="rounded border p-4"><div className="text-xs text-gray-500">Avg punctuality %</div><div className="text-2xl font-semibold">{k.avg_punctuality ?? 0}%</div></div>
        <div className="rounded border p-4"><div className="text-xs text-gray-500">Avg variance (min)</div><div className="text-2xl font-semibold">{k.avg_variance ?? 0}</div></div>
        <div className="rounded border p-4"><div className="text-xs text-gray-500">Total visits</div><div className="text-2xl font-semibold">{k.total_visits ?? 0}</div></div>
        <div className="rounded border p-4"><div className="text-xs text-gray-500">Late visits</div><div className="text-2xl font-semibold">{k.late_visits_total ?? 0}</div></div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly summary — punctuality & variance per engineer</h2>
        <DataTable rows={summaryRows} columns={summaryCols} emptyMessage="No monthly summary." rowKey={(r,i)=>String((r as MonthlyRow).engineer_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top 5 punctual engineers</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No top performers." rowKey={(r,i)=>String((r as TopRow).engineer_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chronic late engineers (&lt; 80%)</h2>
        <DataTable rows={lateRows} columns={lateCols} emptyMessage="No chronic late engineers." rowKey={(r,i)=>String((r as LateRow).engineer_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Variance by tier</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No tier data." rowKey={(r,i)=>String((r as TierRow).tier ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent site visits</h2>
        <DataTable rows={recentRows} columns={recentCols} emptyMessage="No recent visits." rowKey={(r,i)=>String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severely late visits (&gt;= 25 min variance)</h2>
        <DataTable rows={late30Rows} columns={late30Cols} emptyMessage="No severely late visits." rowKey={(r,i)=>String(i)} />
      </section>
    </div>
  );
}
