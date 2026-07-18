import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [events, outcomes, topInfluence, kindBreakdown, attendance, costVsOutcome, monthly] = await Promise.all([
    supabase.rpc('list_events_r2511'),
    supabase.rpc('list_followup_outcomes_r2511'),
    supabase.rpc('top_influence_events_r2511'),
    supabase.rpc('kind_breakdown_r2511'),
    supabase.rpc('attendance_summary_r2511'),
    supabase.rpc('cost_vs_outcome_r2511'),
    supabase.rpc('monthly_event_trend_r2511'),
  ]);

  const eventsRows = (events.data ?? []) as any[];
  const outcomesRows = (outcomes.data ?? []) as any[];
  const topRows = (topInfluence.data ?? []) as any[];
  const kindRows = (kindBreakdown.data ?? []) as any[];
  const attendanceRows = (attendance.data ?? []) as any[];
  const costRows = (costVsOutcome.data ?? []) as any[];
  const monthlyRows = (monthly.data ?? []) as any[];

  const eventsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'held_at', header: 'Held at', render: (r: any) => r.held_at ? new Date(r.held_at).toLocaleString() : '' },
    { key: 'stakeholder_name', header: 'Stakeholder', render: (r: any) => r.stakeholder_name },
    { key: 'stakeholder_role', header: 'Role', render: (r: any) => r.stakeholder_role ?? '' },
    { key: 'attended', header: 'Attended', render: (r: any) => r.attended ? 'yes' : 'no' },
    { key: 'deal_influence', header: 'Influence', render: (r: any) => r.deal_influence },
    { key: 'cost_rupees', header: 'Cost (Rs)', render: (r: any) => String(r.cost_rupees ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
  ];

  const outcomesCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name },
    { key: 'outcome_at', header: 'Outcome at', render: (r: any) => r.outcome_at ? new Date(r.outcome_at).toLocaleString() : '' },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'revenue_influenced_rupees', header: 'Revenue (Rs)', render: (r: any) => String(r.revenue_influenced_rupees ?? 0) },
    { key: 'next_step', header: 'Next step', render: (r: any) => r.next_step ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name },
    { key: 'deal_influence', header: 'Influence', render: (r: any) => r.deal_influence },
    { key: 'cost_rupees', header: 'Cost (Rs)', render: (r: any) => String(r.cost_rupees ?? 0) },
    { key: 'total_revenue_influenced_rupees', header: 'Revenue (Rs)', render: (r: any) => String(r.total_revenue_influenced_rupees ?? 0) },
    { key: 'roi_multiple', header: 'ROI x', render: (r: any) => r.roi_multiple == null ? '-' : String(r.roi_multiple) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'event_count', header: 'Events', render: (r: any) => String(r.event_count ?? 0) },
    { key: 'attended_count', header: 'Attended', render: (r: any) => String(r.attended_count ?? 0) },
    { key: 'total_cost_rupees', header: 'Cost (Rs)', render: (r: any) => String(r.total_cost_rupees ?? 0) },
    { key: 'total_revenue_influenced_rupees', header: 'Revenue (Rs)', render: (r: any) => String(r.total_revenue_influenced_rupees ?? 0) },
  ];

  const attendanceCols: Column<any>[] = [
    { key: 'total_events', header: 'Total events', render: (r: any) => String(r.total_events ?? 0) },
    { key: 'attended_events', header: 'Attended', render: (r: any) => String(r.attended_events ?? 0) },
    { key: 'no_shows', header: 'No-shows', render: (r: any) => String(r.no_shows ?? 0) },
    { key: 'attendance_rate_pct', header: 'Attendance %', render: (r: any) => String(r.attendance_rate_pct ?? 0) },
    { key: 'high_or_critical_influence', header: 'High/Critical', render: (r: any) => String(r.high_or_critical_influence ?? 0) },
  ];

  const costCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_cost_rupees', header: 'Cost (Rs)', render: (r: any) => String(r.total_cost_rupees ?? 0) },
    { key: 'total_revenue_influenced_rupees', header: 'Revenue (Rs)', render: (r: any) => String(r.total_revenue_influenced_rupees ?? 0) },
    { key: 'net_rupees', header: 'Net (Rs)', render: (r: any) => String(r.net_rupees ?? 0) },
    { key: 'outcomes_count', header: 'Outcomes', render: (r: any) => String(r.outcomes_count ?? 0) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '' },
    { key: 'events_count', header: 'Events', render: (r: any) => String(r.events_count ?? 0) },
    { key: 'attended_count', header: 'Attended', render: (r: any) => String(r.attended_count ?? 0) },
    { key: 'total_cost_rupees', header: 'Cost (Rs)', render: (r: any) => String(r.total_cost_rupees ?? 0) },
    { key: 'total_revenue_influenced_rupees', header: 'Revenue (Rs)', render: (r: any) => String(r.total_revenue_influenced_rupees ?? 0) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Stakeholder Event Attendance</h1>
        <p className="text-sm text-gray-600">
          Track chain & event & stakeholder attended & prep & follow-up & deal influence & cost =&gt; founder ops insight.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Attendance summary</h2>
        <DataTable
          rows={attendanceRows}
          columns={attendanceCols}
          emptyMessage="No attendance data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top influence events (ROI)</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No top-influence events."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Kind breakdown</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No kind breakdown."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cost vs outcome by chain</h2>
        <DataTable
          rows={costRows}
          columns={costCols}
          emptyMessage="No cost/outcome rows."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No monthly trend."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Events</h2>
        <DataTable
          rows={eventsRows}
          columns={eventsCols}
          emptyMessage="No events logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-up outcomes</h2>
        <DataTable
          rows={outcomesRows}
          columns={outcomesCols}
          emptyMessage="No follow-up outcomes."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
