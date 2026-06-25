import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_arrivals: number;
  on_time_pct: number;
  avg_arrival_rating: number;
  avg_overall_rating: number;
  promoter_pct: number;
  detractor_pct: number;
  total_bonus_paid_rupees: number;
  engineers_on_probation: number;
};

type ArrivalRow = {
  id: string;
  month_label: string;
  arrival_date: string;
  job_code: string;
  customer_org: string;
  engineer_name: string;
  engineer_tier: string;
  arrival_punctuality_minutes: number;
  arrival_rating: number;
  service_rating: number;
  overall_rating: number;
  verbatim_quote: string;
  sentiment: string;
  pattern_tag: string;
  incentive_action: string;
  incentive_amount_rupees: number;
};

type RollupRow = {
  id: string;
  month_label: string;
  engineer_name: string;
  engineer_tier: string;
  total_arrivals: number;
  on_time_arrivals: number;
  late_arrivals: number;
  avg_arrival_rating: number;
  avg_overall_rating: number;
  promoter_count: number;
  detractor_count: number;
  dominant_pattern: string;
  policy_decision: string;
  monthly_bonus_rupees: number;
  founder_note: string;
};

type PatternRow = {
  pattern_tag: string;
  occurrences: number;
  avg_overall_rating: number;
  sentiment_skew: string;
};

type TierRow = {
  engineer_tier: string;
  engineers: number;
  avg_rating: number;
  total_bonus_rupees: number;
};

type ActionRow = {
  incentive_action: string;
  arrivals: number;
  total_payout_rupees: number;
};

type PromoterQuote = {
  engineer_name: string;
  customer_org: string;
  overall_rating: number;
  verbatim_quote: string;
  pattern_tag: string;
};

type DetractorRow = {
  engineer_name: string;
  customer_org: string;
  arrival_punctuality_minutes: number;
  overall_rating: number;
  verbatim_quote: string;
  incentive_action: string;
};

function inr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, feedRes, rollupRes, patternRes, tierRes, actionRes, promoterRes, detractorRes] = await Promise.all([
    supabase.rpc('founder_r2760_kpi_summary'),
    supabase.rpc('founder_r2760_arrival_feed'),
    supabase.rpc('founder_r2760_engineer_rollup'),
    supabase.rpc('founder_r2760_pattern_frequency'),
    supabase.rpc('founder_r2760_tier_mix'),
    supabase.rpc('founder_r2760_action_mix'),
    supabase.rpc('founder_r2760_top_promoter_quotes'),
    supabase.rpc('founder_r2760_detractor_watchlist'),
  ]);

  const kpi: Kpi = (Array.isArray(kpiRes.data) ? kpiRes.data[0] : kpiRes.data) ?? {
    total_arrivals: 0,
    on_time_pct: 0,
    avg_arrival_rating: 0,
    avg_overall_rating: 0,
    promoter_pct: 0,
    detractor_pct: 0,
    total_bonus_paid_rupees: 0,
    engineers_on_probation: 0,
  };

  const arrivals: ArrivalRow[] = (feedRes.data ?? []) as ArrivalRow[];
  const rollup: RollupRow[] = (rollupRes.data ?? []) as RollupRow[];
  const patterns: PatternRow[] = (patternRes.data ?? []) as PatternRow[];
  const tiers: TierRow[] = (tierRes.data ?? []) as TierRow[];
  const actions: ActionRow[] = (actionRes.data ?? []) as ActionRow[];
  const promoters: PromoterQuote[] = (promoterRes.data ?? []) as PromoterQuote[];
  const detractors: DetractorRow[] = (detractorRes.data ?? []) as DetractorRow[];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Arrival & Rating</h1>
        <p className="text-sm text-gray-600">
          Round r2760 — job × engineer × arrival rating × verbatim × pattern × incentive action.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total arrivals</div>
          <div className="text-2xl font-semibold">{kpi.total_arrivals}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">On-time % (arrival &lt;= 0 min late)</div>
          <div className="text-2xl font-semibold">{kpi.on_time_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg arrival rating</div>
          <div className="text-2xl font-semibold">{kpi.avg_arrival_rating}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg overall rating</div>
          <div className="text-2xl font-semibold">{kpi.avg_overall_rating}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Promoter %</div>
          <div className="text-2xl font-semibold">{kpi.promoter_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Detractor %</div>
          <div className="text-2xl font-semibold">{kpi.detractor_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Bonus paid this month</div>
          <div className="text-2xl font-semibold">{inr(kpi.total_bonus_paid_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">On probation / exit</div>
          <div className="text-2xl font-semibold">{kpi.engineers_on_probation}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Arrival rating feed</h2>
        <p className="text-xs text-gray-500 mb-2">
          Punctuality minutes: negative = early, 0 = on the dot, positive = late.
        </p>
        <DataTable
          rows={arrivals}
          columns={[
            { key: 'arrival_date', header: 'Date', render: (r: ArrivalRow) => r.arrival_date },
            { key: 'job_code', header: 'Job', render: (r: ArrivalRow) => r.job_code },
            { key: 'customer_org', header: 'Customer', render: (r: ArrivalRow) => r.customer_org },
            { key: 'engineer_name', header: 'Engineer', render: (r: ArrivalRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: ArrivalRow) => r.engineer_tier },
            { key: 'arrival_punctuality_minutes', header: 'Punctual (min)', render: (r: ArrivalRow) => String(r.arrival_punctuality_minutes) },
            { key: 'arrival_rating', header: 'Arrival', render: (r: ArrivalRow) => String(r.arrival_rating) },
            { key: 'overall_rating', header: 'Overall', render: (r: ArrivalRow) => String(r.overall_rating) },
            { key: 'sentiment', header: 'Sentiment', render: (r: ArrivalRow) => r.sentiment },
            { key: 'pattern_tag', header: 'Pattern', render: (r: ArrivalRow) => r.pattern_tag },
            { key: 'incentive_action', header: 'Action', render: (r: ArrivalRow) => r.incentive_action },
            { key: 'incentive_amount_rupees', header: 'Bonus', render: (r: ArrivalRow) => inr(r.incentive_amount_rupees) },
            { key: 'verbatim_quote', header: 'Verbatim', render: (r: ArrivalRow) => r.verbatim_quote },
          ]}
          emptyMessage="No data"
          rowKey={(r: ArrivalRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer monthly rollup & policy decision</h2>
        <DataTable
          rows={rollup}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RollupRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: RollupRow) => r.engineer_tier },
            { key: 'total_arrivals', header: 'Visits', render: (r: RollupRow) => String(r.total_arrivals) },
            { key: 'on_time_arrivals', header: 'On-time', render: (r: RollupRow) => String(r.on_time_arrivals) },
            { key: 'late_arrivals', header: 'Late', render: (r: RollupRow) => String(r.late_arrivals) },
            { key: 'avg_arrival_rating', header: 'Avg arrival', render: (r: RollupRow) => String(r.avg_arrival_rating) },
            { key: 'avg_overall_rating', header: 'Avg overall', render: (r: RollupRow) => String(r.avg_overall_rating) },
            { key: 'promoter_count', header: 'Promoters', render: (r: RollupRow) => String(r.promoter_count) },
            { key: 'detractor_count', header: 'Detractors', render: (r: RollupRow) => String(r.detractor_count) },
            { key: 'dominant_pattern', header: 'Pattern', render: (r: RollupRow) => r.dominant_pattern },
            { key: 'policy_decision', header: 'Decision', render: (r: RollupRow) => r.policy_decision },
            { key: 'monthly_bonus_rupees', header: 'Bonus', render: (r: RollupRow) => inr(r.monthly_bonus_rupees) },
            { key: 'founder_note', header: 'Founder note', render: (r: RollupRow) => r.founder_note },
          ]}
          emptyMessage="No data"
          rowKey={(r: RollupRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Pattern frequency</h2>
          <DataTable
            rows={patterns}
            columns={[
              { key: 'pattern_tag', header: 'Pattern', render: (r: PatternRow) => r.pattern_tag },
              { key: 'occurrences', header: 'Count', render: (r: PatternRow) => String(r.occurrences) },
              { key: 'avg_overall_rating', header: 'Avg overall', render: (r: PatternRow) => String(r.avg_overall_rating) },
              { key: 'sentiment_skew', header: 'Skew', render: (r: PatternRow) => r.sentiment_skew },
            ]}
            emptyMessage="No data"
            rowKey={(r: PatternRow, i: number) => String(r.pattern_tag ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Tier mix</h2>
          <DataTable
            rows={tiers}
            columns={[
              { key: 'engineer_tier', header: 'Tier', render: (r: TierRow) => r.engineer_tier },
              { key: 'engineers', header: 'Engineers', render: (r: TierRow) => String(r.engineers) },
              { key: 'avg_rating', header: 'Avg rating', render: (r: TierRow) => String(r.avg_rating) },
              { key: 'total_bonus_rupees', header: 'Bonus paid', render: (r: TierRow) => inr(r.total_bonus_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: TierRow, i: number) => String(r.engineer_tier ?? i)}
          />
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Incentive action mix</h2>
          <DataTable
            rows={actions}
            columns={[
              { key: 'incentive_action', header: 'Action', render: (r: ActionRow) => r.incentive_action },
              { key: 'arrivals', header: 'Arrivals', render: (r: ActionRow) => String(r.arrivals) },
              { key: 'total_payout_rupees', header: 'Total payout', render: (r: ActionRow) => inr(r.total_payout_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: ActionRow, i: number) => String(r.incentive_action ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Top promoter quotes</h2>
          <DataTable
            rows={promoters}
            columns={[
              { key: 'engineer_name', header: 'Engineer', render: (r: PromoterQuote) => r.engineer_name },
              { key: 'customer_org', header: 'Customer', render: (r: PromoterQuote) => r.customer_org },
              { key: 'overall_rating', header: 'Rating', render: (r: PromoterQuote) => String(r.overall_rating) },
              { key: 'pattern_tag', header: 'Pattern', render: (r: PromoterQuote) => r.pattern_tag },
              { key: 'verbatim_quote', header: 'Quote', render: (r: PromoterQuote) => r.verbatim_quote },
            ]}
            emptyMessage="No data"
            rowKey={(r: PromoterQuote, i: number) => String(i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Detractor watchlist</h2>
        <p className="text-xs text-gray-500 mb-2">
          Rating &lt;= passive threshold. Founder reviews each row before payroll cut-off.
        </p>
        <DataTable
          rows={detractors}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: DetractorRow) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: DetractorRow) => r.customer_org },
            { key: 'arrival_punctuality_minutes', header: 'Late (min)', render: (r: DetractorRow) => String(r.arrival_punctuality_minutes) },
            { key: 'overall_rating', header: 'Overall', render: (r: DetractorRow) => String(r.overall_rating) },
            { key: 'incentive_action', header: 'Action', render: (r: DetractorRow) => r.incentive_action },
            { key: 'verbatim_quote', header: 'Quote', render: (r: DetractorRow) => r.verbatim_quote },
          ]}
          emptyMessage="No data"
          rowKey={(r: DetractorRow, i: number) => String(i)}
        />
      </section>
    </div>
  );
}
