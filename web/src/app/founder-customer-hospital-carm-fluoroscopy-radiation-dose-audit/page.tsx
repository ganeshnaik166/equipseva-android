import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { dose_verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  within_limits: number;
  exceeds_drl: number;
  service_required: number;
  recalls: number;
  collimation_fails: number;
  apron_defects: number;
  aerb_noncompliant: number;
  compliance_pct: number;
};
type MatrixRow = {
  imaging_mode: string;
  clinical_procedure: string;
  tests: number;
  exceeds: number;
  avg_dose_rate: number;
  avg_cumulative_dose: number;
};
type TrendRow = {
  test_date: string;
  tests: number;
  within_limits: number;
  exceeds_drl: number;
  avg_dose_rate: number;
  avg_dap: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  escalated_flag: number;
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
  cath_lab_code: string;
  carm_asset_tag: string;
  test_date: string;
  dose_verdict: string;
  imaging_mode: string;
  dose_rate_mgy_min: number;
  cumulative_dose_mgy: number;
  aerb_compliance: string;
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
    supabase.rpc('founder_r3151_dose_verdict_rollup'),
    supabase.rpc('founder_r3151_hospital_scorecard'),
    supabase.rpc('founder_r3151_mode_procedure_matrix'),
    supabase.rpc('founder_r3151_dose_daily_trend'),
    supabase.rpc('founder_r3151_capa_status_board'),
    supabase.rpc('founder_r3151_root_cause_pareto'),
    supabase.rpc('founder_r3151_regulatory_impact_digest'),
    supabase.rpc('founder_r3151_high_risk_queue'),
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
    { key: 'dose_verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'within_limits', header: 'Within Limits' },
    { key: 'exceeds_drl', header: 'Exceeds DRL' },
    { key: 'service_required', header: 'Service Req' },
    { key: 'recalls', header: 'Recalls' },
    { key: 'collimation_fails', header: 'Collim Fail' },
    { key: 'apron_defects', header: 'Apron Defects' },
    { key: 'aerb_noncompliant', header: 'AERB Non-Comp' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'imaging_mode', header: 'Imaging Mode' },
    { key: 'clinical_procedure', header: 'Procedure' },
    { key: 'tests', header: 'Tests' },
    { key: 'exceeds', header: 'Exceeds DRL' },
    { key: 'avg_dose_rate', header: 'Avg Dose-Rate mGy/min' },
    { key: 'avg_cumulative_dose', header: 'Avg Cumul. mGy' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'tests', header: 'Tests' },
    { key: 'within_limits', header: 'Within Limits' },
    { key: 'exceeds_drl', header: 'Exceeds DRL' },
    { key: 'avg_dose_rate', header: 'Avg Dose-Rate mGy/min' },
    { key: 'avg_dap', header: 'Avg DAP Gy·cm²' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'escalated_flag', header: 'Overdue / Escalated' },
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
    { key: 'cath_lab_code', header: 'Cath Lab' },
    { key: 'carm_asset_tag', header: 'Asset' },
    { key: 'test_date', header: 'Date' },
    { key: 'dose_verdict', header: 'Verdict' },
    { key: 'imaging_mode', header: 'Mode' },
    { key: 'dose_rate_mgy_min', header: 'Dose-Rate mGy/min' },
    { key: 'cumulative_dose_mgy', header: 'Cumul. mGy' },
    { key: 'aerb_compliance', header: 'AERB' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital C-Arm / Fluoroscopy Radiation-Output &amp; Dose Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        C-arm dose QA log — imaging mode &times; kVp/mA &times; dose-rate mGy/min &times; cumulative
        dose &times; collimation &times; laser alignment &times; lead-apron &times; AERB compliance &amp; CAPA
        closure. Founder-gated view: dose verdicts, hospital scorecards, mode &times; procedure matrix,
        root-cause pareto, and regulatory-impact digest across AERB &amp; NABH surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Dose verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No dose tests logged yet."
          rowKey={(r, i) => String(r.dose_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital dose compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Imaging mode &times; procedure matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tests by mode."
          rowKey={(r, i) => `${r.imaging_mode}-${r.clinical_procedure}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily dose trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk dose queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tests."
          rowKey={(r, i) => `${r.carm_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
