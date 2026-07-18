import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { finding_verdict: string; findings: number; pct: number };
type AreaRow = {
  control_area: string;
  total_findings: number;
  critical_high: number;
  open_findings: number;
  repeat_findings: number;
  closed_verified: number;
  total_exposure_rupees: number;
  closed_pct: number;
};
type MatrixRow = {
  audit_cycle: string;
  severity: string;
  findings: number;
  open_findings: number;
  avg_exposure_rupees: number;
};
type TrendRow = {
  finding_date: string;
  findings: number;
  critical_high: number;
  closed: number;
  repeat_findings: number;
  exposure_rupees: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ExposureRow = {
  management_response: string;
  findings: number;
  open_findings: number;
  total_exposure_rupees: number;
  max_exposure_rupees: number;
};
type RiskRow = {
  finding_code: string;
  control_area: string;
  finding_title: string;
  severity: string;
  finding_date: string;
  target_close_date: string;
  finding_verdict: string;
  retest_result: string | null;
  estimated_exposure_rupees: number | null;
  remediation_owner: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    areaRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3257_finding_verdict_rollup'),
    supabase.rpc('founder_r3257_control_area_scorecard'),
    supabase.rpc('founder_r3257_cycle_severity_matrix'),
    supabase.rpc('founder_r3257_finding_date_trend'),
    supabase.rpc('founder_r3257_capa_status_board'),
    supabase.rpc('founder_r3257_root_cause_pareto'),
    supabase.rpc('founder_r3257_exposure_response_digest'),
    supabase.rpc('founder_r3257_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const areaRows: AreaRow[] = (areaRes.data as AreaRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'finding_verdict', header: 'Verdict' },
    { key: 'findings', header: 'Findings' },
    { key: 'pct', header: 'Share %' },
  ];

  const areaCols: Column<AreaRow>[] = [
    { key: 'control_area', header: 'Control Area' },
    { key: 'total_findings', header: 'Findings' },
    { key: 'critical_high', header: 'Critical / High' },
    { key: 'open_findings', header: 'Open' },
    { key: 'repeat_findings', header: 'Repeat' },
    { key: 'closed_verified', header: 'Closed Verified' },
    { key: 'total_exposure_rupees', header: 'Exposure (INR)' },
    { key: 'closed_pct', header: 'Closed %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'audit_cycle', header: 'Audit Cycle' },
    { key: 'severity', header: 'Severity' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'finding_date', header: 'Date' },
    { key: 'findings', header: 'Findings' },
    { key: 'critical_high', header: 'Critical / High' },
    { key: 'closed', header: 'Closed' },
    { key: 'repeat_findings', header: 'Repeat' },
    { key: 'exposure_rupees', header: 'Exposure (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'management_response', header: 'Management Response' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'max_exposure_rupees', header: 'Max Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'finding_code', header: 'Code' },
    { key: 'control_area', header: 'Control Area' },
    { key: 'finding_title', header: 'Finding' },
    { key: 'severity', header: 'Severity' },
    { key: 'finding_date', header: 'Found' },
    { key: 'target_close_date', header: 'Target Close' },
    { key: 'finding_verdict', header: 'Verdict' },
    { key: 'retest_result', header: 'Retest' },
    { key: 'estimated_exposure_rupees', header: 'Exposure (INR)' },
    { key: 'remediation_owner', header: 'Owner' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Internal-Audit Finding &amp; Control-Remediation Register
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Governance board — audit cycle &times; control area &times; severity &times; likelihood
        &times; retest result &times; repeat flag &times; estimated exposure INR &times;
        management response &amp; CAPA closure. Founder-gated view: finding verdicts,
        control-area scorecards, root-cause pareto, and exposure digest across Companies Act,
        GST &amp; ISO 27001 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Finding verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audit findings logged yet."
          rowKey={(r, i) => String(r.finding_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Control-area scorecard</h2>
        <DataTable
          rows={areaRows}
          columns={areaCols}
          emptyMessage="No control-area rollups."
          rowKey={(r, i) => String(r.control_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Audit cycle &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No findings by cycle."
          rowKey={(r, i) => `${r.audit_cycle}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Finding-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.finding_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure &amp; management-response digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.management_response ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk finding queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk findings."
          rowKey={(r, i) => `${r.finding_code}-${r.finding_date}-${i}`}
        />
      </section>
    </main>
  );
}
