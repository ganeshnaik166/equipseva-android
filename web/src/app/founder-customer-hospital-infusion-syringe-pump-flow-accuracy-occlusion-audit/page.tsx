import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { test_verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  passed: number;
  failed: number;
  quarantined: number;
  out_of_spec: number;
  occlusion_slow: number;
  pass_pct: number;
};
type MatrixRow = {
  pump_type: string;
  test_profile: string;
  tests: number;
  passed: number;
  avg_flow_error: number;
};
type TrendRow = {
  test_date: string;
  tests: number;
  within_spec: number;
  marginal: number;
  out_of_spec: number;
  occlusion_slow: number;
  avg_flow_error: number;
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
  ward_code: string;
  pump_asset_tag: string;
  pump_model: string;
  test_date: string;
  pump_type: string;
  test_verdict: string;
  flow_error_pct: number | null;
  occlusion_response_time_sec: number | null;
  flow_accuracy_verdict: string | null;
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
    supabase.rpc('founder_r3143_verdict_rollup'),
    supabase.rpc('founder_r3143_hospital_scorecard'),
    supabase.rpc('founder_r3143_pump_profile_matrix'),
    supabase.rpc('founder_r3143_flow_occlusion_daily_trend'),
    supabase.rpc('founder_r3143_capa_status_board'),
    supabase.rpc('founder_r3143_root_cause_pareto'),
    supabase.rpc('founder_r3143_regulatory_impact_digest'),
    supabase.rpc('founder_r3143_high_risk_pumps'),
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
    { key: 'test_verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'out_of_spec', header: 'Out of Spec' },
    { key: 'occlusion_slow', header: 'Occlusion Slow' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'pump_type', header: 'Pump Type' },
    { key: 'test_profile', header: 'Test Profile' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_flow_error', header: 'Avg Flow Error %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'tests', header: 'Tests' },
    { key: 'within_spec', header: 'Within Spec' },
    { key: 'marginal', header: 'Marginal' },
    { key: 'out_of_spec', header: 'Out of Spec' },
    { key: 'occlusion_slow', header: 'Occlusion Slow' },
    { key: 'avg_flow_error', header: 'Avg Flow Error %' },
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
    { key: 'ward_code', header: 'Ward' },
    { key: 'pump_asset_tag', header: 'Asset' },
    { key: 'pump_model', header: 'Model' },
    { key: 'test_date', header: 'Date' },
    { key: 'pump_type', header: 'Type' },
    { key: 'test_verdict', header: 'Verdict' },
    { key: 'flow_error_pct', header: 'Flow Err %' },
    { key: 'occlusion_response_time_sec', header: 'Occl Resp (s)' },
    { key: 'flow_accuracy_verdict', header: 'Flow Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Infusion &amp; Syringe Pump Flow-Accuracy &amp; Occlusion Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Infusion, syringe &amp; PCA pump QA log — pump type &times; test profile &times; flow error % &times;
        occlusion alarm pressure/response &times; bolus accuracy &amp; CAPA closure. Founder-gated view:
        verdict rollup, hospital scorecards, root-cause pareto, and regulatory-impact digest across
        NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Test verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No pump tests logged yet."
          rowKey={(r, i) => String(r.test_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital pump-QA scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Pump type &times; test profile matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tests by profile."
          rowKey={(r, i) => `${r.pump_type}-${r.test_profile}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Flow-accuracy &amp; occlusion daily trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk pumps queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk pumps."
          rowKey={(r, i) => `${r.pump_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
