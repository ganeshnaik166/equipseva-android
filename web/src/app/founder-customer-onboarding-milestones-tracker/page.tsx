import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [activeRes, milestoneRes, stalledRes, funnelRes, eventsRes, kpiRes, cohortRes] = await Promise.all([
    sb.rpc('r2240_active_journeys'),
    sb.rpc('r2240_milestone_summary'),
    sb.rpc('r2240_stalled_customers'),
    sb.rpc('r2240_funnel_conversion'),
    sb.rpc('r2240_recent_events'),
    sb.rpc('r2240_kpi_snapshot'),
    sb.rpc('r2240_cohort_breakdown'),
  ]);

  const active = (activeRes.data ?? []) as any[];
  const milestones = (milestoneRes.data ?? []) as any[];
  const stalled = (stalledRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const kpi = (kpiRes.data?.[0] ?? {}) as any;
  const cohort = (cohortRes.data ?? []) as any[];

  const activeCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => String(r.customer_name ?? '') },
    { key: 'organization_name', header: 'Organization', render: (r: any) => String(r.organization_name ?? '') },
    { key: 'current_milestone', header: 'Current Milestone', render: (r: any) => String(r.current_milestone ?? '') },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => String(r.completion_pct ?? 0) + '%' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'days_in_progress', header: 'Days In', render: (r: any) => String(r.days_in_progress ?? 0) },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => String(r.days_remaining ?? 0) },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'milestone', header: 'Milestone', render: (r: any) => String(r.milestone ?? '') },
    { key: 'total_started', header: 'Started', render: (r: any) => String(r.total_started ?? 0) },
    { key: 'total_completed', header: 'Completed', render: (r: any) => String(r.total_completed ?? 0) },
    { key: 'total_skipped', header: 'Skipped', render: (r: any) => String(r.total_skipped ?? 0) },
    { key: 'total_delayed', header: 'Delayed', render: (r: any) => String(r.total_delayed ?? 0) },
    { key: 'avg_days_to_complete', header: 'Avg Days', render: (r: any) => String(r.avg_days_to_complete ?? '-') },
  ];

  const stalledCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => String(r.customer_name ?? '') },
    { key: 'organization_name', header: 'Organization', render: (r: any) => String(r.organization_name ?? '') },
    { key: 'current_milestone', header: 'Stuck At', render: (r: any) => String(r.current_milestone ?? '') },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => String(r.completion_pct ?? 0) + '%' },
    { key: 'days_since_last_event', header: 'Days Quiet', render: (r: any) => String(r.days_since_last_event ?? 0) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => String(r.stage ?? '') },
    { key: 'customers_reached', header: 'Customers Reached', render: (r: any) => String(r.customers_reached ?? 0) },
    { key: 'conversion_pct', header: 'Conversion %', render: (r: any) => String(r.conversion_pct ?? 0) + '%' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'customer_name', header: 'Customer', render: (r: any) => String(r.customer_name ?? '') },
    { key: 'milestone', header: 'Milestone', render: (r: any) => String(r.milestone ?? '') },
    { key: 'event_type', header: 'Event', render: (r: any) => String(r.event_type ?? '') },
    { key: 'days_from_start', header: 'Day #', render: (r: any) => String(r.days_from_start ?? '-') },
    { key: 'outcome_notes', header: 'Notes', render: (r: any) => String(r.outcome_notes ?? '') },
    { key: 'created_at', header: 'At', render: (r: any) => String(r.created_at ?? '').slice(0, 16).replace('T', ' ') },
  ];

  const cohortCols: Column<any>[] = [
    { key: 'cohort_week', header: 'Cohort Week', render: (r: any) => String(r.cohort_week ?? '') },
    { key: 'journeys_started', header: 'Started', render: (r: any) => String(r.journeys_started ?? 0) },
    { key: 'journeys_completed', header: 'Completed', render: (r: any) => String(r.journeys_completed ?? 0) },
    { key: 'avg_days_to_complete', header: 'Avg Days', render: (r: any) => String(r.avg_days_to_complete ?? '-') },
    { key: 'amc_signups', header: 'AMC Signups', render: (r: any) => String(r.amc_signups ?? 0) },
  ];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer Onboarding Milestones Tracker</h1>
        <p className="text-sm text-gray-600">14-day journey from welcome call → kit dispatch → first service → AMC signup. Watch funnel completion and catch stalls fast.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total Journeys</div>
          <div className="text-xl font-semibold">{String(kpi.total_journeys ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">In Progress</div>
          <div className="text-xl font-semibold">{String(kpi.in_progress_count ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="text-xl font-semibold">{String(kpi.completed_count ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Stalled</div>
          <div className="text-xl font-semibold">{String(kpi.stalled_count ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg Completion %</div>
          <div className="text-xl font-semibold">{String(kpi.avg_completion_pct ?? 0)}%</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">AMC Signup Rate</div>
          <div className="text-xl font-semibold">{String(kpi.amc_signup_rate_pct ?? 0)}%</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Abandoned</div>
          <div className="text-xl font-semibold">{String(kpi.abandoned_count ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg Days to Complete</div>
          <div className="text-xl font-semibold">{String(kpi.avg_completion_days ?? '-')}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active Journeys</h2>
        <DataTable columns={activeCols} rows={active} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Milestone Summary</h2>
        <DataTable columns={milestoneCols} rows={milestones} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stalled Customers (Need Outreach)</h2>
        <DataTable columns={stalledCols} rows={stalled} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Funnel Conversion</h2>
        <DataTable columns={funnelCols} rows={funnel} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Cohort Breakdown</h2>
        <DataTable columns={cohortCols} rows={cohort} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Milestone Events</h2>
        <DataTable columns={eventCols} rows={events} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
