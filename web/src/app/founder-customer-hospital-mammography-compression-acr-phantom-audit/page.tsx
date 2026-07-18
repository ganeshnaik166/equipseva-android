import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qa_verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  passed: number;
  conditional: number;
  failed: number;
  suspended: number;
  avg_phantom_score: number;
  avg_mgd_mgy: number;
  pass_pct: number;
};
type MatrixRow = {
  unit_type: string;
  test_type: string;
  tests: number;
  passed: number;
  avg_force_n: number;
  avg_phantom_score: number;
};
type TrendRow = {
  test_date: string;
  tests: number;
  passed: number;
  failed: number;
  avg_phantom_score: number;
  avg_mgd_mgy: number;
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
  mammo_unit_tag: string;
  unit_model: string;
  test_date: string;
  qa_verdict: string;
  compression_force_n: number | null;
  aec_test_result: string | null;
  phantom_total: number | null;
  mean_glandular_dose_mgy: number | null;
  artifact_check: string | null;
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
    supabase.rpc('founder_r3198_qa_verdict_rollup'),
    supabase.rpc('founder_r3198_hospital_scorecard'),
    supabase.rpc('founder_r3198_unit_test_matrix'),
    supabase.rpc('founder_r3198_daily_qa_trend'),
    supabase.rpc('founder_r3198_capa_status_board'),
    supabase.rpc('founder_r3198_root_cause_pareto'),
    supabase.rpc('founder_r3198_regulatory_impact_digest'),
    supabase.rpc('founder_r3198_high_risk_units'),
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
    { key: 'qa_verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'failed', header: 'Failed' },
    { key: 'suspended', header: 'Suspended' },
    { key: 'avg_phantom_score', header: 'Avg Phantom' },
    { key: 'avg_mgd_mgy', header: 'Avg MGD (mGy)' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'unit_type', header: 'Unit Type' },
    { key: 'test_type', header: 'Test Type' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_force_n', header: 'Avg Force (N)' },
    { key: 'avg_phantom_score', header: 'Avg Phantom' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'tests', header: 'Tests' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_phantom_score', header: 'Avg Phantom' },
    { key: 'avg_mgd_mgy', header: 'Avg MGD (mGy)' },
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
    { key: 'mammo_unit_tag', header: 'Unit' },
    { key: 'unit_model', header: 'Model' },
    { key: 'test_date', header: 'Date' },
    { key: 'qa_verdict', header: 'Verdict' },
    { key: 'compression_force_n', header: 'Force (N)' },
    { key: 'aec_test_result', header: 'AEC' },
    { key: 'phantom_total', header: 'Phantom' },
    { key: 'mean_glandular_dose_mgy', header: 'MGD (mGy)' },
    { key: 'artifact_check', header: 'Artifacts' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Mammography Compression-Force &amp; Image-Quality (ACR Phantom) Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Mammo QA log — unit model &times; compression force N &times; kVp accuracy &times; AEC &times;
        ACR phantom score (fibers/specks/masses) &times; mean glandular dose &amp; CAPA closure.
        Founder-gated view: QA verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across AERB &amp; NABH surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QA verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QA tests logged yet."
          rowKey={(r, i) => String(r.qa_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QA scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Unit type &times; test type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tests by unit type."
          rowKey={(r, i) => `${r.unit_type}-${r.test_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QA trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk units queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.mammo_unit_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
