import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { treasury_verdict: string; instruments: number; total_amount_rupees: number; pct: number };
type ScoreRow = {
  instrument_type: string;
  instruments: number;
  total_amount_rupees: number;
  avg_yield_pct: number;
  avg_benchmark_pct: number;
  below_benchmark: number;
  policy_breaches: number;
  above_benchmark_pct: number;
};
type MatrixRow = { liquidity_tier: string; credit_rating: string; instruments: number; total_amount_rupees: number; avg_yield_pct: number };
type TrendRow = { maturity_month: string; instruments: number; total_amount_rupees: number; avg_yield_pct: number };
type CapaRow = { capa_status: string; findings: number; avg_uplift_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_uplift_rupees: number; pct: number };
type ImpactRow = { financial_impact: string; findings: number; open_findings: number; total_uplift_rupees: number };
type RiskRow = {
  instrument_name: string;
  instrument_type: string;
  bank_or_amc: string;
  amount_rupees: number;
  yield_pct: number;
  benchmark_yield_pct: number;
  credit_rating: string;
  days_to_maturity: number;
  treasury_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, impactRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3401_treasury_verdict_rollup'),
    supabase.rpc('founder_r3401_type_scorecard'),
    supabase.rpc('founder_r3401_liquidity_rating_matrix'),
    supabase.rpc('founder_r3401_maturity_runway_trend'),
    supabase.rpc('founder_r3401_capa_status_board'),
    supabase.rpc('founder_r3401_root_cause_pareto'),
    supabase.rpc('founder_r3401_financial_impact_digest'),
    supabase.rpc('founder_r3401_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'treasury_verdict', header: 'Treasury Verdict' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_amount_rupees', header: 'Amount (INR)' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'instrument_type', header: 'Instrument Type' },
    { key: 'instruments', header: 'Count' },
    { key: 'total_amount_rupees', header: 'Amount (INR)' },
    { key: 'avg_yield_pct', header: 'Avg Yield %' },
    { key: 'avg_benchmark_pct', header: 'Avg Benchmark %' },
    { key: 'below_benchmark', header: 'Below Bench' },
    { key: 'policy_breaches', header: 'Policy Breaches' },
    { key: 'above_benchmark_pct', header: 'Above Bench %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'liquidity_tier', header: 'Liquidity Tier' },
    { key: 'credit_rating', header: 'Credit Rating' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_amount_rupees', header: 'Amount (INR)' },
    { key: 'avg_yield_pct', header: 'Avg Yield %' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'maturity_month', header: 'Maturity Month' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_amount_rupees', header: 'Amount (INR)' },
    { key: 'avg_yield_pct', header: 'Avg Yield %' },
  ];
  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_uplift_rupees', header: 'Avg Uplift (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];
  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_uplift_rupees', header: 'Total Uplift (INR)' },
    { key: 'pct', header: 'Share %' },
  ];
  const impactCols: Column<ImpactRow>[] = [
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_uplift_rupees', header: 'Total Uplift (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'instrument_name', header: 'Instrument' },
    { key: 'instrument_type', header: 'Type' },
    { key: 'bank_or_amc', header: 'Bank/AMC' },
    { key: 'amount_rupees', header: 'Amount (INR)' },
    { key: 'yield_pct', header: 'Yield %' },
    { key: 'benchmark_yield_pct', header: 'Benchmark %' },
    { key: 'credit_rating', header: 'Rating' },
    { key: 'days_to_maturity', header: 'Days to Maturity' },
    { key: 'treasury_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Treasury Surplus-Fund / Short-Term Investment-Policy &amp; FD-Ladder Yield Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Surplus-fund deployment &mdash; instrument type &times; bank/AMC &times; amount &times; tenor &times;
        yield vs benchmark &times; liquidity tier &times; credit rating &times; policy compliance &times;
        concentration &amp; CAPA. Founder-gated view: treasury-verdict rollup, instrument-type scorecard,
        liquidity &times; rating matrix, maturity-runway trend, and policy-breach/low-yield queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Treasury verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No instruments yet." rowKey={(r, i) => String(r.treasury_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Instrument-type scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No type rollups." rowKey={(r, i) => String(r.instrument_type ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Liquidity &times; credit-rating matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.liquidity_tier}-${r.credit_rating}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Maturity-runway trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.maturity_month ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact digest</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No financial-impact rollups." rowKey={(r, i) => String(r.financial_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Policy-breach / low-yield queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No at-risk instruments." rowKey={(r, i) => `${r.instrument_name}-${i}`} />
      </section>
    </main>
  );
}
