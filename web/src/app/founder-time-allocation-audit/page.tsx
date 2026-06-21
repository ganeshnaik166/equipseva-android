import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Allocation = {
  id: string;
  week_start: string;
  sales_hours: number;
  eng_hours: number;
  ops_hours: number;
  admin_hours: number;
  personal_hours: number;
  total_hours: number;
  recorded_at: string;
};

type Target = {
  category: string;
  target_pct: number;
  set_at: string;
};

type VsTarget = {
  category: string;
  actual_pct: number;
  target_pct: number;
  delta_pct: number;
};

type MonthlyTrend = {
  month_start: string;
  sales_hours: number;
  eng_hours: number;
  ops_hours: number;
  admin_hours: number;
  personal_hours: number;
  total_hours: number;
};

type CategorySummary = {
  category: string;
  total_hours: number;
  avg_weekly_hours: number;
  weeks_recorded: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [allocsRes, targetsRes, vsRes, trendRes, summaryRes] = await Promise.all([
    sb.rpc('r1678_list_allocations', { p_limit: 26 }),
    sb.rpc('r1678_list_targets'),
    sb.rpc('r1678_current_vs_target'),
    sb.rpc('r1678_monthly_trend'),
    sb.rpc('r1678_category_summary'),
  ]);

  const allocs: Allocation[] = (allocsRes.data ?? []) as Allocation[];
  const targets: Target[] = (targetsRes.data ?? []) as Target[];
  const vs: VsTarget[] = (vsRes.data ?? []) as VsTarget[];
  const trend: MonthlyTrend[] = (trendRes.data ?? []) as MonthlyTrend[];
  const summary: CategorySummary[] = (summaryRes.data ?? []) as CategorySummary[];

  const totalWeeks = allocs.length;
  const latestWeekTotal = allocs[0]?.total_hours ?? 0;
  const targetsSet = targets.length;
  const offTrack = vs.filter((v) => Math.abs(Number(v.delta_pct)) > 5).length;

  const allocCols: Column<Allocation>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '—') },
    { key: 'sales_hours', header: 'Sales', render: (r: any) => String(r.sales_hours ?? '—') },
    { key: 'eng_hours', header: 'Eng', render: (r: any) => String(r.eng_hours ?? '—') },
    { key: 'ops_hours', header: 'Ops', render: (r: any) => String(r.ops_hours ?? '—') },
    { key: 'admin_hours', header: 'Admin', render: (r: any) => String(r.admin_hours ?? '—') },
    { key: 'personal_hours', header: 'Personal', render: (r: any) => String(r.personal_hours ?? '—') },
    { key: 'total_hours', header: 'Total', render: (r: any) => String(r.total_hours ?? '—') },
  ];

  const vsCols: Column<VsTarget>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '—') },
    { key: 'actual_pct', header: 'Actual %', render: (r: any) => String(r.actual_pct ?? '—') },
    { key: 'target_pct', header: 'Target %', render: (r: any) => String(r.target_pct ?? '—') },
    { key: 'delta_pct', header: 'Delta %', render: (r: any) => String(r.delta_pct ?? '—') },
  ];

  const trendCols: Column<MonthlyTrend>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '—') },
    { key: 'sales_hours', header: 'Sales h', render: (r: any) => String(r.sales_hours ?? '—') },
    { key: 'eng_hours', header: 'Eng h', render: (r: any) => String(r.eng_hours ?? '—') },
    { key: 'ops_hours', header: 'Ops h', render: (r: any) => String(r.ops_hours ?? '—') },
    { key: 'admin_hours', header: 'Admin h', render: (r: any) => String(r.admin_hours ?? '—') },
    { key: 'personal_hours', header: 'Personal h', render: (r: any) => String(r.personal_hours ?? '—') },
    { key: 'total_hours', header: 'Total h', render: (r: any) => String(r.total_hours ?? '—') },
  ];

  const summaryCols: Column<CategorySummary>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '—') },
    { key: 'total_hours', header: 'Total Hours', render: (r: any) => String(r.total_hours ?? '—') },
    { key: 'avg_weekly_hours', header: 'Avg / Week', render: (r: any) => String(r.avg_weekly_hours ?? '—') },
    { key: 'weeks_recorded', header: 'Weeks', render: (r: any) => String(r.weeks_recorded ?? '—') },
  ];

  const targetCols: Column<Target>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '—') },
    { key: 'target_pct', header: 'Target %', render: (r: any) => String(r.target_pct ?? '—') },
    { key: 'set_at', header: 'Set At', render: (r: any) => String(r.set_at ?? '—') },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 600 }}>Founder Time Allocation Audit</h1>
        <p style={{ color: '#666' }}>Weekly hours per category vs targets — r1678</p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Weeks Recorded</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalWeeks}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Latest Week Total Hours</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{Number(latestWeekTotal).toFixed(1)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Targets Set</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{targetsSet} / 5</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ color: '#666', fontSize: 12 }}>Off-Track Categories (&gt;5%)</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: offTrack > 0 ? '#dc2626' : '#16a34a' }}>
            {offTrack}
          </div>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly Allocations (last 26 weeks)</h2>
        <DataTable
          rows={allocs}
          columns={allocCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Current vs Target (last 28 days)</h2>
        <DataTable
          rows={vs}
          columns={vsCols}
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Action Queue — Categories Needing Reallocation</h2>
        <DataTable
          rows={vs.filter((v) => Math.abs(Number(v.delta_pct)) > 5)}
          columns={vsCols}
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          rowKey={(r, i) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Category Summary (all-time)</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Targets</h2>
        <DataTable
          rows={targets}
          columns={targetCols}
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>
    </div>
  );
}
