import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { renewal_status: string; licenses: number; pct: number };
type SiteRow = {
  site_name: string;
  licenses: number;
  active_valid: number;
  renewal_overdue: number;
  expired_lapsed: number;
  inspection_pending: number;
  open_inspection_findings: number;
  total_penalty_rupees: number;
  avg_days_to_expiry: number;
};
type MatrixRow = {
  license_class: string;
  renewal_status: string;
  licenses: number;
  avg_days_to_expiry: number;
  total_penalty_rupees: number;
};
type TrendRow = {
  period_month: string;
  licenses: number;
  avg_days_to_expiry: number;
  renewals_filed: number;
  expired_count: number;
  worsening_count: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  closed_count: number;
  overdue_count: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type RiskDigestRow = {
  site_name: string;
  license_type: string;
  license_class: string;
  expiry_date: string | null;
  days_to_expiry: number | null;
  renewal_filed: boolean;
  inspection_due: boolean;
  renewal_status: string;
  penalty_rupees: number | null;
};
type HighRiskRow = {
  site_name: string;
  license_type: string;
  license_class: string;
  license_number: string | null;
  expiry_date: string | null;
  days_to_expiry: number | null;
  renewal_status: string;
  inspection_due: boolean;
  inspection_findings_open: number | null;
  penalty_rupees: number | null;
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
    riskDigestRes,
    highRiskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3731_renewal_status_rollup'),
    supabase.rpc('founder_r3731_site_scorecard'),
    supabase.rpc('founder_r3731_license_class_status_matrix'),
    supabase.rpc('founder_r3731_monthly_expiry_trend'),
    supabase.rpc('founder_r3731_capa_status_board'),
    supabase.rpc('founder_r3731_root_cause_pareto'),
    supabase.rpc('founder_r3731_expiry_risk_digest'),
    supabase.rpc('founder_r3731_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskDigestRows: RiskDigestRow[] = (riskDigestRes.data as RiskDigestRow[]) ?? [];
  const highRiskRows: HighRiskRow[] = (highRiskRes.data as HighRiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'active_valid', header: 'Active/Valid' },
    { key: 'renewal_overdue', header: 'Renewal Overdue' },
    { key: 'expired_lapsed', header: 'Expired/Lapsed' },
    { key: 'inspection_pending', header: 'Inspection Pending' },
    { key: 'open_inspection_findings', header: 'Open Findings' },
    { key: 'total_penalty_rupees', header: 'Total Penalty (INR)' },
    { key: 'avg_days_to_expiry', header: 'Avg Days To Expiry' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'license_class', header: 'License Class' },
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'avg_days_to_expiry', header: 'Avg Days To Expiry' },
    { key: 'total_penalty_rupees', header: 'Total Penalty (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'avg_days_to_expiry', header: 'Avg Days To Expiry' },
    { key: 'renewals_filed', header: 'Renewals Filed' },
    { key: 'expired_count', header: 'Expired' },
    { key: 'worsening_count', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'overdue_count', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const riskDigestCols: Column<RiskDigestRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'license_type', header: 'License Type' },
    { key: 'license_class', header: 'License Class' },
    { key: 'expiry_date', header: 'Expiry Date' },
    { key: 'days_to_expiry', header: 'Days To Expiry' },
    { key: 'renewal_filed', header: 'Renewal Filed' },
    { key: 'inspection_due', header: 'Inspection Due' },
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'penalty_rupees', header: 'Penalty (INR)' },
  ];

  const highRiskCols: Column<HighRiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'license_type', header: 'License Type' },
    { key: 'license_class', header: 'License Class' },
    { key: 'license_number', header: 'License Number' },
    { key: 'expiry_date', header: 'Expiry Date' },
    { key: 'days_to_expiry', header: 'Days To Expiry' },
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'inspection_due', header: 'Inspection Due' },
    { key: 'inspection_findings_open', header: 'Open Findings' },
    { key: 'penalty_rupees', header: 'Penalty (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Statutory Factory License / Shops &amp; Establishments Renewal Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Factory license (Factories Act) and Shops &amp; Establishments Act registration renewals
        per site &mdash; license number &times; issue/expiry date &times; days to expiry &times;
        renewal filing status &times; inspection due/findings &times; penalty amounts &amp; CAPA
        closure. Covers premises/labour statutory licensing &mdash; distinct from any
        medical-device-registration-license-renewal page, which is PRODUCT regulatory, not
        premises/labour statutory licensing. Founder-gated view: renewal-status distribution, site
        scorecards, license-class matrix, monthly expiry trend, CAPA closure, root-cause pareto,
        an expiry-risk digest, and a high-risk queue of overdue &amp; lapsed renewals.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Renewal-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No factory-license rows logged yet."
          rowKey={(r, i) => String(r.renewal_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. License class &times; renewal status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No license-class rollups."
          rowKey={(r, i) => `${r.license_class}-${r.renewal_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly expiry trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Expiry-risk digest</h2>
        <DataTable
          rows={riskDigestRows}
          columns={riskDigestCols}
          emptyMessage="No licenses at imminent expiry risk."
          rowKey={(r, i) => `${r.site_name}-${r.license_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk renewal queue</h2>
        <DataTable
          rows={highRiskRows}
          columns={highRiskCols}
          emptyMessage="No high-risk renewals."
          rowKey={(r, i) => `${r.site_name}-${r.license_type}-${i}`}
        />
      </section>
    </main>
  );
}
