import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PriorityRow = {
  id: string;
  week_start: string;
  priority_title: string;
  priority_category: string;
  owner_email: string | null;
  effort_estimate_hours: number;
  business_impact: string;
  latest_outcome: string | null;
  root_cause: string | null;
  actual_effort_hours: number | null;
  entered_at: string;
};

type FunnelRow = {
  week_start: string;
  entered_count: number;
  shipped_count: number;
  dropped_count: number;
  deferred_count: number;
  still_in_progress_count: number;
  blocked_count: number;
  ship_rate_pct: number | null;
  drop_rate_pct: number | null;
};

type RootCauseRow = {
  root_cause: string;
  priority_count: number;
  avg_effort_estimate: number | null;
  pct_of_non_shipped: number | null;
};

type CategoryRow = {
  priority_category: string;
  total_priorities: number;
  shipped: number;
  dropped: number;
  ship_rate_pct: number | null;
};

type VarianceRow = {
  priority_id: string;
  priority_title: string;
  week_start: string;
  effort_estimate_hours: number;
  actual_effort_hours: number | null;
  variance_hours: number | null;
  variance_pct: number | null;
};

type OwnerRow = {
  owner_email: string | null;
  total_priorities: number;
  shipped: number;
  dropped: number;
  blocked: number;
  ship_rate_pct: number | null;
};

type TrendRow = {
  bucket: string;
  weeks_covered: number;
  total_priorities: number;
  total_shipped: number;
  total_dropped: number;
  rolling_ship_rate_pct: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [prioRes, funnelRes, rootRes, catRes, varRes, ownerRes, trendRes] = await Promise.all([
    sb.rpc('list_weekly_priorities_r2381'),
    sb.rpc('weekly_funnel_exit_rate_r2381'),
    sb.rpc('root_cause_breakdown_r2381'),
    sb.rpc('ship_rate_by_category_r2381'),
    sb.rpc('effort_variance_r2381'),
    sb.rpc('owner_ship_rate_r2381'),
    sb.rpc('rolling_funnel_trend_r2381'),
  ]);

  const priorities: PriorityRow[] = (prioRes.data as PriorityRow[] | null) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[] | null) ?? [];
  const roots: RootCauseRow[] = (rootRes.data as RootCauseRow[] | null) ?? [];
  const cats: CategoryRow[] = (catRes.data as CategoryRow[] | null) ?? [];
  const variances: VarianceRow[] = (varRes.data as VarianceRow[] | null) ?? [];
  const owners: OwnerRow[] = (ownerRes.data as OwnerRow[] | null) ?? [];
  const trends: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];

  const prioCols: Column<PriorityRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'priority_title', header: 'Priority', render: (r: any) => r.priority_title },
    { key: 'priority_category', header: 'Category', render: (r: any) => r.priority_category },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'business_impact', header: 'Impact', render: (r: any) => r.business_impact },
    { key: 'effort_estimate_hours', header: 'Est hrs', render: (r: any) => r.effort_estimate_hours },
    { key: 'latest_outcome', header: 'Outcome', render: (r: any) => r.latest_outcome ?? 'pending' },
    { key: 'root_cause', header: 'Root cause', render: (r: any) => r.root_cause ?? '—' },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'entered_count', header: 'Entered', render: (r: any) => r.entered_count },
    { key: 'shipped_count', header: 'Shipped', render: (r: any) => r.shipped_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'deferred_count', header: 'Deferred', render: (r: any) => r.deferred_count },
    { key: 'still_in_progress_count', header: 'In progress', render: (r: any) => r.still_in_progress_count },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => r.blocked_count },
    { key: 'ship_rate_pct', header: 'Ship %', render: (r: any) => r.ship_rate_pct ?? '—' },
    { key: 'drop_rate_pct', header: 'Drop %', render: (r: any) => r.drop_rate_pct ?? '—' },
  ];

  const rootCols: Column<RootCauseRow>[] = [
    { key: 'root_cause', header: 'Root cause', render: (r: any) => r.root_cause },
    { key: 'priority_count', header: 'Count', render: (r: any) => r.priority_count },
    { key: 'avg_effort_estimate', header: 'Avg est hrs', render: (r: any) => r.avg_effort_estimate ?? '—' },
    { key: 'pct_of_non_shipped', header: '% of non-shipped', render: (r: any) => r.pct_of_non_shipped ?? '—' },
  ];

  const catCols: Column<CategoryRow>[] = [
    { key: 'priority_category', header: 'Category', render: (r: any) => r.priority_category },
    { key: 'total_priorities', header: 'Total', render: (r: any) => r.total_priorities },
    { key: 'shipped', header: 'Shipped', render: (r: any) => r.shipped },
    { key: 'dropped', header: 'Dropped', render: (r: any) => r.dropped },
    { key: 'ship_rate_pct', header: 'Ship %', render: (r: any) => r.ship_rate_pct ?? '—' },
  ];

  const varCols: Column<VarianceRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'priority_title', header: 'Priority', render: (r: any) => r.priority_title },
    { key: 'effort_estimate_hours', header: 'Est hrs', render: (r: any) => r.effort_estimate_hours },
    { key: 'actual_effort_hours', header: 'Actual hrs', render: (r: any) => r.actual_effort_hours ?? '—' },
    { key: 'variance_hours', header: 'Variance hrs', render: (r: any) => r.variance_hours ?? '—' },
    { key: 'variance_pct', header: 'Variance %', render: (r: any) => r.variance_pct ?? '—' },
  ];

  const ownerCols: Column<OwnerRow>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'total_priorities', header: 'Total', render: (r: any) => r.total_priorities },
    { key: 'shipped', header: 'Shipped', render: (r: any) => r.shipped },
    { key: 'dropped', header: 'Dropped', render: (r: any) => r.dropped },
    { key: 'blocked', header: 'Blocked', render: (r: any) => r.blocked },
    { key: 'ship_rate_pct', header: 'Ship %', render: (r: any) => r.ship_rate_pct ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'weeks_covered', header: 'Weeks', render: (r: any) => r.weeks_covered },
    { key: 'total_priorities', header: 'Priorities', render: (r: any) => r.total_priorities },
    { key: 'total_shipped', header: 'Shipped', render: (r: any) => r.total_shipped },
    { key: 'total_dropped', header: 'Dropped', render: (r: any) => r.total_dropped },
    { key: 'rolling_ship_rate_pct', header: 'Rolling ship %', render: (r: any) => r.rolling_ship_rate_pct ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Weekly Priority Funnel Exit-Rate</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        What % of weekly priorities actually shipped vs got dropped, deferred, or blocked — with root-cause attribution, owner accountability, and effort-variance tracking.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly funnel exit-rate ({funnel.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Per-week entry-to-outcome funnel. Ship rate &gt;= 70% is healthy; drop rate &gt;= 20% means weekly intake is too ambitious.
        </p>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Rolling 4-week trend ({trends.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Last 4 weeks vs prior 4 weeks — is ship rate trending up or down?
        </p>
        <DataTable
          rows={trends}
          columns={trendCols}
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Root cause for non-shipped ({roots.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Why priorities did not ship. Top cause &gt;= 40% means systemic issue (e.g. scope creep, dependency blockers).
        </p>
        <DataTable
          rows={roots}
          columns={rootCols}
          rowKey={(r: any, i: number) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Ship rate by category ({cats.length})</h2>
        <DataTable
          rows={cats}
          columns={catCols}
          rowKey={(r: any, i: number) => String(r.priority_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner ship rate ({owners.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Per-owner accountability. Ship rate &lt;= 50% across &gt;= 5 priorities warrants a 1:1.
        </p>
        <DataTable
          rows={owners}
          columns={ownerCols}
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Effort variance — shipped only ({variances.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Estimated vs actual hours for shipped work. Variance &gt;= 50% means estimation is systematically off.
        </p>
        <DataTable
          rows={variances}
          columns={varCols}
          rowKey={(r: any, i: number) => String(r.priority_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All priorities ({priorities.length})</h2>
        <DataTable
          rows={priorities}
          columns={prioCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
