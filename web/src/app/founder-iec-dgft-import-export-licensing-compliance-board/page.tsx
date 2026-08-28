import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; registrations: number; pct: number };
type AuthorityRow = {
  authority: string;
  registrations: number;
  active_compliant: number;
  renewal_due: number;
  return_overdue: number;
  usage_error_flagged: number;
  suspended: number;
  total_usage_errors: number;
  total_scheme_benefit_rupees: number;
};
type MatrixRow = {
  reg_class: string;
  compliance_status: string;
  registrations: number;
  avg_days_to_expiry: number | null;
};
type TrendRow = {
  period_month: string;
  registrations: number;
  expiring_soon: number;
  overdue_returns: number;
  avg_days_to_expiry: number | null;
  worsening_registrations: number;
};
type CapaRow = { capa_status: string; findings: number; overdue_flag: number };
type CauseRow = { root_cause: string | null; occurrences: number; pct: number };
type DigestRow = {
  reg_class: string;
  registrations: number;
  flagged_registrations: number;
  total_usage_errors: number;
  total_shipments_processed: number;
  error_rate_pct: number | null;
};
type RiskRow = {
  registration_type: string;
  authority: string;
  registration_number: string | null;
  reg_class: string;
  compliance_status: string;
  period_month: string;
  days_to_expiry: number | null;
  iec_usage_errors: number | null;
  annual_return_filed: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    authorityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3739_compliance_status_rollup'),
    supabase.rpc('founder_r3739_authority_scorecard'),
    supabase.rpc('founder_r3739_reg_class_status_matrix'),
    supabase.rpc('founder_r3739_monthly_expiry_trend'),
    supabase.rpc('founder_r3739_capa_status_board'),
    supabase.rpc('founder_r3739_root_cause_pareto'),
    supabase.rpc('founder_r3739_usage_error_digest'),
    supabase.rpc('founder_r3739_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const authorityRows: AuthorityRow[] = (authorityRes.data as AuthorityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'pct', header: 'Share %' },
  ];

  const authorityCols: Column<AuthorityRow>[] = [
    { key: 'authority', header: 'Authority' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'active_compliant', header: 'Active Compliant' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'return_overdue', header: 'Return Overdue' },
    { key: 'usage_error_flagged', header: 'Usage Error Flagged' },
    { key: 'suspended', header: 'Suspended' },
    { key: 'total_usage_errors', header: 'Total Usage Errors' },
    { key: 'total_scheme_benefit_rupees', header: 'Scheme Benefit (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'reg_class', header: 'Registration Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'expiring_soon', header: 'Expiring Soon (<=60d)' },
    { key: 'overdue_returns', header: 'Overdue Returns' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'worsening_registrations', header: 'Worsening' },
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
    { key: 'reg_class', header: 'Registration Class' },
    { key: 'registrations', header: 'Registrations' },
    { key: 'flagged_registrations', header: 'Flagged' },
    { key: 'total_usage_errors', header: 'Total Usage Errors' },
    { key: 'total_shipments_processed', header: 'Shipments Processed' },
    { key: 'error_rate_pct', header: 'Error Rate %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'registration_type', header: 'Registration Type' },
    { key: 'authority', header: 'Authority' },
    { key: 'registration_number', header: 'Registration No.' },
    { key: 'reg_class', header: 'Class' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'period_month', header: 'Month' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'iec_usage_errors', header: 'Usage Errors' },
    { key: 'annual_return_filed', header: 'Return Filed' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        IEC / DGFT Import-Export Licensing Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Company Importer-Exporter Code (IEC) and DGFT registration/scheme compliance log --
        registration type (IEC, RCMC, export promotion scheme, advance authorization, EPCG) &times;
        issuing authority &times; period month &times; validity/expiry &times; annual return
        filing &times; shipment-level usage errors &times; scheme benefit claimed &amp; KYC
        updation, with CAPA closure. Distinct from any medical-device import-license page, which
        is CDSCO PRODUCT-specific licensing by OEM/license-form, not the company&apos;s general
        trade code/scheme registrations. Founder-gated view: compliance-status distribution,
        authority scorecards, a registration-class &times; status matrix, monthly expiry trend,
        a usage-error digest, and a high-risk queue of suspended &amp; overdue registrations.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No IEC/DGFT registration rows logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Authority scorecard</h2>
        <DataTable
          rows={authorityRows}
          columns={authorityCols}
          emptyMessage="No authority rollups."
          rowKey={(r, i) => String(r.authority ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Registration-class &times; compliance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No registrations by class."
          rowKey={(r, i) => `${r.reg_class}-${r.compliance_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Usage-error digest by registration class</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No usage-error data."
          rowKey={(r, i) => String(r.reg_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue (suspended &amp; return overdue)</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk registrations."
          rowKey={(r, i) => `${r.registration_number ?? r.registration_type}-${i}`}
        />
      </section>
    </main>
  );
}
