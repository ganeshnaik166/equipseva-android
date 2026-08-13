import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cert_status: string; certs: number; pct: number };
type BrandRow = {
  oem_brand: string;
  certs: number;
  active_compliant: number;
  renewal_overdue: number;
  avg_last_audit_score: number | null;
  avg_technicians_certified: number | null;
  audit_findings_open_total: number;
};
type MatrixRow = {
  cert_class: string;
  cert_status: string;
  certs: number;
  avg_days_to_expiry: number | null;
};
type TrendRow = {
  period_month: string;
  certs: number;
  avg_days_to_expiry: number | null;
  renewals_due_soon: number;
  renewals_overdue: number;
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
type DigestRow = {
  cert_class: string;
  certs: number;
  audit_findings_open_total: number;
  avg_last_audit_score: number | null;
  low_score_certs: number;
};
type RiskRow = {
  oem_brand: string;
  service_center_location: string;
  certification_ref: string | null;
  cert_class: string;
  cert_status: string;
  period_month: string;
  expiry_date: string | null;
  days_to_expiry: number | null;
  technicians_certified: number | null;
  technicians_required: number | null;
  audit_findings_open: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    brandRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3734_cert_status_rollup'),
    supabase.rpc('founder_r3734_oem_brand_scorecard'),
    supabase.rpc('founder_r3734_cert_class_status_matrix'),
    supabase.rpc('founder_r3734_monthly_expiry_trend'),
    supabase.rpc('founder_r3734_capa_status_board'),
    supabase.rpc('founder_r3734_root_cause_pareto'),
    supabase.rpc('founder_r3734_audit_finding_digest'),
    supabase.rpc('founder_r3734_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const brandRows: BrandRow[] = (brandRes.data as BrandRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cert_status', header: 'Cert Status' },
    { key: 'certs', header: 'Certs' },
    { key: 'pct', header: 'Share %' },
  ];

  const brandCols: Column<BrandRow>[] = [
    { key: 'oem_brand', header: 'OEM Brand' },
    { key: 'certs', header: 'Certs' },
    { key: 'active_compliant', header: 'Active Compliant' },
    { key: 'renewal_overdue', header: 'Renewal Overdue' },
    { key: 'avg_last_audit_score', header: 'Avg Audit Score' },
    { key: 'avg_technicians_certified', header: 'Avg Technicians Certified' },
    { key: 'audit_findings_open_total', header: 'Open Findings' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'cert_class', header: 'Cert Class' },
    { key: 'cert_status', header: 'Cert Status' },
    { key: 'certs', header: 'Certs' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'certs', header: 'Certs' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'renewals_due_soon', header: 'Renewal Due Soon' },
    { key: 'renewals_overdue', header: 'Renewal Overdue' },
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
    { key: 'cert_class', header: 'Cert Class' },
    { key: 'certs', header: 'Certs' },
    { key: 'audit_findings_open_total', header: 'Open Findings' },
    { key: 'avg_last_audit_score', header: 'Avg Audit Score' },
    { key: 'low_score_certs', header: 'Low-Score Certs' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'oem_brand', header: 'OEM Brand' },
    { key: 'service_center_location', header: 'Service Center' },
    { key: 'certification_ref', header: 'Cert Ref' },
    { key: 'cert_class', header: 'Cert Class' },
    { key: 'cert_status', header: 'Cert Status' },
    { key: 'period_month', header: 'Month' },
    { key: 'expiry_date', header: 'Expiry Date' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'technicians_certified', header: 'Technicians Certified' },
    { key: 'technicians_required', header: 'Technicians Required' },
    { key: 'audit_findings_open', header: 'Open Findings' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        OEM-Authorized Dealer / Service-Center Certification Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        OEM-authorized dealer &amp; service-center certifications held by EquipSeva per equipment
        brand &mdash; certification class (service authorization, sales dealership, training
        partner, spare-parts distributor, warranty repair center) &times; validity window &times;
        technician headcount certified vs. required &times; last audit score &amp; open findings
        &times; renewal fee &amp; status &times; CAPA closure. This board tracks the COMPANY&apos;s
        own OEM authorization status specifically &mdash; it is distinct from any
        engineer-tool-calibration or engineer-refurbishment-recertification board, which cover
        tools and used equipment rather than dealer/service-center authorization. Founder-gated
        view: certification-status distribution, OEM-brand scorecards, an audit-finding digest, a
        root-cause pareto, and a high-risk queue of overdue, suspended, or revoked certifications.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Certification-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No certification rows logged yet."
          rowKey={(r, i) => String(r.cert_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. OEM-brand scorecard</h2>
        <DataTable
          rows={brandRows}
          columns={brandCols}
          emptyMessage="No brand rollups."
          rowKey={(r, i) => String(r.oem_brand ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cert class &times; cert status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No certifications by class."
          rowKey={(r, i) => `${r.cert_class}-${r.cert_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Audit-finding digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No open audit findings."
          rowKey={(r, i) => String(r.cert_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk certification queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk certifications."
          rowKey={(r, i) => `${r.certification_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
