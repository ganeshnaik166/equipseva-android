import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  westgard_reject: number;
  recal_overdue: number;
  eqas_pt_fail: number;
  pass_pct: number;
};
type MatrixRow = {
  analyzer_type: string;
  control_level: string;
  checks: number;
  passed: number;
  avg_cv_percent: number;
  avg_bias_percent: number;
};
type TrendRow = {
  check_date: string;
  checks: number;
  passed: number;
  failed: number;
  westgard_reject: number;
  recal_overdue: number;
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
  analyzer_code: string;
  analyzer_type: string;
  lab_section: string;
  check_date: string;
  qc_verdict: string;
  westgard_rule_violation: string | null;
  calibration_status: string | null;
  cv_percent: number | null;
  bias_percent: number | null;
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
    supabase.rpc('founder_r3274_qc_verdict_rollup'),
    supabase.rpc('founder_r3274_hospital_scorecard'),
    supabase.rpc('founder_r3274_analyzer_control_matrix'),
    supabase.rpc('founder_r3274_daily_qc_trend'),
    supabase.rpc('founder_r3274_capa_status_board'),
    supabase.rpc('founder_r3274_root_cause_pareto'),
    supabase.rpc('founder_r3274_regulatory_impact_digest'),
    supabase.rpc('founder_r3274_high_risk_queue'),
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
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'westgard_reject', header: 'Westgard Reject' },
    { key: 'recal_overdue', header: 'Recal Overdue' },
    { key: 'eqas_pt_fail', header: 'EQAS/PT Fail' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'analyzer_type', header: 'Analyzer Type' },
    { key: 'control_level', header: 'Control Level' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_cv_percent', header: 'Avg CV %' },
    { key: 'avg_bias_percent', header: 'Avg Bias %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'westgard_reject', header: 'Westgard Reject' },
    { key: 'recal_overdue', header: 'Recal Overdue' },
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
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'analyzer_code', header: 'Analyzer' },
    { key: 'analyzer_type', header: 'Type' },
    { key: 'lab_section', header: 'Lab Section' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'westgard_rule_violation', header: 'Westgard Rule' },
    { key: 'calibration_status', header: 'Calibration' },
    { key: 'cv_percent', header: 'CV %' },
    { key: 'bias_percent', header: 'Bias %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Central-Lab Clinical-Chemistry &amp; Hematology Analyzer QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Central-lab QA log — analyzer type &times; control level &times; Westgard-rule violation
        &times; CV% imprecision &times; bias% &times; calibration status &times; reagent-lot
        verification &times; maintenance currency &times; EQAS/PT participation &amp; CAPA closure.
        Founder-gated view: QC verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABL &amp; CAP / ISO 15189 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QC checks logged yet."
          rowKey={(r, i) => String(r.qc_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QC scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Analyzer type &times; control level matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by analyzer type."
          rowKey={(r, i) => `${r.analyzer_type}-${r.control_level}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QC trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk QC queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.analyzer_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
