import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type ModelRow = {
  device_model: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  out_of_tolerance: number;
  catalyst_issue: number;
  calibration_overdue: number;
  pass_pct: number;
};
type MatrixRow = {
  parameter: string;
  qc_verdict: string;
  checks: number;
  out_of_tolerance: number;
  avg_deviation_pct: number | null;
};
type TrendRow = {
  cal_month: string;
  checks: number;
  passed: number;
  failed: number;
  out_of_tolerance: number;
  avg_deviation_pct: number | null;
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
type DigestRow = {
  parameter: string;
  checks: number;
  out_of_tolerance: number;
  fail_checks: number;
  avg_deviation_pct: number | null;
  max_deviation_pct: number | null;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  parameter: string;
  reference_value: number | null;
  measured_value: number | null;
  deviation_pct: number | null;
  qc_verdict: string;
  catalyst_condition: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    modelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3498_qc_verdict_rollup'),
    supabase.rpc('founder_r3498_device_model_scorecard'),
    supabase.rpc('founder_r3498_parameter_verdict_matrix'),
    supabase.rpc('founder_r3498_monthly_accuracy_trend'),
    supabase.rpc('founder_r3498_capa_status_board'),
    supabase.rpc('founder_r3498_root_cause_pareto'),
    supabase.rpc('founder_r3498_accuracy_impact_digest'),
    supabase.rpc('founder_r3498_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'catalyst_issue', header: 'Catalyst Issue' },
    { key: 'calibration_overdue', header: 'Cal Overdue' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'fail_checks', header: 'Failed' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'max_deviation_pct', header: 'Max |Deviation| %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'parameter', header: 'Parameter' },
    { key: 'reference_value', header: 'Reference' },
    { key: 'measured_value', header: 'Measured' },
    { key: 'deviation_pct', header: 'Deviation %' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'catalyst_condition', header: 'Catalyst' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Anaerobic Chamber / Microbiology Incubator QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Hospital anaerobic-chamber &amp; microbiology-incubator QA log — parameter (O2 ppm, temperature
        &deg;C, humidity %, H2 %, CO2 % &amp; anaerobic indicator) &times; reference vs measured &times;
        deviation % &times; tolerance &times; catalyst condition &times; anaerobic-indicator status
        &times; gas supply &times; calibration currency &amp; CAPA closure. Founder-gated view: QC
        verdicts, device-model scorecards, parameter &times; verdict matrix, root-cause pareto, and an
        accuracy-impact digest across NABH &amp; ISO 15189 surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-model scorecard</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No device-model rollups."
          rowKey={(r, i) => String(r.device_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Parameter &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by parameter."
          rowKey={(r, i) => `${r.parameter}-${r.qc_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly calibration / accuracy trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cal_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Accuracy-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No accuracy-impact rollups."
          rowKey={(r, i) => String(r.parameter ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk QC queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.device_code}-${r.parameter}-${i}`}
        />
      </section>
    </main>
  );
}
