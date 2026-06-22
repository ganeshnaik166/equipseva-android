import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Scorecard = {
  id: string;
  chain_name: string;
  quarter_label: string;
  period_start: string;
  period_end: string;
  jobs_completed: number;
  jobs_cancelled: number;
  nps_score: number;
  nps_responses: number;
  active_units: number;
  amc_units: number;
  amc_penetration_pct: number;
  complaints_count: number;
  complaints_resolved: number;
  revenue_rupees: number;
  revenue_prev_rupees: number;
  revenue_trend_pct: number;
  health_grade: string;
  notes_md: string;
  generated_at: string;
  review_count: number;
};

type Rollup = {
  chain_name: string;
  quarters_tracked: number;
  latest_quarter: string;
  latest_jobs: number;
  latest_nps: number;
  latest_amc_penetration_pct: number;
  latest_complaints: number;
  latest_revenue_rupees: number;
  latest_revenue_trend_pct: number;
  latest_grade: string;
};

type AtRisk = {
  id: string;
  chain_name: string;
  quarter_label: string;
  health_grade: string;
  nps_score: number;
  amc_penetration_pct: number;
  complaints_count: number;
  revenue_trend_pct: number;
  revenue_rupees: number;
  risk_score: number;
};

type Summary = {
  total_scorecards: number;
  chains_tracked: number;
  quarters_tracked: number;
  avg_nps: number;
  avg_amc_penetration_pct: number;
  total_revenue_rupees: number;
  grade_a_count: number;
  grade_b_count: number;
  grade_c_count: number;
  grade_d_count: number;
  grade_f_count: number;
};

function inr(n: number): string {
  if (!n || n <= 0) return 'Rs 0';
  if (n >= 10000000) return `Rs ${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `Rs ${(n / 100000).toFixed(2)} L`;
  return `Rs ${n.toLocaleString('en-IN')}`;
}

function trendArrow(pct: number): string {
  if (pct > 0) return `up ${pct.toFixed(1)}%`;
  if (pct < 0) return `down ${Math.abs(pct).toFixed(1)}%`;
  return 'flat';
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [scorecardsRes, rollupRes, atRiskRes, summaryRes] = await Promise.all([
    sb.rpc('list_chain_scorecards_r2303'),
    sb.rpc('chain_scorecard_rollup_r2303'),
    sb.rpc('chain_scorecard_at_risk_r2303'),
    sb.rpc('chain_scorecard_program_summary_r2303'),
  ]);

  const scorecards: Scorecard[] = (scorecardsRes.data ?? []) as Scorecard[];
  const rollup: Rollup[] = (rollupRes.data ?? []) as Rollup[];
  const atRisk: AtRisk[] = (atRiskRes.data ?? []) as AtRisk[];
  const summary: Summary = ((summaryRes.data ?? [])[0] ?? {
    total_scorecards: 0,
    chains_tracked: 0,
    quarters_tracked: 0,
    avg_nps: 0,
    avg_amc_penetration_pct: 0,
    total_revenue_rupees: 0,
    grade_a_count: 0,
    grade_b_count: 0,
    grade_c_count: 0,
    grade_d_count: 0,
    grade_f_count: 0,
  }) as Summary;

  const scorecardCols: Column<Scorecard>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'period', header: 'Period', render: (r: any) => `${r.period_start} -> ${r.period_end}` },
    { key: 'jobs', header: 'Jobs (done / cancel)', render: (r: any) => `${r.jobs_completed} / ${r.jobs_cancelled}` },
    { key: 'nps', header: 'NPS', render: (r: any) => `${Number(r.nps_score).toFixed(1)} (n=${r.nps_responses})` },
    { key: 'amc', header: 'AMC pen.', render: (r: any) => `${Number(r.amc_penetration_pct).toFixed(1)}% (${r.amc_units}/${r.active_units})` },
    { key: 'complaints', header: 'Complaints', render: (r: any) => `${r.complaints_count} (${r.complaints_resolved} resolved)` },
    { key: 'revenue', header: 'Revenue', render: (r: any) => inr(r.revenue_rupees) },
    { key: 'trend', header: 'Trend vs prev Q', render: (r: any) => trendArrow(Number(r.revenue_trend_pct)) },
    { key: 'grade', header: 'Grade', render: (r: any) => r.health_grade },
    { key: 'reviews', header: 'Reviews', render: (r: any) => String(r.review_count) },
  ];

  const rollupCols: Column<Rollup>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'qtrs', header: 'Quarters tracked', render: (r: any) => String(r.quarters_tracked) },
    { key: 'latest', header: 'Latest quarter', render: (r: any) => r.latest_quarter },
    { key: 'jobs', header: 'Latest jobs', render: (r: any) => String(r.latest_jobs) },
    { key: 'nps', header: 'Latest NPS', render: (r: any) => Number(r.latest_nps).toFixed(1) },
    { key: 'amc', header: 'AMC pen.', render: (r: any) => `${Number(r.latest_amc_penetration_pct).toFixed(1)}%` },
    { key: 'complaints', header: 'Complaints', render: (r: any) => String(r.latest_complaints) },
    { key: 'revenue', header: 'Revenue', render: (r: any) => inr(r.latest_revenue_rupees) },
    { key: 'trend', header: 'Trend', render: (r: any) => trendArrow(Number(r.latest_revenue_trend_pct)) },
    { key: 'grade', header: 'Grade', render: (r: any) => r.latest_grade },
  ];

  const atRiskCols: Column<AtRisk>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'grade', header: 'Grade', render: (r: any) => r.health_grade },
    { key: 'nps', header: 'NPS', render: (r: any) => Number(r.nps_score).toFixed(1) },
    { key: 'amc', header: 'AMC pen.', render: (r: any) => `${Number(r.amc_penetration_pct).toFixed(1)}%` },
    { key: 'complaints', header: 'Complaints', render: (r: any) => String(r.complaints_count) },
    { key: 'trend', header: 'Trend', render: (r: any) => trendArrow(Number(r.revenue_trend_pct)) },
    { key: 'revenue', header: 'Revenue', render: (r: any) => inr(r.revenue_rupees) },
    { key: 'risk', header: 'Risk score', render: (r: any) => Number(r.risk_score).toFixed(1) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Executive Scorecard</h1>
        <p className="text-sm text-gray-500">r2303 · per-chain quarterly view of jobs, NPS, AMC penetration, complaints & revenue trend</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total scorecards</div>
          <div className="text-2xl font-semibold">{summary.total_scorecards}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Chains tracked</div>
          <div className="text-2xl font-semibold">{summary.chains_tracked}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Quarters tracked</div>
          <div className="text-2xl font-semibold">{summary.quarters_tracked}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total revenue</div>
          <div className="text-2xl font-semibold">{inr(summary.total_revenue_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg NPS</div>
          <div className="text-2xl font-semibold">{Number(summary.avg_nps).toFixed(1)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg AMC pen.</div>
          <div className="text-2xl font-semibold">{Number(summary.avg_amc_penetration_pct).toFixed(1)}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">A & B grade</div>
          <div className="text-2xl font-semibold text-green-600">{summary.grade_a_count + summary.grade_b_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">D & F grade</div>
          <div className="text-2xl font-semibold text-red-600">{summary.grade_d_count + summary.grade_f_count}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">At-risk chains (grade C/D/F or NPS &lt; 40 or revenue trending &lt;= 0)</h2>
        <DataTable rowKey={(r: AtRisk) => r.id} rows={atRisk} columns={atRiskCols} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Chain rollup (latest quarter per chain)</h2>
        <DataTable rowKey={(r: Rollup) => r.chain_name} rows={rollup} columns={rollupCols} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All quarterly scorecards</h2>
        <DataTable rowKey={(r: Scorecard) => r.id} rows={scorecards} columns={scorecardCols} />
      </section>
    </main>
  );
}
