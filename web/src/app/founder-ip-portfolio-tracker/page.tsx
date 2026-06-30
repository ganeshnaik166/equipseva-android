import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioSummary = {
  asset_type: string;
  asset_count: number;
  active_jurisdictions: number;
  total_counsel_cost_inr: number;
  total_annuity_inr: number;
  watch_active_count: number;
};

type JurisdictionRollup = {
  jurisdiction: string;
  asset_count: number;
  granted_count: number;
  pending_count: number;
  counsel_spend_inr: number;
};

type UpcomingDeadline = {
  asset_code: string;
  asset_title: string;
  event_type: string;
  due_date: string;
  days_to_due: number;
  urgency: string;
  jurisdiction: string;
  cost_estimate_inr: number;
  responsible_party: string;
};

type CounselSpend = {
  counsel_firm: string;
  asset_count: number;
  ytd_spend_inr: number;
  event_invoiced_inr: number;
  total_inr: number;
};

type StagePipeline = {
  current_stage: string;
  asset_count: number;
  total_annuity_inr: number;
  next_30d_events: number;
  next_90d_events: number;
};

type InfringementWatch = {
  asset_code: string;
  asset_title: string;
  technology_area: string;
  jurisdiction: string;
  open_alerts: number;
  resolved_alerts: number;
  total_response_inr: number;
};

type PriorityMap = {
  strategic_priority: string;
  technology_area: string;
  asset_count: number;
  granted_count: number;
  counsel_spend_inr: number;
  watch_active_count: number;
};

type OverdueAction = {
  asset_code: string;
  event_type: string;
  jurisdiction: string;
  due_date: string;
  days_overdue: number;
  urgency: string;
  cost_estimate_inr: number;
  responsible_party: string;
  external_party: string | null;
};

type QuarterlyBurn = {
  fiscal_quarter: string;
  events_paid: number;
  events_upcoming: number;
  paid_inr: number;
  upcoming_estimate_inr: number;
};

const inr = (n: number | null | undefined) =>
  n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    jurisdictionRes,
    deadlinesRes,
    counselRes,
    stageRes,
    watchRes,
    priorityRes,
    overdueRes,
    burnRes,
  ] = await Promise.all([
    supabase.rpc('r3129_portfolio_summary'),
    supabase.rpc('r3129_jurisdiction_rollup'),
    supabase.rpc('r3129_upcoming_deadlines', { p_days: 365 }),
    supabase.rpc('r3129_counsel_spend_by_firm'),
    supabase.rpc('r3129_stage_pipeline'),
    supabase.rpc('r3129_infringement_watch'),
    supabase.rpc('r3129_priority_strategic_map'),
    supabase.rpc('r3129_overdue_actions'),
    supabase.rpc('r3129_quarterly_burn'),
  ]);

  const summary = (summaryRes.data ?? []) as PortfolioSummary[];
  const jurisdictions = (jurisdictionRes.data ?? []) as JurisdictionRollup[];
  const deadlines = (deadlinesRes.data ?? []) as UpcomingDeadline[];
  const counsel = (counselRes.data ?? []) as CounselSpend[];
  const stages = (stageRes.data ?? []) as StagePipeline[];
  const watch = (watchRes.data ?? []) as InfringementWatch[];
  const priority = (priorityRes.data ?? []) as PriorityMap[];
  const overdue = (overdueRes.data ?? []) as OverdueAction[];
  const burn = (burnRes.data ?? []) as QuarterlyBurn[];

  const summaryCols: Column<PortfolioSummary>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'asset_count', header: 'Assets' },
    { key: 'active_jurisdictions', header: 'Jurisdictions' },
    { key: 'total_counsel_cost_inr', header: 'Counsel YTD', render: (r) => inr(r.total_counsel_cost_inr) },
    { key: 'total_annuity_inr', header: 'Annuity Due', render: (r) => inr(r.total_annuity_inr) },
    { key: 'watch_active_count', header: 'Watch Active' },
  ];

  const jurisdictionCols: Column<JurisdictionRollup>[] = [
    { key: 'jurisdiction', header: 'Jurisdiction' },
    { key: 'asset_count', header: 'Assets' },
    { key: 'granted_count', header: 'Granted' },
    { key: 'pending_count', header: 'Pending' },
    { key: 'counsel_spend_inr', header: 'Counsel Spend', render: (r) => inr(r.counsel_spend_inr) },
  ];

  const deadlineCols: Column<UpcomingDeadline>[] = [
    { key: 'asset_code', header: 'Asset' },
    { key: 'asset_title', header: 'Title' },
    { key: 'event_type', header: 'Event' },
    { key: 'due_date', header: 'Due' },
    { key: 'days_to_due', header: 'Days' },
    { key: 'urgency', header: 'Urgency' },
    { key: 'jurisdiction', header: 'Jx' },
    { key: 'cost_estimate_inr', header: 'Cost Est', render: (r) => inr(r.cost_estimate_inr) },
    { key: 'responsible_party', header: 'Owner' },
  ];

  const counselCols: Column<CounselSpend>[] = [
    { key: 'counsel_firm', header: 'Firm' },
    { key: 'asset_count', header: 'Assets' },
    { key: 'ytd_spend_inr', header: 'YTD on Assets', render: (r) => inr(r.ytd_spend_inr) },
    { key: 'event_invoiced_inr', header: 'Invoiced (paid)', render: (r) => inr(r.event_invoiced_inr) },
    { key: 'total_inr', header: 'Total Spend', render: (r) => inr(r.total_inr) },
  ];

  const stageCols: Column<StagePipeline>[] = [
    { key: 'current_stage', header: 'Stage' },
    { key: 'asset_count', header: 'Assets' },
    { key: 'total_annuity_inr', header: 'Annuity', render: (r) => inr(r.total_annuity_inr) },
    { key: 'next_30d_events', header: 'Next 30d Events' },
    { key: 'next_90d_events', header: 'Next 90d Events' },
  ];

  const watchCols: Column<InfringementWatch>[] = [
    { key: 'asset_code', header: 'Asset' },
    { key: 'asset_title', header: 'Title' },
    { key: 'technology_area', header: 'Tech Area' },
    { key: 'jurisdiction', header: 'Jx' },
    { key: 'open_alerts', header: 'Open Alerts' },
    { key: 'resolved_alerts', header: 'Resolved' },
    { key: 'total_response_inr', header: 'Response Cost', render: (r) => inr(r.total_response_inr) },
  ];

  const priorityCols: Column<PriorityMap>[] = [
    { key: 'strategic_priority', header: 'Priority' },
    { key: 'technology_area', header: 'Tech Area' },
    { key: 'asset_count', header: 'Assets' },
    { key: 'granted_count', header: 'Granted' },
    { key: 'counsel_spend_inr', header: 'Counsel Spend', render: (r) => inr(r.counsel_spend_inr) },
    { key: 'watch_active_count', header: 'Watch' },
  ];

  const overdueCols: Column<OverdueAction>[] = [
    { key: 'asset_code', header: 'Asset' },
    { key: 'event_type', header: 'Event' },
    { key: 'jurisdiction', header: 'Jx' },
    { key: 'due_date', header: 'Due' },
    { key: 'days_overdue', header: 'Days Overdue' },
    { key: 'urgency', header: 'Urgency' },
    { key: 'cost_estimate_inr', header: 'Cost Est', render: (r) => inr(r.cost_estimate_inr) },
    { key: 'responsible_party', header: 'Owner' },
    { key: 'external_party', header: 'Counsel' },
  ];

  const burnCols: Column<QuarterlyBurn>[] = [
    { key: 'fiscal_quarter', header: 'Quarter' },
    { key: 'events_paid', header: 'Paid Events' },
    { key: 'events_upcoming', header: 'Upcoming Events' },
    { key: 'paid_inr', header: 'Paid', render: (r) => inr(r.paid_inr) },
    { key: 'upcoming_estimate_inr', header: 'Upcoming Est', render: (r) => inr(r.upcoming_estimate_inr) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-8">
        <h1 className="text-2xl font-semibold">Founder IP Portfolio & Trademark Renewal Calendar</h1>
        <p className="text-sm text-gray-600 mt-2">
          Quarterly strategic tracker for patent applications, trademark renewals, annuity due dates,
          infringement watch, and outside-counsel spend across all jurisdictions.
        </p>
      </header>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Portfolio Summary by Asset Type</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No portfolio data yet."
          rowKey={(r, i) => String((r as PortfolioSummary).asset_type ?? i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Jurisdiction Rollup</h2>
        <DataTable
          rows={jurisdictions}
          columns={jurisdictionCols}
          emptyMessage="No jurisdictional data yet."
          rowKey={(r, i) => String((r as JurisdictionRollup).jurisdiction ?? i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Upcoming Deadlines (next 365 days)</h2>
        <DataTable
          rows={deadlines}
          columns={deadlineCols}
          emptyMessage="No upcoming deadlines."
          rowKey={(r, i) => String((r as UpcomingDeadline).asset_code + '-' + (r as UpcomingDeadline).due_date) ?? String(i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Counsel Spend by Firm</h2>
        <DataTable
          rows={counsel}
          columns={counselCols}
          emptyMessage="No counsel invoices yet."
          rowKey={(r, i) => String((r as CounselSpend).counsel_firm ?? i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Stage Pipeline</h2>
        <DataTable
          rows={stages}
          columns={stageCols}
          emptyMessage="No pipeline data yet."
          rowKey={(r, i) => String((r as StagePipeline).current_stage ?? i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Infringement Watch (active assets)</h2>
        <DataTable
          rows={watch}
          columns={watchCols}
          emptyMessage="No active watch."
          rowKey={(r, i) => String((r as InfringementWatch).asset_code ?? i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Strategic Priority Map</h2>
        <DataTable
          rows={priority}
          columns={priorityCols}
          emptyMessage="No strategic map data yet."
          rowKey={(r, i) => String((r as PriorityMap).strategic_priority + '-' + (r as PriorityMap).technology_area) ?? String(i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Overdue Actions (escalate immediately)</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue actions. Calendar is clean."
          rowKey={(r, i) => String((r as OverdueAction).asset_code + '-' + (r as OverdueAction).due_date) ?? String(i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Quarterly Burn (paid vs upcoming)</h2>
        <DataTable
          rows={burn}
          columns={burnCols}
          emptyMessage="No quarterly burn data yet."
          rowKey={(r, i) => String((r as QuarterlyBurn).fiscal_quarter ?? i)}
        />
      </section>
    </main>
  );
}
