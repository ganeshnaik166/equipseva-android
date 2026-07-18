import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { experiment_verdict: string; experiments: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_experiments: number;
  wins: number;
  losses: number;
  guardrail_breaches: number;
  rollouts: number;
  rollbacks: number;
  avg_discount_pct: number;
  win_pct: number;
};
type MatrixRow = {
  customer_segment: string;
  service_line: string;
  experiments: number;
  wins: number;
  avg_discount_pct: number;
  total_revenue_delta_rupees: number;
};
type TrendRow = {
  experiment_start_date: string;
  experiments: number;
  wins: number;
  guardrail_breaches: number;
  avg_margin_impact_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  experiment_code: string;
  experiment_name: string;
  customer_segment: string;
  discount_pct: number;
  margin_impact_pct: number | null;
  guardrail_type: string | null;
  decision: string;
  experiment_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3237_verdict_rollup'),
    supabase.rpc('founder_r3237_hospital_scorecard'),
    supabase.rpc('founder_r3237_segment_service_matrix'),
    supabase.rpc('founder_r3237_daily_trend'),
    supabase.rpc('founder_r3237_capa_status_board'),
    supabase.rpc('founder_r3237_root_cause_pareto'),
    supabase.rpc('founder_r3237_regulatory_impact_digest'),
    supabase.rpc('founder_r3237_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'experiment_verdict', header: 'Verdict' },
    { key: 'experiments', header: 'Experiments' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_experiments', header: 'Experiments' },
    { key: 'wins', header: 'Wins' },
    { key: 'losses', header: 'Losses' },
    { key: 'guardrail_breaches', header: 'Guardrail Breaches' },
    { key: 'rollouts', header: 'Rollouts' },
    { key: 'rollbacks', header: 'Rollbacks' },
    { key: 'avg_discount_pct', header: 'Avg Discount %' },
    { key: 'win_pct', header: 'Win %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'service_line', header: 'Service Line' },
    { key: 'experiments', header: 'Experiments' },
    { key: 'wins', header: 'Wins' },
    { key: 'avg_discount_pct', header: 'Avg Discount %' },
    { key: 'total_revenue_delta_rupees', header: 'Revenue Delta (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'experiment_start_date', header: 'Start Date' },
    { key: 'experiments', header: 'Experiments' },
    { key: 'wins', header: 'Wins' },
    { key: 'guardrail_breaches', header: 'Guardrail Breaches' },
    { key: 'avg_margin_impact_pct', header: 'Avg Margin Impact %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Governance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'experiment_code', header: 'Code' },
    { key: 'experiment_name', header: 'Experiment' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'discount_pct', header: 'Discount %' },
    { key: 'margin_impact_pct', header: 'Margin Impact %' },
    { key: 'guardrail_type', header: 'Guardrail' },
    { key: 'decision', header: 'Decision' },
    { key: 'experiment_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Pricing-Experiment &amp; Discount-Guardrail Outcome Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Pricing board — experiment &times; segment &times; control/test price &times; discount &times;
        take-rate delta &times; revenue delta &times; margin impact &amp; guardrail breaches with CAPA closure.
        Founder-gated view: verdict rollups, hospital scorecards, segment matrix, root-cause pareto,
        and governance-impact digest across rollout / rollback / iterate decisions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Experiment verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No experiments logged yet."
          rowKey={(r, i) => String(r.experiment_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital pricing scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; service-line matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => `${r.customer_segment}-${r.service_line}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Experiment start-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.experiment_start_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Governance impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No governance-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk experiment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk experiments."
          rowKey={(r, i) => `${r.experiment_code}-${i}`}
        />
      </section>
    </main>
  );
}
