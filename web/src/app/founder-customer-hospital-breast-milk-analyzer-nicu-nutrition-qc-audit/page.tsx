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
  avg_abs_deviation_pct: number;
  pass_pct: number;
};
type MatrixRow = {
  parameter: string;
  qc_verdict: string;
  checks: number;
  out_of_tolerance: number;
  avg_abs_deviation_pct: number;
};
type TrendRow = {
  cal_month: string;
  checks: number;
  passed: number;
  failed: number;
  out_of_tolerance: number;
  avg_abs_deviation_pct: number;
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
  within_tolerance_checks: number;
  out_of_tolerance: number;
  avg_abs_deviation_pct: number;
  max_abs_deviation_pct: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  parameter: string;
  calibration_date: string;
  qc_verdict: string;
  reference_value: number;
  measured_value: number;
  deviation_pct: number | null;
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
    supabase.rpc('founder_r3583_qc_verdict_rollup'),
    supabase.rpc('founder_r3583_device_model_scorecard'),
    supabase.rpc('founder_r3583_parameter_verdict_matrix'),
    supabase.rpc('founder_r3583_monthly_calibration_trend'),
    supabase.rpc('founder_r3583_capa_status_board'),
    supabase.rpc('founder_r3583_root_cause_pareto'),
    supabase.rpc('founder_r3583_accuracy_impact_digest'),
    supabase.rpc('founder_r3583_high_risk_queue'),
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
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'avg_abs_deviation_pct', header: 'Avg |Dev| %' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'avg_abs_deviation_pct', header: 'Avg |Dev| %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'avg_abs_deviation_pct', header: 'Avg |Dev| %' },
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
    { key: 'within_tolerance_checks', header: 'Within Tolerance' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'avg_abs_deviation_pct', header: 'Avg |Dev| %' },
    { key: 'max_abs_deviation_pct', header: 'Max |Dev| %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'parameter', header: 'Parameter' },
    { key: 'calibration_date', header: 'Cal Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'reference_value', header: 'Reference' },
    { key: 'measured_value', header: 'Measured' },
    { key: 'deviation_pct', header: 'Dev %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Human Breast-Milk Analyzer (NICU Nutrition) QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        NICU human breast-milk analyzer QA log — parameter (fat, protein, lactose, energy, total
        solids &amp; homogenizer speed) &times; device model &times; reference vs measured &times;
        deviation % &times; within-tolerance &times; calibration date &times; QC verdict &amp; CAPA
        closure. Founder-gated view: QC verdicts, device-model scorecards, root-cause pareto, and
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-model QC scorecard</h2>
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
          emptyMessage="No accuracy digest."
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
