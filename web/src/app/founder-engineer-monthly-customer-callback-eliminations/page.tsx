import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_cases: number;
  eliminated: number;
  recurring: number;
  avg_rate: number;
  total_callbacks: number;
};

type CaseRow = {
  id: string;
  month_key: string;
  engineer_code: string;
  engineer_name: string;
  current_tier: string;
  callback_count: number;
  callback_rate_pct: number;
  primary_root_cause: string;
  prevention_plan: string;
  outcome_status: string;
  tier_learning_tag: string;
  reduce_target_pct: number;
  reviewed_at: string;
};

type RootCauseRow = {
  root_cause: string;
  cases: number;
  callbacks: number;
  avg_rate: number;
};

type OutcomeRow = {
  outcome: string;
  cases: number;
  share_pct: number;
};

type TierRow = {
  id: string;
  month_key: string;
  tier: string;
  engineers_count: number;
  avg_callback_rate_pct: number;
  top_root_cause: string;
  shared_lesson: string;
  reduction_vs_prev_pct: number;
  playbook_url: string;
};

type RecurringRow = {
  engineer_code: string;
  engineer_name: string;
  tier: string;
  callback_count: number;
  callback_rate_pct: number;
  root_cause: string;
  outcome: string;
};

type TrendRow = {
  tier: string;
  month_key: string;
  avg_rate: number;
  reduction_vs_prev_pct: number;
  shared_lesson: string;
};

type PreventionRow = {
  engineer_code: string;
  engineer_name: string;
  tier: string;
  prevention_plan: string;
  tier_learning_tag: string;
  reduce_target_pct: number;
  outcome: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    casesRes,
    rootCauseRes,
    outcomeRes,
    tierRes,
    recurringRes,
    trendRes,
    preventionRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2782_callback_overview'),
    supabase.rpc('founder_r2782_list_cases'),
    supabase.rpc('founder_r2782_root_cause_breakdown'),
    supabase.rpc('founder_r2782_outcome_breakdown'),
    supabase.rpc('founder_r2782_tier_learning_current'),
    supabase.rpc('founder_r2782_top_recurring_engineers'),
    supabase.rpc('founder_r2782_tier_reduction_trend'),
    supabase.rpc('founder_r2782_prevention_inventory'),
  ]);

  const overview: Overview =
    (overviewRes.data as Overview[] | null)?.[0] ?? {
      total_cases: 0,
      eliminated: 0,
      recurring: 0,
      avg_rate: 0,
      total_callbacks: 0,
    };

  const cases: CaseRow[] = (casesRes.data as CaseRow[] | null) ?? [];
  const rootCauses: RootCauseRow[] = (rootCauseRes.data as RootCauseRow[] | null) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[] | null) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[] | null) ?? [];
  const recurring: RecurringRow[] = (recurringRes.data as RecurringRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];
  const prevention: PreventionRow[] = (preventionRes.data as PreventionRow[] | null) ?? [];

  const kpis = [
    { label: 'Total Cases', value: overview.total_cases },
    { label: 'Eliminated', value: overview.eliminated },
    { label: 'Recurring', value: overview.recurring },
    { label: 'Avg Callback Rate %', value: Number(overview.avg_rate).toFixed(2) },
    { label: 'Total Callbacks', value: overview.total_callbacks },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">
          Engineer Monthly Customer Callback Eliminations
        </h1>
        <p className="text-sm text-gray-600 mt-1">
          Track engineer x callback root-cause x prevention x outcome x tier
          learning to reduce callbacks month-over-month.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        {kpis.map((k) => (
          <div
            key={k.label}
            className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm"
          >
            <div className="text-xs uppercase tracking-wide text-gray-500">
              {k.label}
            </div>
            <div className="text-2xl font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Callback Cases</h2>
        <DataTable
          rows={cases}
          columns={[
            { key: 'month_key', header: 'Month', render: (r: CaseRow) => r.month_key },
            { key: 'engineer_code', header: 'Engineer', render: (r: CaseRow) => `${r.engineer_code} - ${r.engineer_name}` },
            { key: 'current_tier', header: 'Tier', render: (r: CaseRow) => r.current_tier },
            { key: 'callback_count', header: 'Callbacks', render: (r: CaseRow) => r.callback_count },
            { key: 'callback_rate_pct', header: 'Rate %', render: (r: CaseRow) => Number(r.callback_rate_pct).toFixed(2) },
            { key: 'primary_root_cause', header: 'Root Cause', render: (r: CaseRow) => r.primary_root_cause },
            { key: 'outcome_status', header: 'Outcome', render: (r: CaseRow) => r.outcome_status },
            { key: 'tier_learning_tag', header: 'Tier Learning', render: (r: CaseRow) => r.tier_learning_tag },
            { key: 'reduce_target_pct', header: 'Reduce Target %', render: (r: CaseRow) => Number(r.reduce_target_pct).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CaseRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Root Cause Breakdown</h2>
          <DataTable
            rows={rootCauses}
            columns={[
              { key: 'root_cause', header: 'Root Cause', render: (r: RootCauseRow) => r.root_cause },
              { key: 'cases', header: 'Cases', render: (r: RootCauseRow) => r.cases },
              { key: 'callbacks', header: 'Callbacks', render: (r: RootCauseRow) => r.callbacks },
              { key: 'avg_rate', header: 'Avg Rate %', render: (r: RootCauseRow) => Number(r.avg_rate).toFixed(2) },
            ]}
            emptyMessage="No data"
            rowKey={(r: RootCauseRow, i: number) => `${r.root_cause}-${i}`}
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Outcome Breakdown</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'cases', header: 'Cases', render: (r: OutcomeRow) => r.cases },
              { key: 'share_pct', header: 'Share %', render: (r: OutcomeRow) => Number(r.share_pct).toFixed(2) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => `${r.outcome}-${i}`}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">
          Tier Learning - Current Month
        </h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'tier', header: 'Tier', render: (r: TierRow) => r.tier },
            { key: 'engineers_count', header: 'Engineers', render: (r: TierRow) => r.engineers_count },
            { key: 'avg_callback_rate_pct', header: 'Avg Rate %', render: (r: TierRow) => Number(r.avg_callback_rate_pct).toFixed(2) },
            { key: 'top_root_cause', header: 'Top Root Cause', render: (r: TierRow) => r.top_root_cause },
            { key: 'shared_lesson', header: 'Shared Lesson', render: (r: TierRow) => r.shared_lesson },
            { key: 'reduction_vs_prev_pct', header: 'Reduction vs Prev %', render: (r: TierRow) => Number(r.reduction_vs_prev_pct).toFixed(2) },
            { key: 'playbook_url', header: 'Playbook', render: (r: TierRow) => r.playbook_url },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top Recurring Engineers</h2>
        <DataTable
          rows={recurring}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: RecurringRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: RecurringRow) => r.engineer_name },
            { key: 'tier', header: 'Tier', render: (r: RecurringRow) => r.tier },
            { key: 'callback_count', header: 'Callbacks', render: (r: RecurringRow) => r.callback_count },
            { key: 'callback_rate_pct', header: 'Rate %', render: (r: RecurringRow) => Number(r.callback_rate_pct).toFixed(2) },
            { key: 'root_cause', header: 'Root Cause', render: (r: RecurringRow) => r.root_cause },
            { key: 'outcome', header: 'Outcome', render: (r: RecurringRow) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: RecurringRow, i: number) => `${r.engineer_code}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Tier Reduction Trend</h2>
        <DataTable
          rows={trend}
          columns={[
            { key: 'tier', header: 'Tier', render: (r: TrendRow) => r.tier },
            { key: 'month_key', header: 'Month', render: (r: TrendRow) => r.month_key },
            { key: 'avg_rate', header: 'Avg Rate %', render: (r: TrendRow) => Number(r.avg_rate).toFixed(2) },
            { key: 'reduction_vs_prev_pct', header: 'Reduction vs Prev %', render: (r: TrendRow) => Number(r.reduction_vs_prev_pct).toFixed(2) },
            { key: 'shared_lesson', header: 'Shared Lesson', render: (r: TrendRow) => r.shared_lesson },
          ]}
          emptyMessage="No data"
          rowKey={(r: TrendRow, i: number) => `${r.tier}-${r.month_key}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Prevention Plan Inventory</h2>
        <DataTable
          rows={prevention}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: PreventionRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: PreventionRow) => r.engineer_name },
            { key: 'tier', header: 'Tier', render: (r: PreventionRow) => r.tier },
            { key: 'prevention_plan', header: 'Plan', render: (r: PreventionRow) => r.prevention_plan },
            { key: 'tier_learning_tag', header: 'Tag', render: (r: PreventionRow) => r.tier_learning_tag },
            { key: 'reduce_target_pct', header: 'Target %', render: (r: PreventionRow) => Number(r.reduce_target_pct).toFixed(2) },
            { key: 'outcome', header: 'Outcome', render: (r: PreventionRow) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: PreventionRow, i: number) => `${r.engineer_code}-${i}`}
        />
      </section>
    </div>
  );
}
