import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type SiteRow = {
  site_name: string;
  records: number;
  compliant: number;
  minor_gap: number;
  visit_shortfall: number;
  quality_issue: number;
  contract_expiring: number;
  avg_visit_compliance_pct: number | null;
  avg_audit_score: number | null;
  pest_incidents_total: number;
};
type MatrixRow = {
  service_class: string;
  compliance_status: string;
  records: number;
  avg_visit_compliance_pct: number | null;
  avg_audit_score: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  avg_visit_compliance_pct: number | null;
  avg_audit_score: number | null;
  pest_incidents_total: number;
  worsening_records: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type PestRow = {
  site_name: string;
  records: number;
  pest_incidents_total: number;
  chemical_noncompliant_records: number;
  avg_audit_score: number | null;
  worsening_records: number;
};
type RiskRow = {
  site_name: string;
  service_class: string;
  period_month: string;
  compliance_status: string;
  visit_compliance_pct: number | null;
  audit_score: number | null;
  pest_incidents_reported: number | null;
  chemical_compliance_verified: boolean;
  vendor_name: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    pestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3742_compliance_status_rollup'),
    supabase.rpc('founder_r3742_site_scorecard'),
    supabase.rpc('founder_r3742_service_class_status_matrix'),
    supabase.rpc('founder_r3742_monthly_visit_compliance_trend'),
    supabase.rpc('founder_r3742_capa_status_board'),
    supabase.rpc('founder_r3742_root_cause_pareto'),
    supabase.rpc('founder_r3742_pest_incident_digest'),
    supabase.rpc('founder_r3742_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const pestRows: PestRow[] = (pestRes.data as PestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'minor_gap', header: 'Minor Gap' },
    { key: 'visit_shortfall', header: 'Visit Shortfall' },
    { key: 'quality_issue', header: 'Quality Issue' },
    { key: 'contract_expiring', header: 'Contract Expiring' },
    { key: 'avg_visit_compliance_pct', header: 'Avg Visit Compliance %' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
    { key: 'pest_incidents_total', header: 'Pest Incidents' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_class', header: 'Service Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_visit_compliance_pct', header: 'Avg Visit Compliance %' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'avg_visit_compliance_pct', header: 'Avg Visit Compliance %' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
    { key: 'pest_incidents_total', header: 'Pest Incidents' },
    { key: 'worsening_records', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const pestCols: Column<PestRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'records', header: 'Records' },
    { key: 'pest_incidents_total', header: 'Pest Incidents' },
    { key: 'chemical_noncompliant_records', header: 'Chemical Non-Compliant' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
    { key: 'worsening_records', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'service_class', header: 'Service Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'visit_compliance_pct', header: 'Visit Compliance %' },
    { key: 'audit_score', header: 'Audit Score' },
    { key: 'pest_incidents_reported', header: 'Pest Incidents' },
    { key: 'chemical_compliance_verified', header: 'Chemical Verified' },
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Housekeeping / Pest-Control AMC Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-premises housekeeping and pest-control AMC compliance per site &mdash; visit frequency
        vs contracted, service-quality audit scores, chemical compliance, and contract renewal
        status across housekeeping, deep-cleaning, pest-control, fumigation &amp; washroom-hygiene
        service classes. Founder-gated view: compliance-status distribution, per-site scorecards,
        a service-class &times; status matrix, monthly visit-compliance trend, CAPA status board,
        root-cause pareto, a pest-incident digest, and a high-risk queue of visit shortfalls &amp;
        quality issues.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No AMC compliance rows logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service class &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No service classes recorded."
          rowKey={(r, i) => `${r.service_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly visit-compliance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Pest-incident digest</h2>
        <DataTable
          rows={pestRows}
          columns={pestCols}
          emptyMessage="No pest incidents or chemical-compliance gaps logged."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk compliance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk compliance records."
          rowKey={(r, i) => `${r.site_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
