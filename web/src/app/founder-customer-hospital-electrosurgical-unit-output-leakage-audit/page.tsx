import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { test_verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  passed: number;
  quarantined: number;
  removed: number;
  hf_fail: number;
  lf_fail: number;
  rem_issues: number;
  compliance_pct: number;
};
type ModeStdRow = {
  output_mode: string;
  test_standard: string;
  tests: number;
  passed: number;
  avg_power_error: number;
};
type TrendRow = {
  test_date: string;
  hf_pass: number;
  hf_fail: number;
  lf_pass: number;
  lf_fail: number;
  lf_borderline: number;
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
  ot_room_code: string;
  esu_asset_tag: string;
  test_date: string;
  test_verdict: string;
  output_mode: string;
  hf_leakage_verdict: string | null;
  lf_leakage_verdict: string | null;
  rem_patient_plate_alarm: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    modeStdRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3147_verdict_rollup'),
    supabase.rpc('founder_r3147_hospital_scorecard'),
    supabase.rpc('founder_r3147_mode_standard_matrix'),
    supabase.rpc('founder_r3147_leakage_daily_trend'),
    supabase.rpc('founder_r3147_capa_status_board'),
    supabase.rpc('founder_r3147_root_cause_pareto'),
    supabase.rpc('founder_r3147_regulatory_impact_digest'),
    supabase.rpc('founder_r3147_high_risk_units'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const modeStdRows: ModeStdRow[] = (modeStdRes.data as ModeStdRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'test_verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'removed', header: 'Removed' },
    { key: 'hf_fail', header: 'HF Fail' },
    { key: 'lf_fail', header: 'LF Fail' },
    { key: 'rem_issues', header: 'REM Issues' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const modeStdCols: Column<ModeStdRow>[] = [
    { key: 'output_mode', header: 'Output Mode' },
    { key: 'test_standard', header: 'Standard' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_power_error', header: 'Avg Power Error %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'hf_pass', header: 'HF Pass' },
    { key: 'hf_fail', header: 'HF Fail' },
    { key: 'lf_pass', header: 'LF Pass' },
    { key: 'lf_fail', header: 'LF Fail' },
    { key: 'lf_borderline', header: 'LF Borderline' },
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
    { key: 'ot_room_code', header: 'OT' },
    { key: 'esu_asset_tag', header: 'Asset' },
    { key: 'test_date', header: 'Date' },
    { key: 'test_verdict', header: 'Verdict' },
    { key: 'output_mode', header: 'Mode' },
    { key: 'hf_leakage_verdict', header: 'HF' },
    { key: 'lf_leakage_verdict', header: 'LF' },
    { key: 'rem_patient_plate_alarm', header: 'REM / Plate' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Electrosurgical Unit (Diathermy) Output &amp; Leakage-Current Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ESU QA log — output mode &times; set/measured power &times; power error % &times; HF leakage current &times;
        REM/patient-plate alarm &times; low-frequency leakage &amp; CAPA closure. Founder-gated view: test verdicts,
        hospital scorecards, root-cause pareto, and regulatory-impact digest across IEC 60601-2-2, IEC 62353,
        NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Test verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No ESU tests logged yet."
          rowKey={(r, i) => String(r.test_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Output mode &times; standard matrix</h2>
        <DataTable
          rows={modeStdRows}
          columns={modeStdCols}
          emptyMessage="No tests by mode."
          rowKey={(r, i) => `${r.output_mode}-${r.test_standard}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. HF &amp; LF leakage daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk ESU priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.esu_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
