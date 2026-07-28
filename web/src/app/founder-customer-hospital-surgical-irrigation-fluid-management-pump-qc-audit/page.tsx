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
  avg_deviation_pct: number;
  pass_pct: number;
};
type MatrixRow = {
  parameter: string;
  qc_verdict: string;
  checks: number;
  out_of_tolerance: number;
  avg_deviation_pct: number;
};
type TrendRow = {
  cal_month: string;
  checks: number;
  passed: number;
  failed: number;
  out_of_tolerance: number;
  avg_deviation_pct: number;
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
type ImpactRow = {
  parameter: string;
  checks: number;
  out_of_tolerance: number;
  avg_deviation_pct: number;
  max_deviation_pct: number;
  within_tolerance_pct: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  parameter: string;
  calibration_date: string;
  reference_value: number | null;
  measured_value: number | null;
  deviation_pct: number | null;
  qc_verdict: string;
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
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3550_qc_verdict_rollup'),
    supabase.rpc('founder_r3550_device_model_scorecard'),
    supabase.rpc('founder_r3550_parameter_verdict_matrix'),
    supabase.rpc('founder_r3550_monthly_calibration_trend'),
    supabase.rpc('founder_r3550_capa_status_board'),
    supabase.rpc('founder_r3550_root_cause_pareto'),
    supabase.rpc('founder_r3550_accuracy_impact_digest'),
    supabase.rpc('founder_r3550_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
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
    { key: 'avg_deviation_pct', header: 'Avg Dev %' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'avg_deviation_pct', header: 'Avg Dev %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'avg_deviation_pct', header: 'Avg Dev %' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'avg_deviation_pct', header: 'Avg Dev %' },
    { key: 'max_deviation_pct', header: 'Max Dev %' },
    { key: 'within_tolerance_pct', header: 'Within Tol %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'parameter', header: 'Parameter' },
    { key: 'calibration_date', header: 'Cal Date' },
    { key: 'reference_value', header: 'Reference' },
    { key: 'measured_value', header: 'Measured' },
    { key: 'deviation_pct', header: 'Dev %' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Surgical Irrigation / Fluid-Management Pump QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Hospital surgical irrigation / fluid-management pump (arthroscopy &amp; laparoscopy) QC log —
        parameter (set &amp; measured flow ml/min, set &amp; measured chamber pressure mmHg, occlusion
        auto-shutoff response sec, fluid-deficit accuracy ml) &times; device model &times;
        reference-vs-measured accuracy &times; deviation % &times; within-tolerance &amp; CAPA closure.
        Founder-gated view: QC verdicts, device-model scorecards, parameter &times; verdict matrix,
        root-cause pareto and accuracy-impact digest across NABH &amp; CDSCO surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device model QC scorecard</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly calibration trend</h2>
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
          rows={impactRows}
          columns={impactCols}
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
          rowKey={(r, i) => `${r.device_code}-${r.calibration_date}-${i}`}
        />
      </section>
    </main>
  );
}
