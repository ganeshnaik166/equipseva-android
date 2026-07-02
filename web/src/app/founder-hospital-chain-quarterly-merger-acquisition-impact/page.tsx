import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_events: number;
  closed_events: number;
  pending_events: number;
  total_deal_value_crore: number;
  exposed_revenue_lakh: number;
  active_contracts: number;
  expanded_contracts: number;
};

type EventRow = {
  id: string;
  chain_name: string;
  event_type: string;
  event_quarter: string;
  announced_on: string;
  expected_close_on: string | null;
  closed_on: string | null;
  counterparty: string;
  deal_value_crore: number;
  acquirer_country: string;
  combined_beds: number;
  combined_hospitals: number;
  our_active_contracts: number;
  our_active_engineers: number;
  our_quarterly_revenue_lakh: number;
  exposure_tier: string;
  renegotiation_status: string;
  renegotiation_outcome: string | null;
  contract_delta_pct: number | null;
  strategy_play: string;
  owner_role: string;
  next_review_on: string;
  notes: string | null;
};

type ExposureRow = {
  exposure_tier: string;
  events: number;
  contracts: number;
  engineers: number;
  quarterly_revenue_lakh: number;
};

type RenegoRow = {
  renegotiation_status: string;
  events: number;
  signed_share_pct: number;
  revenue_lakh: number;
};

type StrategyRow = {
  strategy_play: string;
  events: number;
  avg_contract_delta_pct: number;
  revenue_lakh: number;
};

type ActionRow = {
  chain_name: string;
  action_date: string;
  action_type: string;
  owner: string;
  outcome: string;
  revenue_impact_lakh: number;
  summary: string;
};

type ReviewRow = {
  chain_name: string;
  next_review_on: string;
  days_until: number;
  exposure_tier: string;
  renegotiation_status: string;
  strategy_play: string;
  owner_role: string;
};

type OutcomeRow = {
  renegotiation_outcome: string;
  events: number;
  avg_delta_pct: number;
  revenue_lakh: number;
};

function fmtNum(n: number | null | undefined, digits = 2) {
  if (n === null || n === undefined) return '—';
  return Number(n).toLocaleString('en-IN', { maximumFractionDigits: digits });
}

function pctBadge(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  const sign = v > 0 ? '+' : '';
  return `${sign}${v.toFixed(2)}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    eventsRes,
    exposureRes,
    renegoRes,
    strategyRes,
    actionsRes,
    reviewsRes,
    outcomeRes,
  ] = await Promise.all([
    supabase.rpc('chain_ma_overview_r2767'),
    supabase.rpc('chain_ma_events_list_r2767'),
    supabase.rpc('chain_ma_by_exposure_r2767'),
    supabase.rpc('chain_ma_renegotiation_status_r2767'),
    supabase.rpc('chain_ma_strategy_mix_r2767'),
    supabase.rpc('chain_ma_recent_actions_r2767'),
    supabase.rpc('chain_ma_upcoming_reviews_r2767'),
    supabase.rpc('chain_ma_outcome_summary_r2767'),
  ]);

  const overview: Overview = (overviewRes.data?.[0] ?? {
    total_events: 0,
    closed_events: 0,
    pending_events: 0,
    total_deal_value_crore: 0,
    exposed_revenue_lakh: 0,
    active_contracts: 0,
    expanded_contracts: 0,
  }) as Overview;

  const events: EventRow[] = (eventsRes.data ?? []) as EventRow[];
  const exposure: ExposureRow[] = (exposureRes.data ?? []) as ExposureRow[];
  const renego: RenegoRow[] = (renegoRes.data ?? []) as RenegoRow[];
  const strategy: StrategyRow[] = (strategyRes.data ?? []) as StrategyRow[];
  const actions: ActionRow[] = (actionsRes.data ?? []) as ActionRow[];
  const reviews: ReviewRow[] = (reviewsRes.data ?? []) as ReviewRow[];
  const outcomes: OutcomeRow[] = (outcomeRes.data ?? []) as OutcomeRow[];

  const kpis = [
    { label: 'Tracked M&A Events', value: String(overview.total_events) },
    { label: 'Closed / Pending', value: `${overview.closed_events} / ${overview.pending_events}` },
    { label: 'Combined Deal Value', value: `₹${fmtNum(overview.total_deal_value_crore)} Cr` },
    { label: 'Exposed Qtr Revenue', value: `₹${fmtNum(overview.exposed_revenue_lakh)} L` },
    { label: 'Active Contracts at Risk', value: String(overview.active_contracts) },
    { label: 'Already Expanded', value: String(overview.expanded_contracts) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Hospital Chain Quarterly M&A Impact
        </h1>
        <p style={{ color: '#666' }}>
          Track chain mergers, acquisitions, divestitures & spinoffs against our exposure
          (contracts, engineers, revenue). Surface renegotiation status, outcome deltas, and the
          strategy play per event so the next move is never lost.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 28,
        }}
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            style={{
              border: '1px solid #e6e6e6',
              borderRadius: 10,
              padding: 14,
              background: '#fafafa',
            }}
          >
            <div style={{ fontSize: 12, color: '#777', marginBottom: 6 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Exposure by Tier</h2>
        <DataTable
          rows={exposure}
          columns={[
            { key: 'exposure_tier', header: 'Tier', render: (r: ExposureRow) => r.exposure_tier },
            { key: 'events', header: 'Events', render: (r: ExposureRow) => String(r.events) },
            { key: 'contracts', header: 'Contracts', render: (r: ExposureRow) => String(r.contracts) },
            { key: 'engineers', header: 'Engineers', render: (r: ExposureRow) => String(r.engineers) },
            {
              key: 'rev',
              header: 'Qtr Revenue (₹L)',
              render: (r: ExposureRow) => fmtNum(r.quarterly_revenue_lakh),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: ExposureRow, i: number) => String(r.exposure_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Renegotiation Status Mix
        </h2>
        <DataTable
          rows={renego}
          columns={[
            {
              key: 'renegotiation_status',
              header: 'Status',
              render: (r: RenegoRow) => r.renegotiation_status,
            },
            { key: 'events', header: 'Events', render: (r: RenegoRow) => String(r.events) },
            {
              key: 'share',
              header: 'Share %',
              render: (r: RenegoRow) => `${fmtNum(r.signed_share_pct)}%`,
            },
            {
              key: 'rev',
              header: 'Qtr Revenue (₹L)',
              render: (r: RenegoRow) => fmtNum(r.revenue_lakh),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: RenegoRow, i: number) => String(r.renegotiation_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Strategy Play Mix</h2>
        <DataTable
          rows={strategy}
          columns={[
            {
              key: 'strategy_play',
              header: 'Play',
              render: (r: StrategyRow) => r.strategy_play,
            },
            { key: 'events', header: 'Events', render: (r: StrategyRow) => String(r.events) },
            {
              key: 'avg',
              header: 'Avg Δ %',
              render: (r: StrategyRow) => pctBadge(r.avg_contract_delta_pct),
            },
            {
              key: 'rev',
              header: 'Qtr Revenue (₹L)',
              render: (r: StrategyRow) => fmtNum(r.revenue_lakh),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: StrategyRow, i: number) => String(r.strategy_play ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Outcome Summary</h2>
        <DataTable
          rows={outcomes}
          columns={[
            {
              key: 'renegotiation_outcome',
              header: 'Outcome',
              render: (r: OutcomeRow) => r.renegotiation_outcome,
            },
            { key: 'events', header: 'Events', render: (r: OutcomeRow) => String(r.events) },
            {
              key: 'avg',
              header: 'Avg Δ %',
              render: (r: OutcomeRow) => pctBadge(r.avg_delta_pct),
            },
            {
              key: 'rev',
              header: 'Qtr Revenue (₹L)',
              render: (r: OutcomeRow) => fmtNum(r.revenue_lakh),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.renegotiation_outcome ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>All M&A Events</h2>
        <DataTable
          rows={events}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: EventRow) => r.chain_name },
            { key: 'event_type', header: 'Type', render: (r: EventRow) => r.event_type },
            { key: 'event_quarter', header: 'Quarter', render: (r: EventRow) => r.event_quarter },
            { key: 'counterparty', header: 'Counterparty', render: (r: EventRow) => r.counterparty },
            {
              key: 'deal',
              header: 'Deal (₹Cr)',
              render: (r: EventRow) => fmtNum(r.deal_value_crore),
            },
            {
              key: 'exposure_tier',
              header: 'Exposure',
              render: (r: EventRow) => r.exposure_tier,
            },
            {
              key: 'contracts',
              header: 'Contracts',
              render: (r: EventRow) => String(r.our_active_contracts),
            },
            {
              key: 'qtr_rev',
              header: 'Qtr Rev (₹L)',
              render: (r: EventRow) => fmtNum(r.our_quarterly_revenue_lakh),
            },
            {
              key: 'renegotiation_status',
              header: 'Renegotiation',
              render: (r: EventRow) => r.renegotiation_status,
            },
            {
              key: 'outcome',
              header: 'Outcome',
              render: (r: EventRow) => r.renegotiation_outcome ?? 'pending',
            },
            {
              key: 'delta',
              header: 'Δ %',
              render: (r: EventRow) => pctBadge(r.contract_delta_pct),
            },
            {
              key: 'strategy_play',
              header: 'Play',
              render: (r: EventRow) => r.strategy_play,
            },
            { key: 'owner_role', header: 'Owner', render: (r: EventRow) => r.owner_role },
            {
              key: 'next_review_on',
              header: 'Next Review',
              render: (r: EventRow) => r.next_review_on,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: EventRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Upcoming Reviews</h2>
        <DataTable
          rows={reviews}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ReviewRow) => r.chain_name },
            {
              key: 'next_review_on',
              header: 'Review Date',
              render: (r: ReviewRow) => r.next_review_on,
            },
            {
              key: 'days_until',
              header: 'Days Until',
              render: (r: ReviewRow) => String(r.days_until),
            },
            {
              key: 'exposure_tier',
              header: 'Exposure',
              render: (r: ReviewRow) => r.exposure_tier,
            },
            {
              key: 'renegotiation_status',
              header: 'Renegotiation',
              render: (r: ReviewRow) => r.renegotiation_status,
            },
            {
              key: 'strategy_play',
              header: 'Play',
              render: (r: ReviewRow) => r.strategy_play,
            },
            { key: 'owner_role', header: 'Owner', render: (r: ReviewRow) => r.owner_role },
          ]}
          emptyMessage="No data"
          rowKey={(r: ReviewRow, i: number) => `${r.chain_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent Actions</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'action_date', header: 'Date', render: (r: ActionRow) => r.action_date },
            { key: 'chain_name', header: 'Chain', render: (r: ActionRow) => r.chain_name },
            { key: 'action_type', header: 'Action', render: (r: ActionRow) => r.action_type },
            { key: 'owner', header: 'Owner', render: (r: ActionRow) => r.owner },
            { key: 'outcome', header: 'Outcome', render: (r: ActionRow) => r.outcome },
            {
              key: 'revenue_impact_lakh',
              header: 'Impact (₹L)',
              render: (r: ActionRow) => fmtNum(r.revenue_impact_lakh),
            },
            { key: 'summary', header: 'Summary', render: (r: ActionRow) => r.summary },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => `${r.chain_name}-${r.action_date}-${i}`}
        />
      </section>
    </div>
  );
}
