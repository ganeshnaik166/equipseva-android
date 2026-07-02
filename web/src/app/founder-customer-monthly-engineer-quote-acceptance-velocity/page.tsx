import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_quotes_sent: number;
  total_quotes_accepted: number;
  acceptance_rate_pct: number;
  avg_time_to_accept_hours: number;
  avg_discount_pct: number;
  total_accepted_value_rupees: number;
  avg_refine_iterations: number;
};

type LeaderboardRow = {
  engineer_name: string;
  engineer_tier: string;
  quotes_sent: number;
  quotes_accepted: number;
  acceptance_rate_pct: number;
  avg_time_to_accept_hours: number;
  total_accepted_value_rupees: number;
  velocity_band: string;
};

type BandRow = {
  velocity_band: string;
  engineer_count: number;
  total_quotes_accepted: number;
  share_of_accepted_pct: number;
};

type EventRow = {
  quote_ref: string;
  engineer_name: string;
  customer_name: string;
  outcome: string;
  initial_amount_rupees: number;
  final_amount_rupees: number;
  discount_pct: number;
  refine_count: number;
  time_to_respond_hours: number;
  sent_at: string;
};

type RefineRow = {
  refine_count: number;
  quote_count: number;
  accepted_count: number;
  acceptance_rate_pct: number;
  avg_discount_pct: number;
};

type TrendRow = {
  month_start: string;
  total_sent: number;
  total_accepted: number;
  acceptance_rate_pct: number;
  avg_time_to_accept_hours: number;
  total_accepted_value_rupees: number;
};

type TierRow = {
  engineer_tier: string;
  engineer_count: number;
  total_sent: number;
  total_accepted: number;
  acceptance_rate_pct: number;
  avg_discount_pct: number;
  total_accepted_value_rupees: number;
};

type StalledRow = {
  engineer_name: string;
  engineer_tier: string;
  quotes_sent: number;
  quotes_accepted: number;
  avg_time_to_accept_hours: number;
  median_discount_pct: number;
  refine_iterations_avg: number;
};

function fmtINR(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined, digits = 2) {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(digits);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpisRes,
    leaderboardRes,
    bandsRes,
    eventsRes,
    refineRes,
    trendRes,
    tierRes,
    stalledRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2872_quote_velocity_kpis'),
    supabase.rpc('founder_r2872_engineer_leaderboard'),
    supabase.rpc('founder_r2872_velocity_band_distribution'),
    supabase.rpc('founder_r2872_recent_quote_events'),
    supabase.rpc('founder_r2872_refine_impact'),
    supabase.rpc('founder_r2872_mom_trend'),
    supabase.rpc('founder_r2872_tier_rollup'),
    supabase.rpc('founder_r2872_stalled_engineers'),
  ]);

  const kpis: Kpis | null = Array.isArray(kpisRes.data) ? (kpisRes.data[0] as Kpis) : null;
  const leaderboard: LeaderboardRow[] = (leaderboardRes.data as LeaderboardRow[]) ?? [];
  const bands: BandRow[] = (bandsRes.data as BandRow[]) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[]) ?? [];
  const refine: RefineRow[] = (refineRes.data as RefineRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const tier: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const stalled: StalledRow[] = (stalledRes.data as StalledRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer — Monthly Engineer Quote Acceptance Velocity</h1>
        <p className="text-sm text-gray-600 mt-1">
          Engineer quote throughput: sent, accepted, time-to-accept, discount, refine iterations. Round r2872.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Quotes Sent</div>
          <div className="text-2xl font-semibold">{kpis?.total_quotes_sent ?? 0}</div>
        </div>
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Quotes Accepted</div>
          <div className="text-2xl font-semibold">{kpis?.total_quotes_accepted ?? 0}</div>
        </div>
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Acceptance Rate</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.acceptance_rate_pct, 2)}%</div>
        </div>
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Avg Time-to-Accept</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.avg_time_to_accept_hours, 2)} h</div>
        </div>
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Avg Discount</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.avg_discount_pct, 2)}%</div>
        </div>
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Accepted Value</div>
          <div className="text-2xl font-semibold">{fmtINR(kpis?.total_accepted_value_rupees)}</div>
        </div>
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Avg Refines</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.avg_refine_iterations, 2)}</div>
        </div>
        <div className="rounded-xl border p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Engineers Tracked</div>
          <div className="text-2xl font-semibold">{leaderboard.length}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Engineer Leaderboard (latest month)</h2>
        <DataTable
          rows={leaderboard}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: LeaderboardRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: LeaderboardRow) => r.engineer_tier },
            { key: 'quotes_sent', header: 'Sent', render: (r: LeaderboardRow) => r.quotes_sent },
            { key: 'quotes_accepted', header: 'Accepted', render: (r: LeaderboardRow) => r.quotes_accepted },
            { key: 'acceptance_rate_pct', header: 'Accept %', render: (r: LeaderboardRow) => fmtNum(r.acceptance_rate_pct, 2) + '%' },
            { key: 'avg_time_to_accept_hours', header: 'Avg TTA (h)', render: (r: LeaderboardRow) => fmtNum(r.avg_time_to_accept_hours, 2) },
            { key: 'total_accepted_value_rupees', header: 'Accepted Value', render: (r: LeaderboardRow) => fmtINR(r.total_accepted_value_rupees) },
            { key: 'velocity_band', header: 'Band', render: (r: LeaderboardRow) => r.velocity_band },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeaderboardRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-3">Velocity Band Distribution</h2>
          <DataTable
            rows={bands}
            columns={[
              { key: 'velocity_band', header: 'Band', render: (r: BandRow) => r.velocity_band },
              { key: 'engineer_count', header: 'Engineers', render: (r: BandRow) => r.engineer_count },
              { key: 'total_quotes_accepted', header: 'Accepted', render: (r: BandRow) => r.total_quotes_accepted },
              { key: 'share_of_accepted_pct', header: 'Share %', render: (r: BandRow) => fmtNum(r.share_of_accepted_pct, 2) + '%' },
            ]}
            emptyMessage="No data"
            rowKey={(r: BandRow, i: number) => String(r.velocity_band ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-3">Tier Rollup</h2>
          <DataTable
            rows={tier}
            columns={[
              { key: 'engineer_tier', header: 'Tier', render: (r: TierRow) => r.engineer_tier },
              { key: 'engineer_count', header: 'Engineers', render: (r: TierRow) => r.engineer_count },
              { key: 'total_sent', header: 'Sent', render: (r: TierRow) => r.total_sent },
              { key: 'total_accepted', header: 'Accepted', render: (r: TierRow) => r.total_accepted },
              { key: 'acceptance_rate_pct', header: 'Accept %', render: (r: TierRow) => fmtNum(r.acceptance_rate_pct, 2) + '%' },
              { key: 'avg_discount_pct', header: 'Avg Disc %', render: (r: TierRow) => fmtNum(r.avg_discount_pct, 2) + '%' },
              { key: 'total_accepted_value_rupees', header: 'Accepted Value', render: (r: TierRow) => fmtINR(r.total_accepted_value_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: TierRow, i: number) => String(r.engineer_tier ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Refine Iteration Impact (more refines → lower acceptance?)</h2>
        <DataTable
          rows={refine}
          columns={[
            { key: 'refine_count', header: 'Refines', render: (r: RefineRow) => r.refine_count },
            { key: 'quote_count', header: 'Quotes', render: (r: RefineRow) => r.quote_count },
            { key: 'accepted_count', header: 'Accepted', render: (r: RefineRow) => r.accepted_count },
            { key: 'acceptance_rate_pct', header: 'Accept %', render: (r: RefineRow) => fmtNum(r.acceptance_rate_pct, 2) + '%' },
            { key: 'avg_discount_pct', header: 'Avg Disc %', render: (r: RefineRow) => fmtNum(r.avg_discount_pct, 2) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RefineRow, i: number) => String(r.refine_count ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Month-over-Month Trend</h2>
        <DataTable
          rows={trend}
          columns={[
            { key: 'month_start', header: 'Month', render: (r: TrendRow) => String(r.month_start).slice(0,7) },
            { key: 'total_sent', header: 'Sent', render: (r: TrendRow) => r.total_sent },
            { key: 'total_accepted', header: 'Accepted', render: (r: TrendRow) => r.total_accepted },
            { key: 'acceptance_rate_pct', header: 'Accept %', render: (r: TrendRow) => fmtNum(r.acceptance_rate_pct, 2) + '%' },
            { key: 'avg_time_to_accept_hours', header: 'Avg TTA (h)', render: (r: TrendRow) => fmtNum(r.avg_time_to_accept_hours, 2) },
            { key: 'total_accepted_value_rupees', header: 'Accepted Value', render: (r: TrendRow) => fmtINR(r.total_accepted_value_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TrendRow, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Stalled Engineers (intervention list)</h2>
        <p className="text-sm text-gray-600 mb-3">
          Engineers whose velocity band is slow or stalled this month. Review pricing, refine loop & SLA discipline.
        </p>
        <DataTable
          rows={stalled}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: StalledRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: StalledRow) => r.engineer_tier },
            { key: 'quotes_sent', header: 'Sent', render: (r: StalledRow) => r.quotes_sent },
            { key: 'quotes_accepted', header: 'Accepted', render: (r: StalledRow) => r.quotes_accepted },
            { key: 'avg_time_to_accept_hours', header: 'Avg TTA (h)', render: (r: StalledRow) => fmtNum(r.avg_time_to_accept_hours, 2) },
            { key: 'median_discount_pct', header: 'Median Disc %', render: (r: StalledRow) => fmtNum(r.median_discount_pct, 2) + '%' },
            { key: 'refine_iterations_avg', header: 'Avg Refines', render: (r: StalledRow) => fmtNum(r.refine_iterations_avg, 2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: StalledRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Quote Events</h2>
        <DataTable
          rows={events}
          columns={[
            { key: 'quote_ref', header: 'Quote', render: (r: EventRow) => r.quote_ref },
            { key: 'engineer_name', header: 'Engineer', render: (r: EventRow) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: EventRow) => r.customer_name },
            { key: 'outcome', header: 'Outcome', render: (r: EventRow) => r.outcome },
            { key: 'initial_amount_rupees', header: 'Initial', render: (r: EventRow) => fmtINR(r.initial_amount_rupees) },
            { key: 'final_amount_rupees', header: 'Final', render: (r: EventRow) => fmtINR(r.final_amount_rupees) },
            { key: 'discount_pct', header: 'Disc %', render: (r: EventRow) => fmtNum(r.discount_pct, 2) + '%' },
            { key: 'refine_count', header: 'Refines', render: (r: EventRow) => r.refine_count },
            { key: 'time_to_respond_hours', header: 'TTR (h)', render: (r: EventRow) => fmtNum(r.time_to_respond_hours, 2) },
            { key: 'sent_at', header: 'Sent', render: (r: EventRow) => new Date(r.sent_at).toLocaleString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: EventRow, i: number) => String(r.quote_ref ?? i)}
        />
      </section>
    </div>
  );
}
