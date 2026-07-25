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
  optics_fail: number;
  out_of_tolerance: number;
  calibration_overdue: number;
  pass_pct: number;
};
type MatrixRow = {
  ward_or_dept: string;
  qc_verdict: string;
  checks: number;
  avg_deviation_pct: number;
  avg_tsb_correlation_pct: number;
};
type TrendRow = {
  month: string;
  checks: number;
  passed: number;
  failed: number;
  avg_deviation_pct: number;
  avg_tsb_correlation_pct: number;
  calibration_overdue: number;
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
  device_code: string;
  device_model: string;
  ward_or_dept: string;
  check_date: string;
  qc_verdict: string;
  deviation_pct: number | null;
  tsb_correlation_pct: number | null;
  probe_condition: string | null;
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
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3439_qc_verdict_rollup'),
    supabase.rpc('founder_r3439_device_model_scorecard'),
    supabase.rpc('founder_r3439_ward_verdict_matrix'),
    supabase.rpc('founder_r3439_monthly_accuracy_trend'),
    supabase.rpc('founder_r3439_capa_status_board'),
    supabase.rpc('founder_r3439_root_cause_pareto'),
    supabase.rpc('founder_r3439_accuracy_impact_digest'),
    supabase.rpc('founder_r3439_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
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

  const modelCols: Column<ModelRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'optics_fail', header: 'Optics Fail' },
    { key: 'out_of_tolerance', header: 'Out of Tolerance' },
    { key: 'calibration_overdue', header: 'Cal Overdue' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'ward_or_dept', header: 'Ward / Dept' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'avg_tsb_correlation_pct', header: 'Avg TSB Corr %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'avg_tsb_correlation_pct', header: 'Avg TSB Corr %' },
    { key: 'calibration_overdue', header: 'Cal Overdue' },
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
    { key: 'device_code', header: 'Device' },
    { key: 'device_model', header: 'Model' },
    { key: 'ward_or_dept', header: 'Ward / Dept' },
    { key: 'check_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'deviation_pct', header: 'Deviation %' },
    { key: 'tsb_correlation_pct', header: 'TSB Corr %' },
    { key: 'probe_condition', header: 'Probe' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Transcutaneous Bilirubin (Neonatal Jaundice Meter) QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Hospital transcutaneous bilirubinometer (neonatal jaundice meter) QA log — device model
        (Draeger JM-105 &amp; JM-103, Philips BiliChek, Konica Minolta JM-105) &times; ward &times;
        phantom-vs-measured TcB reading &times; deviation % &times; TSB correlation % &times; optics
        condition &times; probe condition &times; calibration currency &amp; CAPA closure. Founder-gated
        view: QC verdicts, device-model scorecards, ward &times; verdict matrix, monthly accuracy trend,
        root-cause pareto, and accuracy-impact digest across NABH &amp; CDSCO surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Ward &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by ward."
          rowKey={(r, i) => `${r.ward_or_dept}-${r.qc_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly accuracy trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
          rows={regRows}
          columns={regCols}
          emptyMessage="No accuracy-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk QC queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.device_code}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
