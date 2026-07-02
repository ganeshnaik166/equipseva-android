import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Snapshot = {
  id: string;
  quarter_label: string;
  vertical: string;
  our_share_pct: number;
  top_competitor_name: string;
  top_competitor_share_pct: number;
  other_share_pct: number;
  tam_rupees: number;
  our_revenue_rupees: number;
  growth_qoq_pct: number;
  growth_yoy_pct: number;
  wins_count: number;
  losses_count: number;
  pipeline_count: number;
  status: string;
  recommended_action: string | null;
  owner_email: string | null;
};

type FocusRow = {
  vertical: string;
  our_share_pct: number;
  growth_yoy_pct: number;
  status: string;
  recommended_action: string | null;
};

type FunnelRow = {
  status: string;
  vertical_count: number;
  total_revenue_rupees: number;
};

type MonthlyRow = {
  month_start: string;
  wins: number;
  losses: number;
  net_revenue_rupees: number;
};

type QuarterlyRow = {
  quarter_label: string;
  avg_our_share_pct: number;
  total_revenue_rupees: number;
  avg_growth_yoy_pct: number;
};

type SummaryRow = {
  total_verticals: number;
  avg_our_share_pct: number;
  total_tam_rupees: number;
  total_our_revenue_rupees: number;
  total_wins: number;
  total_losses: number;
  gaining_count: number;
  losing_count: number;
};

type OwnerRow = {
  owner_email: string;
  vertical_count: number;
  total_revenue_rupees: number;
  losing_count: number;
};

type EventRow = {
  vertical: string;
  event_type: string;
  account_name: string;
  account_size_rupees: number;
  competitor_name: string | null;
  reason: string | null;
  occurred_on: string;
  owner_email: string | null;
};

const inr = (n: number | null | undefined) =>
  n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

const pct = (n: number | null | undefined) =>
  n == null ? '-' : Number(n).toFixed(2) + '%';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [snapsRes, focusRes, funnelRes, monthlyRes, quarterlyRes, summaryRes, ownerRes, eventsRes] =
    await Promise.all([
      supabase.rpc('list_market_share_snapshots_r2673'),
      supabase.rpc('top_market_share_focus_r2673'),
      supabase.rpc('market_share_status_funnel_r2673'),
      supabase.rpc('monthly_market_share_trend_r2673'),
      supabase.rpc('quarterly_market_share_trend_r2673'),
      supabase.rpc('market_share_summary_r2673'),
      supabase.rpc('market_share_owner_load_r2673'),
      supabase.rpc('recent_market_share_events_r2673'),
    ]);

  const snapshots = (snapsRes.data ?? []) as Snapshot[];
  const focus = (focusRes.data ?? []) as FocusRow[];
  const funnel = (funnelRes.data ?? []) as FunnelRow[];
  const monthly = (monthlyRes.data ?? []) as MonthlyRow[];
  const quarterly = (quarterlyRes.data ?? []) as QuarterlyRow[];
  const summary = ((summaryRes.data ?? [])[0] ?? null) as SummaryRow | null;
  const owners = (ownerRes.data ?? []) as OwnerRow[];
  const events = (eventsRes.data ?? []) as EventRow[];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Quarterly Market Share by Vertical
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Vertical × our share × competitor share × growth × win/loss & action.
      </p>

      {/* KPI cards */}
      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <Kpi label="Verticals tracked" value={summary?.total_verticals ?? 0} />
        <Kpi label="Avg our share" value={pct(summary?.avg_our_share_pct)} />
        <Kpi label="Total TAM" value={inr(summary?.total_tam_rupees)} />
        <Kpi label="Our revenue" value={inr(summary?.total_our_revenue_rupees)} />
        <Kpi label="Wins (sum)" value={summary?.total_wins ?? 0} />
        <Kpi label="Losses (sum)" value={summary?.total_losses ?? 0} />
        <Kpi label="Gaining" value={summary?.gaining_count ?? 0} />
        <Kpi label="Losing" value={summary?.losing_count ?? 0} />
      </section>

      {/* Snapshots master table */}
      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 16, marginBottom: 8 }}>
        Snapshots (share &gt;= competitor flag where gaining)
      </h2>
      <DataTable
        rows={snapshots}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.id ?? i)}
        columns={[
          { key: 'quarter_label', header: 'Quarter', render: (r: Snapshot) => r.quarter_label },
          { key: 'vertical', header: 'Vertical', render: (r: Snapshot) => r.vertical },
          { key: 'our_share_pct', header: 'Our %', render: (r: Snapshot) => pct(r.our_share_pct) },
          {
            key: 'top_competitor_name',
            header: 'Top competitor',
            render: (r: Snapshot) => r.top_competitor_name,
          },
          {
            key: 'top_competitor_share_pct',
            header: 'Comp %',
            render: (r: Snapshot) => pct(r.top_competitor_share_pct),
          },
          {
            key: 'other_share_pct',
            header: 'Other %',
            render: (r: Snapshot) => pct(r.other_share_pct),
          },
          { key: 'tam_rupees', header: 'TAM', render: (r: Snapshot) => inr(r.tam_rupees) },
          {
            key: 'our_revenue_rupees',
            header: 'Our rev',
            render: (r: Snapshot) => inr(r.our_revenue_rupees),
          },
          {
            key: 'growth_qoq_pct',
            header: 'QoQ',
            render: (r: Snapshot) => pct(r.growth_qoq_pct),
          },
          {
            key: 'growth_yoy_pct',
            header: 'YoY',
            render: (r: Snapshot) => pct(r.growth_yoy_pct),
          },
          { key: 'wins_count', header: 'Wins', render: (r: Snapshot) => r.wins_count },
          { key: 'losses_count', header: 'Losses', render: (r: Snapshot) => r.losses_count },
          { key: 'pipeline_count', header: 'Pipeline', render: (r: Snapshot) => r.pipeline_count },
          { key: 'status', header: 'Status', render: (r: Snapshot) => r.status },
          {
            key: 'recommended_action',
            header: 'Action',
            render: (r: Snapshot) => r.recommended_action ?? '-',
          },
          {
            key: 'owner_email',
            header: 'Owner',
            render: (r: Snapshot) => r.owner_email ?? '-',
          },
        ]}
      />

      {/* Top focus */}
      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
        Top focus (gaining & tracking, sorted by YoY)
      </h2>
      <DataTable
        rows={focus}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.vertical ?? i)}
        columns={[
          { key: 'vertical', header: 'Vertical', render: (r: FocusRow) => r.vertical },
          {
            key: 'our_share_pct',
            header: 'Our %',
            render: (r: FocusRow) => pct(r.our_share_pct),
          },
          {
            key: 'growth_yoy_pct',
            header: 'YoY',
            render: (r: FocusRow) => pct(r.growth_yoy_pct),
          },
          { key: 'status', header: 'Status', render: (r: FocusRow) => r.status },
          {
            key: 'recommended_action',
            header: 'Action',
            render: (r: FocusRow) => r.recommended_action ?? '-',
          },
        ]}
      />

      {/* Status funnel */}
      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
        Status funnel
      </h2>
      <DataTable
        rows={funnel}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.status ?? i)}
        columns={[
          { key: 'status', header: 'Status', render: (r: FunnelRow) => r.status },
          {
            key: 'vertical_count',
            header: 'Verticals',
            render: (r: FunnelRow) => r.vertical_count,
          },
          {
            key: 'total_revenue_rupees',
            header: 'Revenue',
            render: (r: FunnelRow) => inr(r.total_revenue_rupees),
          },
        ]}
      />

      {/* Quarterly trend */}
      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
        Quarterly trend
      </h2>
      <DataTable
        rows={quarterly}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.quarter_label ?? i)}
        columns={[
          {
            key: 'quarter_label',
            header: 'Quarter',
            render: (r: QuarterlyRow) => r.quarter_label,
          },
          {
            key: 'avg_our_share_pct',
            header: 'Avg share',
            render: (r: QuarterlyRow) => pct(r.avg_our_share_pct),
          },
          {
            key: 'total_revenue_rupees',
            header: 'Revenue',
            render: (r: QuarterlyRow) => inr(r.total_revenue_rupees),
          },
          {
            key: 'avg_growth_yoy_pct',
            header: 'Avg YoY',
            render: (r: QuarterlyRow) => pct(r.avg_growth_yoy_pct),
          },
        ]}
      />

      {/* Monthly trend */}
      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
        Monthly win/loss trend
      </h2>
      <DataTable
        rows={monthly}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.month_start ?? i)}
        columns={[
          { key: 'month_start', header: 'Month', render: (r: MonthlyRow) => r.month_start },
          { key: 'wins', header: 'Wins', render: (r: MonthlyRow) => r.wins },
          { key: 'losses', header: 'Losses', render: (r: MonthlyRow) => r.losses },
          {
            key: 'net_revenue_rupees',
            header: 'Net rev',
            render: (r: MonthlyRow) => inr(r.net_revenue_rupees),
          },
        ]}
      />

      {/* Owner load */}
      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
        Owner load
      </h2>
      <DataTable
        rows={owners}
        emptyMessage="No data"
        rowKey={(r, i) => String(r.owner_email ?? i)}
        columns={[
          { key: 'owner_email', header: 'Owner', render: (r: OwnerRow) => r.owner_email },
          {
            key: 'vertical_count',
            header: 'Verticals',
            render: (r: OwnerRow) => r.vertical_count,
          },
          {
            key: 'total_revenue_rupees',
            header: 'Revenue',
            render: (r: OwnerRow) => inr(r.total_revenue_rupees),
          },
          {
            key: 'losing_count',
            header: 'Losing',
            render: (r: OwnerRow) => r.losing_count,
          },
        ]}
      />

      {/* Recent events */}
      <h2 style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
        Recent win/loss events
      </h2>
      <DataTable
        rows={events}
        emptyMessage="No data"
        rowKey={(r, i) => String(i)}
        columns={[
          { key: 'occurred_on', header: 'Date', render: (r: EventRow) => r.occurred_on },
          { key: 'vertical', header: 'Vertical', render: (r: EventRow) => r.vertical },
          { key: 'event_type', header: 'Type', render: (r: EventRow) => r.event_type },
          { key: 'account_name', header: 'Account', render: (r: EventRow) => r.account_name },
          {
            key: 'account_size_rupees',
            header: 'Size',
            render: (r: EventRow) => inr(r.account_size_rupees),
          },
          {
            key: 'competitor_name',
            header: 'Competitor',
            render: (r: EventRow) => r.competitor_name ?? '-',
          },
          { key: 'reason', header: 'Reason', render: (r: EventRow) => r.reason ?? '-' },
          {
            key: 'owner_email',
            header: 'Owner',
            render: (r: EventRow) => r.owner_email ?? '-',
          },
        ]}
      />
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: 10,
        padding: 14,
        background: '#fff',
      }}
    >
      <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>
        {label}
      </div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
