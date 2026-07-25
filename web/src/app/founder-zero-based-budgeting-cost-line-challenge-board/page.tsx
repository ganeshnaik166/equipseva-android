import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { zbb_verdict: string; cost_lines: number; pct: number };
type DeptRow = {
  owner_department: string;
  total_lines: number;
  approved_lean: number;
  challenged: number;
  cut_eliminated: number;
  discretionary_lines: number;
  weak_justification: number;
  prior_year_total_rupees: number;
  proposed_total_rupees: number;
  reduction_pct: number;
};
type MatrixRow = {
  cost_line: string;
  owner_department: string;
  lines: number;
  prior_year_total_rupees: number;
  proposed_total_rupees: number;
  avg_reduction_pct: number;
};
type TrendRow = {
  period_quarter: string;
  cost_lines: number;
  prior_year_total_rupees: number;
  proposed_total_rupees: number;
  reduction_total_rupees: number;
  avg_reduction_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_savings_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_rupees: number;
  pct: number;
};
type ImpactRow = {
  governance_impact: string;
  findings: number;
  open_findings: number;
  total_savings_rupees: number;
};
type RiskRow = {
  owner_department: string;
  cost_line: string;
  period_quarter: string;
  prior_year_spend_rupees: number;
  proposed_budget_rupees: number;
  reduction_pct: number;
  spend_classification: string;
  business_justification_strength: string;
  zbb_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3413_zbb_verdict_rollup'),
    supabase.rpc('founder_r3413_department_scorecard'),
    supabase.rpc('founder_r3413_cost_line_department_matrix'),
    supabase.rpc('founder_r3413_period_trend'),
    supabase.rpc('founder_r3413_capa_status_board'),
    supabase.rpc('founder_r3413_root_cause_pareto'),
    supabase.rpc('founder_r3413_governance_impact_digest'),
    supabase.rpc('founder_r3413_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'zbb_verdict', header: 'ZBB Verdict' },
    { key: 'cost_lines', header: 'Cost Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'owner_department', header: 'Owner Dept' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'approved_lean', header: 'Approved Lean' },
    { key: 'challenged', header: 'Challenged' },
    { key: 'cut_eliminated', header: 'Cut / Eliminated' },
    { key: 'discretionary_lines', header: 'Discretionary' },
    { key: 'weak_justification', header: 'Weak Justif.' },
    { key: 'prior_year_total_rupees', header: 'Prior Yr (INR)' },
    { key: 'proposed_total_rupees', header: 'Proposed (INR)' },
    { key: 'reduction_pct', header: 'Reduction %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'cost_line', header: 'Cost Line' },
    { key: 'owner_department', header: 'Owner Dept' },
    { key: 'lines', header: 'Lines' },
    { key: 'prior_year_total_rupees', header: 'Prior Yr (INR)' },
    { key: 'proposed_total_rupees', header: 'Proposed (INR)' },
    { key: 'avg_reduction_pct', header: 'Avg Reduction %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_quarter', header: 'Quarter' },
    { key: 'cost_lines', header: 'Cost Lines' },
    { key: 'prior_year_total_rupees', header: 'Prior Yr (INR)' },
    { key: 'proposed_total_rupees', header: 'Proposed (INR)' },
    { key: 'reduction_total_rupees', header: 'Reduction (INR)' },
    { key: 'avg_reduction_pct', header: 'Avg Reduction %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_savings_rupees', header: 'Avg Savings (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'governance_impact', header: 'Governance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'owner_department', header: 'Owner Dept' },
    { key: 'cost_line', header: 'Cost Line' },
    { key: 'period_quarter', header: 'Quarter' },
    { key: 'prior_year_spend_rupees', header: 'Prior Yr (INR)' },
    { key: 'proposed_budget_rupees', header: 'Proposed (INR)' },
    { key: 'reduction_pct', header: 'Reduction %' },
    { key: 'spend_classification', header: 'Classification' },
    { key: 'business_justification_strength', header: 'Justif.' },
    { key: 'zbb_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Zero-Based-Budgeting Cost-Line Challenge Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Zero-based-budgeting (ZBB) governance for EquipSeva discretionary spend — every cost line
        (field travel, logistics freight, IT &amp; SaaS subscriptions, marketing, office admin,
        professional fees, training, consumables, vehicle running) is challenged from zero rather
        than a prior-year baseline. Cost line &times; owner department &times; period quarter
        &times; prior-year vs justified vs proposed spend &times; challenge reduction &times; spend
        classification &times; justification strength &times; owner signoff &times; savings-locked
        &amp; CAPA closure. Founder-gated view: ZBB verdicts, department scorecards, root-cause
        pareto, and governance-impact digest across board &amp; CFO review surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. ZBB verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cost lines challenged yet."
          rowKey={(r, i) => String(r.zbb_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department ZBB scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.owner_department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cost line &times; department matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by cost line."
          rowKey={(r, i) => `${r.cost_line}-${r.owner_department}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Period-quarter trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_quarter ?? i)}
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
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No governance-impact rollups."
          rowKey={(r, i) => String(r.governance_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk challenge queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cost lines."
          rowKey={(r, i) => `${r.cost_line}-${r.owner_department}-${i}`}
        />
      </section>
    </main>
  );
}
