import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; checks: number; pct: number };
type ScoreRow = {
  device_model: string;
  total_checks: number;
  passed: number;
  conditional: number;
  failed: number;
  out_of_tolerance: number;
  bi_fail: number;
  pass_pct: number;
};
type MatrixRow = { parameter: string; qc_verdict: string; checks: number; avg_deviation_pct: number };
type TrendRow = { month: string; checks: number; passed: number; failed: number; out_of_tolerance: number; avg_deviation_pct: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type ImpactRow = {
  parameter: string;
  checks: number;
  out_of_tolerance: number;
  bi_fail: number;
  avg_deviation_pct: number;
  max_abs_deviation_pct: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  device_model: string;
  parameter: string;
  calibration_date: string;
  qc_verdict: string;
  deviation_pct: number;
  bi_test_ok: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, impactRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3478_qc_verdict_rollup'),
    supabase.rpc('founder_r3478_device_model_scorecard'),
    supabase.rpc('founder_r3478_parameter_verdict_matrix'),
    supabase.rpc('founder_r3478_monthly_accuracy_trend'),
    supabase.rpc('founder_r3478_capa_status_board'),
    supabase.rpc('founder_r3478_root_cause_pareto'),
    supabase.rpc('founder_r3478_accuracy_impact_digest'),
    supabase.rpc('founder_r3478_high_risk_queue'),
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
    { key: 'qc_verdict', header: 'QC Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'bi_fail', header: 'BI Fail' },
    { key: 'pass_pct', header: 'Pass %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
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
  const impactCols: Column<ImpactRow>[] = [
    { key: 'parameter', header: 'Parameter' },
    { key: 'checks', header: 'Checks' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'bi_fail', header: 'BI Fail' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'max_abs_deviation_pct', header: 'Max |Deviation| %' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device Code' },
    { key: 'device_model', header: 'Model' },
    { key: 'parameter', header: 'Parameter' },
    { key: 'calibration_date', header: 'Calibration Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'deviation_pct', header: 'Deviation %' },
    { key: 'bi_test_ok', header: 'BI OK' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Dental Class-B Autoclave Sterilizer Cycle QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Class-B tabletop autoclave QC &mdash; sterilize temperature &times; chamber pressure &times; vacuum test &times;
        hold &amp; drying time &times; Bowie-Dick &times; biological-indicator &times; deviation vs tolerance &amp; CAPA.
        Founder-gated view: QC-verdict rollup, device-model scorecard, parameter &times; verdict matrix,
        monthly accuracy trend, and out-of-tolerance / BI-fail queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No checks yet." rowKey={(r, i) => String(r.qc_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-model scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No model rollups." rowKey={(r, i) => String(r.device_model ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Parameter &times; verdict matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.parameter}-${r.qc_verdict}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly accuracy trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.month ?? i)} />
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Accuracy-impact digest</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No accuracy-impact rollups." rowKey={(r, i) => String(r.parameter ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Out-of-tolerance / BI-fail queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No at-risk checks." rowKey={(r, i) => `${r.device_code}-${i}`} />
      </section>
    </main>
  );
}
