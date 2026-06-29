import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: string };
type ScoreRow = {
  id: string;
  engineer_id: string;
  month_key: string;
  total_jobs: number;
  unique_hospitals: number;
  repeat_request_count: number;
  repeat_ratio: number;
  avg_csat: number;
  bonus_score: number;
  bonus_payout_rupees: number;
  tier_band: string;
  notes: string | null;
};
type TierRow = { tier_band: string; engineer_count: number; total_bonus: number; avg_csat: number };
type EventRow = {
  id: string;
  engineer_id: string;
  hospital_name: string;
  days_since_last_visit: number;
  requested_by_name: string | null;
  request_channel: string;
  csat_prior: number | null;
  bonus_credited_rupees: number;
  status: string;
  created_at: string;
};
type ChannelRow = { request_channel: string; event_count: number; avg_days_since_last: number; avg_prior_csat: number };
type MomRow = { month_key: string; engineer_count: number; avg_repeat_ratio: number; avg_bonus_score: number; total_payout: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpi, top, tiers, events, channels, mom, watch] = await Promise.all([
    supabase.rpc('r2890_kpi_summary'),
    supabase.rpc('r2890_top_engineers'),
    supabase.rpc('r2890_tier_distribution'),
    supabase.rpc('r2890_recent_repeat_events'),
    supabase.rpc('r2890_channel_breakdown'),
    supabase.rpc('r2890_month_over_month'),
    supabase.rpc('r2890_coaching_watchlist'),
  ]);

  const kpiRows: KpiRow[] = (kpi.data as KpiRow[]) ?? [];
  const topRows: ScoreRow[] = (top.data as ScoreRow[]) ?? [];
  const tierRows: TierRow[] = (tiers.data as TierRow[]) ?? [];
  const eventRows: EventRow[] = (events.data as EventRow[]) ?? [];
  const channelRows: ChannelRow[] = (channels.data as ChannelRow[]) ?? [];
  const momRows: MomRow[] = (mom.data as MomRow[]) ?? [];
  const watchRows: ScoreRow[] = (watch.data as ScoreRow[]) ?? [];

  const kpiCard = (label: string, value: string) => (
    <div key={label} className="rounded-lg border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label.replace(/_/g, ' ')}</div>
      <div className="mt-1 text-2xl font-semibold text-neutral-900">{value}</div>
    </div>
  );

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'engineer_id', header: 'Engineer', render: (r) => <span className="font-mono text-xs">{r.engineer_id.slice(0, 8)}</span> },
    { key: 'month_key', header: 'Month' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'unique_hospitals', header: 'Hospitals' },
    { key: 'repeat_request_count', header: 'Repeats' },
    { key: 'repeat_ratio', header: 'Repeat %', render: (r) => `${r.repeat_ratio}%` },
    { key: 'avg_csat', header: 'CSAT' },
    { key: 'bonus_score', header: 'Score' },
    { key: 'bonus_payout_rupees', header: 'Bonus ₹', render: (r) => `₹${r.bonus_payout_rupees.toLocaleString('en-IN')}` },
    { key: 'tier_band', header: 'Tier' },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'tier_band', header: 'Tier' },
    { key: 'engineer_count', header: 'Engineers' },
    { key: 'total_bonus', header: 'Total Bonus ₹', render: (r) => `₹${Number(r.total_bonus).toLocaleString('en-IN')}` },
    { key: 'avg_csat', header: 'Avg CSAT' },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'requested_by_name', header: 'Requested By', render: (r) => r.requested_by_name ?? '—' },
    { key: 'request_channel', header: 'Channel' },
    { key: 'days_since_last_visit', header: 'Days Since Last' },
    { key: 'csat_prior', header: 'Prior CSAT', render: (r) => (r.csat_prior ?? '—').toString() },
    { key: 'bonus_credited_rupees', header: 'Bonus ₹', render: (r) => `₹${r.bonus_credited_rupees}` },
    { key: 'status', header: 'Status' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'request_channel', header: 'Channel' },
    { key: 'event_count', header: 'Events' },
    { key: 'avg_days_since_last', header: 'Avg Days Since Last' },
    { key: 'avg_prior_csat', header: 'Avg Prior CSAT' },
  ];

  const momCols: Column<MomRow>[] = [
    { key: 'month_key', header: 'Month' },
    { key: 'engineer_count', header: 'Engineers' },
    { key: 'avg_repeat_ratio', header: 'Avg Repeat %', render: (r) => `${r.avg_repeat_ratio}%` },
    { key: 'avg_bonus_score', header: 'Avg Score' },
    { key: 'total_payout', header: 'Total Payout ₹', render: (r) => `₹${Number(r.total_payout).toLocaleString('en-IN')}` },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold text-neutral-900">Engineer Monthly Customer Repeat-Request Bonus Score</h1>
        <p className="text-sm text-neutral-600">
          Founder accountability scorecard — measures how often hospitals explicitly re-request the same engineer back month-over-month, then attaches a tiered bonus payout. Repeat ratio &gt;= 50% =&gt; platinum band.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-700">KPI Summary</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
          {kpiRows.map((r) => kpiCard(r.metric, r.value))}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-700">Top Engineers — Current Month</h2>
        <DataTable
          rows={topRows}
          columns={scoreCols}
          emptyMessage="No scored engineers this month."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-700">Tier Distribution</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier data."
          rowKey={(r, i) => String(r.tier_band ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-700">Recent Verified Repeat Requests</h2>
        <DataTable
          rows={eventRows}
          columns={eventCols}
          emptyMessage="No repeat events recorded."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-700">Request Channel Breakdown</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No channel telemetry."
          rowKey={(r, i) => String(r.request_channel ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-700">Month-over-Month Trend</h2>
        <DataTable
          rows={momRows}
          columns={momCols}
          emptyMessage="No historical months."
          rowKey={(r, i) => String(r.month_key ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-neutral-700">Coaching Watchlist — Bronze or CSAT &lt; 4.30</h2>
        <DataTable
          rows={watchRows}
          columns={scoreCols}
          emptyMessage="No engineers flagged for coaching."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
