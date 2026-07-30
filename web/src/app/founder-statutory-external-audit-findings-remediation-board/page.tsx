import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  remediation_status: string;
  findings: number;
  total_impact_rupees: number;
  pct: number;
};
type AreaRow = {
  audit_area: string;
  total_findings: number;
  open_findings: number;
  overdue: number;
  repeat_findings: number;
  critical_high: number;
  total_impact_rupees: number;
  remediated_pct: number;
};
type MatrixRow = {
  audit_area: string;
  remediation_status: string;
  findings: number;
  total_impact_rupees: number;
  avg_days_open: number;
};
type TrendRow = {
  period_month: string;
  findings: number;
  remediated: number;
  overdue: number;
  repeat_findings: number;
  total_impact_rupees: number;
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
type ImpactRow = {
  statutory_exposure: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  finding_ref: string;
  audit_area: string;
  business_unit: string;
  auditor_firm: string;
  severity: string;
  remediation_status: string;
  days_open: number;
  financial_impact_rupees: number | null;
  repeat_finding: boolean | null;
  target_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    areaRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3614_remediation_status_rollup'),
    supabase.rpc('founder_r3614_audit_area_scorecard'),
    supabase.rpc('founder_r3614_area_status_matrix'),
    supabase.rpc('founder_r3614_monthly_finding_trend'),
    supabase.rpc('founder_r3614_capa_status_board'),
    supabase.rpc('founder_r3614_root_cause_pareto'),
    supabase.rpc('founder_r3614_impact_digest'),
    supabase.rpc('founder_r3614_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const areaRows: AreaRow[] = (areaRes.data as AreaRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'remediation_status', header: 'Remediation Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const areaCols: Column<AreaRow>[] = [
    { key: 'audit_area', header: 'Audit Area' },
    { key: 'total_findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'repeat_findings', header: 'Repeat' },
    { key: 'critical_high', header: 'Critical / High' },
    { key: 'total_impact_rupees', header: 'Impact (INR)' },
    { key: 'remediated_pct', header: 'Remediated %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'audit_area', header: 'Audit Area' },
    { key: 'remediation_status', header: 'Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Impact (INR)' },
    { key: 'avg_days_open', header: 'Avg Days Open' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'findings', header: 'Findings' },
    { key: 'remediated', header: 'Remediated' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'repeat_findings', header: 'Repeat' },
    { key: 'total_impact_rupees', header: 'Impact (INR)' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'statutory_exposure', header: 'Statutory Exposure' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'finding_ref', header: 'Finding' },
    { key: 'audit_area', header: 'Audit Area' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'auditor_firm', header: 'Auditor' },
    { key: 'severity', header: 'Severity' },
    { key: 'remediation_status', header: 'Status' },
    { key: 'days_open', header: 'Days Open' },
    { key: 'financial_impact_rupees', header: 'Impact (INR)' },
    { key: 'repeat_finding', header: 'Repeat' },
    { key: 'target_date', header: 'Target' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Statutory / External-Audit Findings Remediation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Statutory &amp; external-audit findings log &mdash; auditor firm &times; audit area &times;
        business unit &times; period &times; severity &times; financial impact &times; days open
        &times; repeat flag &times; target date &times; remediation status &times; trend &amp; CAPA
        closure. Founder-gated view: remediation-status distribution, audit-area scorecards, area
        &times; status matrix, root-cause pareto, and statutory-exposure impact digest across
        Companies Act, GST, TDS &amp; PF/ESI surfaces. Distinct from the internal-audit register.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Remediation-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No audit findings logged yet."
          rowKey={(r, i) => String(r.remediation_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Audit-area scorecard</h2>
        <DataTable
          rows={areaRows}
          columns={areaCols}
          emptyMessage="No audit-area rollups."
          rowKey={(r, i) => String(r.audit_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Audit area &times; remediation status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No findings by area."
          rowKey={(r, i) => `${r.audit_area}-${r.remediation_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly finding trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Statutory-exposure impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No statutory-exposure rollups."
          rowKey={(r, i) => String(r.statutory_exposure ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk remediation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk findings."
          rowKey={(r, i) => `${r.finding_ref}-${i}`}
        />
      </section>
    </main>
  );
}
