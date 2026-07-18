import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { coverage_verdict: string; policies: number; pct: number };
type InsurerRow = {
  insurer: string;
  policies: number;
  lives_covered: number;
  total_premium_rupees: number;
  healthy: number;
  at_risk: number;
  avg_claim_ratio_pct: number;
  endorsement_backlog: number;
};
type MatrixRow = {
  policy_type: string;
  employee_cohort: string;
  policies: number;
  lives: number;
  avg_sum_insured_rupees: number;
  total_premium_rupees: number;
};
type TrendRow = {
  policy_end: string;
  policies_expiring: number;
  lives: number;
  annual_premium_rupees: number;
  at_risk: number;
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
type ComplianceRow = {
  compliance_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  policy_name: string;
  policy_type: string;
  insurer: string;
  employee_cohort: string;
  policy_end: string;
  coverage_verdict: string;
  claim_ratio_pct: number | null;
  cd_balance_rupees: number | null;
  endorsement_backlog: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    insurerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    complianceRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3261_coverage_verdict_rollup'),
    supabase.rpc('founder_r3261_insurer_scorecard'),
    supabase.rpc('founder_r3261_policy_cohort_matrix'),
    supabase.rpc('founder_r3261_renewal_runway_trend'),
    supabase.rpc('founder_r3261_capa_status_board'),
    supabase.rpc('founder_r3261_root_cause_pareto'),
    supabase.rpc('founder_r3261_compliance_impact_digest'),
    supabase.rpc('founder_r3261_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const insurerRows: InsurerRow[] = (insurerRes.data as InsurerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const complianceRows: ComplianceRow[] = (complianceRes.data as ComplianceRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'coverage_verdict', header: 'Verdict' },
    { key: 'policies', header: 'Policies' },
    { key: 'pct', header: 'Share %' },
  ];

  const insurerCols: Column<InsurerRow>[] = [
    { key: 'insurer', header: 'Insurer' },
    { key: 'policies', header: 'Policies' },
    { key: 'lives_covered', header: 'Lives' },
    { key: 'total_premium_rupees', header: 'Premium (INR)' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_claim_ratio_pct', header: 'Avg Claim Ratio %' },
    { key: 'endorsement_backlog', header: 'Endorsement Backlog' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'policy_type', header: 'Policy Type' },
    { key: 'employee_cohort', header: 'Cohort' },
    { key: 'policies', header: 'Policies' },
    { key: 'lives', header: 'Lives' },
    { key: 'avg_sum_insured_rupees', header: 'Avg Sum Insured (INR)' },
    { key: 'total_premium_rupees', header: 'Premium (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'policy_end', header: 'Policy End' },
    { key: 'policies_expiring', header: 'Expiring' },
    { key: 'lives', header: 'Lives' },
    { key: 'annual_premium_rupees', header: 'Premium (INR)' },
    { key: 'at_risk', header: 'At Risk' },
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

  const complianceCols: Column<ComplianceRow>[] = [
    { key: 'compliance_impact', header: 'Compliance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'policy_name', header: 'Policy' },
    { key: 'policy_type', header: 'Type' },
    { key: 'insurer', header: 'Insurer' },
    { key: 'employee_cohort', header: 'Cohort' },
    { key: 'policy_end', header: 'Policy End' },
    { key: 'coverage_verdict', header: 'Verdict' },
    { key: 'claim_ratio_pct', header: 'Claim Ratio %' },
    { key: 'cd_balance_rupees', header: 'CD Balance (INR)' },
    { key: 'endorsement_backlog', header: 'Endorsement Backlog' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Employee Group Mediclaim / GPA / GTL Benefits Coverage Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        HR-benefits governance — policy type &times; employee cohort &times; insurer &times; lives
        covered &times; sum insured &times; annual premium &times; CD balance float &times; claims
        ratio &times; endorsement backlog &amp; CAPA closure. Founder-gated view: coverage verdicts,
        insurer scorecards, renewal runway, root-cause pareto, and compliance-impact digest across
        WC Act &amp; IRDAI surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No benefits policies logged yet."
          rowKey={(r, i) => String(r.coverage_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Insurer coverage scorecard</h2>
        <DataTable
          rows={insurerRows}
          columns={insurerCols}
          emptyMessage="No insurer rollups."
          rowKey={(r, i) => String(r.insurer ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Policy type &times; cohort matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No policies by type."
          rowKey={(r, i) => `${r.policy_type}-${r.employee_cohort}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Renewal runway trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No renewal-runway data."
          rowKey={(r, i) => String(r.policy_end ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Compliance impact digest</h2>
        <DataTable
          rows={complianceRows}
          columns={complianceCols}
          emptyMessage="No compliance-impact rollups."
          rowKey={(r, i) => String(r.compliance_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk coverage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk policies."
          rowKey={(r, i) => `${r.policy_name}-${r.policy_end}-${i}`}
        />
      </section>
    </main>
  );
}
