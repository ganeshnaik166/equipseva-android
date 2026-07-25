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
  calibration_overdue: number;
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
  failed: number;
  avg_deviation_pct: number;
  max_deviation_pct: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  parameter: string;
  calibration_date: string;
  qc_verdict: string;
  deviation_pct: number | null;
  within_tolerance: boolean | null;
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
    supabase.rpc('founder_r3447_qc_verdict_rollup'),
    supabase.rpc('founder_r3447_device_model_scorecard'),
    supabase.rpc('founder_r3447_parameter_verdict_matrix'),
    supabase.rpc('founder_r3447_monthly_calibration_trend'),
    supabase.rpc('founder_r3447_capa_status_board'),
    supabase.rpc('founder_r3447_root_cause_pareto'),
    supabase.rpc('founder_r3447_accuracy_impact_digest'),
    supabase.rpc('founder_r3447_high_risk_queue'),
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
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'calibration_overdue', header: 'Cal Overdue' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cal_month', header: 'Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'max_deviation_pct', header: 'Max Deviation %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'parameter', header: 'Parameter' },
    { key: 'calibration_date', header: 'Cal Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'deviation_pct', header: 'Deviation %' },
    { key: 'within_tolerance', header: 'In Tolerance' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        ELISA Microplate Reader / Washer QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Immunoassay-lab QC log for ELISA microplate readers &amp; washers — parameter (absorbance
        linearity, wavelength accuracy nm, wash residual &micro;L, dispense accuracy %, optical
        crosstalk %, plate uniformity) &times; reference vs measured value &times; deviation %
        &times; within-tolerance &times; calibration currency &times; verdict &amp; CAPA closure.
        Founder-gated view: QC verdicts, device-model scorecards, root-cause pareto, and
        accuracy-impact digest across NABL &amp; NABH surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device model scorecard</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly calibration &amp; accuracy trend</h2>
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
