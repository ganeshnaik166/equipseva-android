import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  passed: number;
  conditional: number;
  failed: number;
  air_detect_fail: number;
  pressure_test_fail: number;
  zero_cal_fail: number;
  pass_pct: number;
};
type MatrixRow = {
  injector_model: string;
  hemodynamic_recorder_model: string;
  audits: number;
  passed: number;
  avg_flow_error_pct: number;
  avg_transducer_error_mmhg: number;
};
type TrendRow = {
  qc_date: string;
  audits: number;
  passed: number;
  failed: number;
  air_detect_fail: number;
  zero_cal_fail: number;
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
  cathlab_room_code: string;
  injector_asset_tag: string;
  qc_date: string;
  qc_verdict: string;
  pressure_limit_test: string | null;
  air_detect_sensor_result: string | null;
  zero_cal_result: string | null;
  transducer_accuracy_verdict: string | null;
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
    supabase.rpc('founder_r3238_qc_verdict_rollup'),
    supabase.rpc('founder_r3238_hospital_scorecard'),
    supabase.rpc('founder_r3238_injector_recorder_matrix'),
    supabase.rpc('founder_r3238_daily_qc_trend'),
    supabase.rpc('founder_r3238_capa_status_board'),
    supabase.rpc('founder_r3238_root_cause_pareto'),
    supabase.rpc('founder_r3238_regulatory_impact_digest'),
    supabase.rpc('founder_r3238_high_risk_queue'),
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
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'air_detect_fail', header: 'Air-Detect Fail' },
    { key: 'pressure_test_fail', header: 'Pressure Fail' },
    { key: 'zero_cal_fail', header: 'Zero-Cal Fail' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'injector_model', header: 'Injector Model' },
    { key: 'hemodynamic_recorder_model', header: 'Recorder Model' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_flow_error_pct', header: 'Avg Flow Err %' },
    { key: 'avg_transducer_error_mmhg', header: 'Avg Transducer Err mmHg' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'qc_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'air_detect_fail', header: 'Air-Detect Fail' },
    { key: 'zero_cal_fail', header: 'Zero-Cal Fail' },
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
    { key: 'cathlab_room_code', header: 'Cath-Lab' },
    { key: 'injector_asset_tag', header: 'Asset' },
    { key: 'qc_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'pressure_limit_test', header: 'Pressure Test' },
    { key: 'air_detect_sensor_result', header: 'Air-Detect' },
    { key: 'zero_cal_result', header: 'Zero-Cal' },
    { key: 'transducer_accuracy_verdict', header: 'Transducer' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Cath-Lab Contrast-Injector &amp; Hemodynamic-Recorder QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Cath-lab QA log — injector model &times; flow-rate accuracy mL/s &times; pressure-limit psi
        &times; air-detect sensor &times; syringe-heater temp &times; hemodynamic zero-cal &times;
        transducer accuracy mmHg &times; ECG-sync trigger &amp; CAPA closure. Founder-gated view:
        QC verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across
        NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QC audits logged yet."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Injector model &times; recorder matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by model."
          rowKey={(r, i) => `${r.injector_model}-${r.hemodynamic_recorder_model}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QC trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.qc_date ?? i)}
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
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.injector_asset_tag}-${r.qc_date}-${i}`}
        />
      </section>
    </main>
  );
}
