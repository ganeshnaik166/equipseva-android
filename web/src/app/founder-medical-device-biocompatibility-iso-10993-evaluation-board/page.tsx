import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { biocompat_status: string; evaluations: number; pct: number };
type CategoryRow = {
  contact_category: string;
  total_evaluations: number;
  compliant: number;
  testing_gap: number;
  endpoint_fail: number;
  under_evaluation: number;
  not_started: number;
  avg_coverage_pct: number;
  avg_risk_score: number;
};
type MatrixRow = {
  contact_duration: string;
  biocompat_status: string;
  evaluations: number;
  avg_coverage_pct: number;
  avg_risk_score: number;
};
type TrendRow = {
  period_month: string;
  evaluations: number;
  compliant: number;
  testing_gap: number;
  endpoint_fail: number;
  avg_coverage_pct: number;
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
type GapRow = {
  contact_category: string;
  devices: number;
  endpoints_required: number;
  endpoints_tested: number;
  endpoints_passed: number;
  endpoint_gap: number;
  avg_coverage_pct: number;
};
type RiskRow = {
  device_name: string;
  evaluation_ref: string;
  contact_category: string;
  contact_duration: string;
  period_month: string;
  biocompat_status: string;
  coverage_pct: number | null;
  endpoints_required: number;
  endpoints_tested: number;
  endpoints_passed: number;
  biological_risk_score: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3647_biocompat_status_rollup'),
    supabase.rpc('founder_r3647_contact_category_scorecard'),
    supabase.rpc('founder_r3647_duration_status_matrix'),
    supabase.rpc('founder_r3647_monthly_evaluation_trend'),
    supabase.rpc('founder_r3647_capa_status_board'),
    supabase.rpc('founder_r3647_root_cause_pareto'),
    supabase.rpc('founder_r3647_endpoint_gap_digest'),
    supabase.rpc('founder_r3647_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'biocompat_status', header: 'Status' },
    { key: 'evaluations', header: 'Evaluations' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'contact_category', header: 'Contact Category' },
    { key: 'total_evaluations', header: 'Evaluations' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'testing_gap', header: 'Testing Gap' },
    { key: 'endpoint_fail', header: 'Endpoint Fail' },
    { key: 'under_evaluation', header: 'Under Eval' },
    { key: 'not_started', header: 'Not Started' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
    { key: 'avg_risk_score', header: 'Avg Risk Score' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'contact_duration', header: 'Contact Duration' },
    { key: 'biocompat_status', header: 'Status' },
    { key: 'evaluations', header: 'Evaluations' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
    { key: 'avg_risk_score', header: 'Avg Risk Score' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'evaluations', header: 'Evaluations' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'testing_gap', header: 'Testing Gap' },
    { key: 'endpoint_fail', header: 'Endpoint Fail' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
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

  const gapCols: Column<GapRow>[] = [
    { key: 'contact_category', header: 'Contact Category' },
    { key: 'devices', header: 'Devices' },
    { key: 'endpoints_required', header: 'Endpoints Required' },
    { key: 'endpoints_tested', header: 'Endpoints Tested' },
    { key: 'endpoints_passed', header: 'Endpoints Passed' },
    { key: 'endpoint_gap', header: 'Endpoint Gap' },
    { key: 'avg_coverage_pct', header: 'Avg Coverage %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'evaluation_ref', header: 'Ref' },
    { key: 'contact_category', header: 'Category' },
    { key: 'contact_duration', header: 'Duration' },
    { key: 'period_month', header: 'Month' },
    { key: 'biocompat_status', header: 'Status' },
    { key: 'coverage_pct', header: 'Coverage %' },
    { key: 'endpoints_required', header: 'Req' },
    { key: 'endpoints_tested', header: 'Tested' },
    { key: 'endpoints_passed', header: 'Passed' },
    { key: 'biological_risk_score', header: 'Risk Score' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Biocompatibility (ISO 10993) Evaluation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ISO 10993 biological-evaluation coverage per device &mdash; contact category (surface,
        external-communicating, implant) &times; contact duration (limited, prolonged, permanent)
        &times; endpoints required vs tested vs passed &times; coverage % &times; test reports
        attached &times; biological risk score &times; reassessment due. Founder-gated view:
        biocompatibility status distribution, contact-category scorecards, endpoint-gap digest,
        root-cause pareto, and CAPA closure across ISO 10993 &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Biocompatibility status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No evaluations logged yet."
          rowKey={(r, i) => String(r.biocompat_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Contact-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No contact-category rollups."
          rowKey={(r, i) => String(r.contact_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Contact duration &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.contact_duration}-${r.biocompat_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly evaluation trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Endpoint-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No endpoint-gap data."
          rowKey={(r, i) => String(r.contact_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk evaluation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk evaluations."
          rowKey={(r, i) => `${r.evaluation_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
