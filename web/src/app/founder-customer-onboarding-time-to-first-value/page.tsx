import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerOnboardingTimeToFirstValuePage() {
  const supabase = await getSupabaseServerClient();

  const [
    metricsRes,
    actionsRes,
    stuckRes,
    bottleneckRes,
    northStarRes,
    trendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_first_value_r2512'),
    supabase.rpc('list_action_log_r2512'),
    supabase.rpc('stuck_hospitals_focus_r2512'),
    supabase.rpc('bottleneck_breakdown_r2512'),
    supabase.rpc('north_star_distribution_r2512'),
    supabase.rpc('monthly_first_value_trend_r2512'),
    supabase.rpc('owner_load_r2512'),
  ]);

  const metrics = (metricsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const stuck = (stuckRes.data ?? []) as any[];
  const bottleneck = (bottleneckRes.data ?? []) as any[];
  const northStar = (northStarRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const fmt = (v: any) => (v == null ? '—' : new Date(v).toLocaleDateString());
  const num = (v: any) => (v == null ? '—' : String(v));

  const metricsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'signup_at', header: 'Signup', render: (r: any) => fmt(r.signup_at) },
    { key: 'days_to_first_pm', header: 'Days => PM', render: (r: any) => num(r.days_to_first_pm) },
    { key: 'days_to_first_repair', header: 'Days => Repair', render: (r: any) => num(r.days_to_first_repair) },
    { key: 'days_to_first_amc', header: 'Days => AMC', render: (r: any) => num(r.days_to_first_amc) },
    { key: 'bottleneck_kind', header: 'Bottleneck', render: (r: any) => r.bottleneck_kind },
    { key: 'north_star_score', header: 'North-Star', render: (r: any) => `${r.north_star_score}/100` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => fmt(r.action_at) },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmt(r.follow_up_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'days_since_signup', header: 'Days Since Signup', render: (r: any) => num(r.days_since_signup) },
    { key: 'bottleneck_kind', header: 'Bottleneck', render: (r: any) => r.bottleneck_kind },
    { key: 'north_star_score', header: 'North-Star', render: (r: any) => `${r.north_star_score}/100` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const bottleneckCols: Column<any>[] = [
    { key: 'bottleneck_kind', header: 'Bottleneck', render: (r: any) => r.bottleneck_kind },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => num(r.hospital_count) },
    { key: 'avg_north_star', header: 'Avg North-Star', render: (r: any) => num(r.avg_north_star) },
    { key: 'avg_days_to_pm', header: 'Avg Days => PM', render: (r: any) => num(r.avg_days_to_pm) },
  ];

  const northStarCols: Column<any>[] = [
    { key: 'bucket', header: 'Score Bucket', render: (r: any) => r.bucket },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => num(r.hospital_count) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmt(r.month_start) },
    { key: 'signups', header: 'Signups', render: (r: any) => num(r.signups) },
    { key: 'first_pm_count', header: 'First PM', render: (r: any) => num(r.first_pm_count) },
    { key: 'first_repair_count', header: 'First Repair', render: (r: any) => num(r.first_repair_count) },
    { key: 'first_amc_count', header: 'First AMC', render: (r: any) => num(r.first_amc_count) },
    { key: 'avg_days_to_pm', header: 'Avg Days => PM', render: (r: any) => num(r.avg_days_to_pm) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => num(r.hospital_count) },
    { key: 'stuck_count', header: 'Stuck', render: (r: any) => num(r.stuck_count) },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => num(r.open_actions) },
    { key: 'avg_north_star', header: 'Avg North-Star', render: (r: any) => num(r.avg_north_star) },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 px-4 py-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Onboarding & Time-to-First-Value</h1>
        <p className="mt-1 text-sm text-gray-600">
          Hospital signup => first PM => first repair => first AMC. Track bottlenecks &
          north-star score.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Hospitals stuck or below score 40</h2>
        <DataTable
          rows={stuck}
          columns={stuckCols}
          emptyMessage="No stuck hospitals."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">First-value metrics</h2>
        <DataTable
          rows={metrics}
          columns={metricsCols}
          emptyMessage="No metrics yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Action log</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div>
          <h2 className="mb-3 text-lg font-semibold">Bottleneck breakdown</h2>
          <DataTable
            rows={bottleneck}
            columns={bottleneckCols}
            emptyMessage="No data."
            rowKey={(r: any, i: number) => String(r.bottleneck_kind ?? i)}
          />
        </div>
        <div>
          <h2 className="mb-3 text-lg font-semibold">North-star distribution</h2>
          <DataTable
            rows={northStar}
            columns={northStarCols}
            emptyMessage="No data."
            rowKey={(r: any, i: number) => String(r.bucket ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Monthly first-value trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
