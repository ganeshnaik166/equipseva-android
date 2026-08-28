import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type SiteRow = {
  site_name: string;
  records: number;
  compliant: number;
  license_renewal_due: number;
  hygiene_gap: number;
  incident_reported: number;
  license_lapsed: number;
  meals_served_total: number;
  subsidy_cost_total: number | null;
  avg_hygiene_audit_score: number | null;
};
type MatrixRow = {
  service_class: string;
  compliance_status: string;
  records: number;
  avg_cost_per_meal_rupees: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  avg_hygiene_audit_score: number | null;
  meals_served_total: number;
  subsidy_cost_total: number | null;
  food_safety_incidents_total: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  site_name: string;
  records: number;
  incident_records: number;
  food_safety_incidents_total: number;
  avg_hygiene_audit_score: number | null;
  pest_control_gaps: number;
};
type RiskRow = {
  site_name: string;
  vendor_name: string;
  period_month: string;
  service_class: string;
  compliance_status: string;
  license_expiry_date: string | null;
  hygiene_audit_score: number | null;
  food_safety_incidents: number | null;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3747_compliance_status_rollup'),
    supabase.rpc('founder_r3747_site_scorecard'),
    supabase.rpc('founder_r3747_service_class_status_matrix'),
    supabase.rpc('founder_r3747_monthly_hygiene_score_trend'),
    supabase.rpc('founder_r3747_capa_status_board'),
    supabase.rpc('founder_r3747_root_cause_pareto'),
    supabase.rpc('founder_r3747_incident_digest'),
    supabase.rpc('founder_r3747_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
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
    { key: 'license_renewal_due', header: 'Renewal Due' },
    { key: 'hygiene_gap', header: 'Hygiene Gap' },
    { key: 'incident_reported', header: 'Incident Reported' },
    { key: 'license_lapsed', header: 'License Lapsed' },
    { key: 'meals_served_total', header: 'Meals Served' },
    { key: 'subsidy_cost_total', header: 'Subsidy Cost Total (Rs)' },
    { key: 'avg_hygiene_audit_score', header: 'Avg Hygiene Audit Score' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_class', header: 'Service Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_cost_per_meal_rupees', header: 'Avg Cost/Meal (Rs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'avg_hygiene_audit_score', header: 'Avg Hygiene Audit Score' },
    { key: 'meals_served_total', header: 'Meals Served' },
    { key: 'subsidy_cost_total', header: 'Subsidy Cost Total (Rs)' },
    { key: 'food_safety_incidents_total', header: 'Food-Safety Incidents' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'records', header: 'Flagged Records' },
    { key: 'incident_records', header: 'Incident Records' },
    { key: 'food_safety_incidents_total', header: 'Food-Safety Incidents' },
    { key: 'avg_hygiene_audit_score', header: 'Avg Hygiene Audit Score' },
    { key: 'pest_control_gaps', header: 'Pest-Control Gaps' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'period_month', header: 'Month' },
    { key: 'service_class', header: 'Service Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'license_expiry_date', header: 'License Expiry' },
    { key: 'hygiene_audit_score', header: 'Hygiene Audit Score' },
    { key: 'food_safety_incidents', header: 'Food-Safety Incidents' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Company Canteen / Food-Service FSSAI Hygiene Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Employee canteen/food-service operations &mdash; FSSAI license validity, hygiene audit
        scores, subsidy cost per meal, and vendor compliance across in-house kitchens,
        outsourced caterers, vending machines, tuck shops &amp; tea/coffee service points.
        Distinct from any pest-control-AMC-compliance board and any vendor-invoice-processing
        page, which are facilities/finance topics, not food-safety &amp; hygiene. Founder-gated
        view: compliance-status distribution, site scorecards, service-class &times; status
        matrix, monthly hygiene-score trend, CAPA status board, root-cause pareto, a
        food-safety incident digest, and a high-risk queue of lapsed/incident/hygiene-gap sites.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No canteen/FSSAI records logged yet."
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
          emptyMessage="No records by service class."
          rowKey={(r, i) => `${r.service_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly hygiene-score trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Food-safety incident digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No food-safety incident records."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk canteen/vendor records."
          rowKey={(r, i) => `${r.site_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
