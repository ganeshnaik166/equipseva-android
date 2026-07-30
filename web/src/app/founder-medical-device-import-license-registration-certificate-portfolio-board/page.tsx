import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { renewal_status: string; licenses: number; pct: number };
type OemRow = {
  oem_name: string;
  total_licenses: number;
  valid: number;
  renewal_due: number;
  expired: number;
  agent_invalid: number;
  avg_days_to_expiry: number;
  avg_dossier_readiness_pct: number;
};
type MatrixRow = {
  license_form: string;
  renewal_status: string;
  licenses: number;
  avg_days_to_expiry: number;
  avg_dossier_readiness_pct: number;
};
type TrendRow = {
  expiry_month: string;
  licenses_expiring: number;
  expired: number;
  renewal_due: number;
  avg_days_to_expiry: number;
};
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type ExposureRow = {
  exposure_bucket: string;
  licenses: number;
  renewal_due: number;
  expired: number;
  avg_days_to_expiry: number;
  avg_dossier_readiness_pct: number;
};
type RiskRow = {
  device_name: string;
  oem_name: string;
  registration_cert_no: string;
  license_form: string;
  expiry_date: string;
  days_to_expiry: number;
  renewal_status: string;
  dossier_readiness_pct: number;
  agent_appointment_valid: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    oemRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3642_renewal_status_rollup'),
    supabase.rpc('founder_r3642_oem_scorecard'),
    supabase.rpc('founder_r3642_license_form_status_matrix'),
    supabase.rpc('founder_r3642_monthly_expiry_trend'),
    supabase.rpc('founder_r3642_capa_status_board'),
    supabase.rpc('founder_r3642_root_cause_pareto'),
    supabase.rpc('founder_r3642_expiry_exposure_digest'),
    supabase.rpc('founder_r3642_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const oemRows: OemRow[] = (oemRes.data as OemRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'pct', header: 'Share %' },
  ];

  const oemCols: Column<OemRow>[] = [
    { key: 'oem_name', header: 'OEM' },
    { key: 'total_licenses', header: 'Licenses' },
    { key: 'valid', header: 'Valid' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'expired', header: 'Expired' },
    { key: 'agent_invalid', header: 'Agent Invalid' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'avg_dossier_readiness_pct', header: 'Avg Dossier %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'license_form', header: 'License Form' },
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'avg_dossier_readiness_pct', header: 'Avg Dossier %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'expiry_month', header: 'Expiry Month' },
    { key: 'licenses_expiring', header: 'Expiring' },
    { key: 'expired', header: 'Expired' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
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

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'exposure_bucket', header: 'Exposure Bucket' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'expired', header: 'Expired' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'avg_dossier_readiness_pct', header: 'Avg Dossier %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'oem_name', header: 'OEM' },
    { key: 'registration_cert_no', header: 'Reg. Cert No.' },
    { key: 'license_form', header: 'Form' },
    { key: 'expiry_date', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'renewal_status', header: 'Status' },
    { key: 'dossier_readiness_pct', header: 'Dossier %' },
    { key: 'agent_appointment_valid', header: 'Agent Valid' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Import-License / Registration-Certificate Portfolio Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Import-license / registration-certificate (Form MD-14 &amp; MD-15) portfolio &mdash; license form &times; OEM
        &times; validity &times; days-to-expiry &times; authorized-agent validity &times; dossier readiness &amp; CAPA
        closure. Founder-gated view: renewal-status distribution, OEM scorecards, expiry exposure, and high-risk
        renewal queue across CDSCO device-import surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Renewal-status distribution</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No licenses logged yet." rowKey={(r, i) => String(r.renewal_status ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. OEM license scorecard</h2>
        <DataTable rows={oemRows} columns={oemCols} emptyMessage="No OEM rollups." rowKey={(r, i) => String(r.oem_name ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. License-form &times; renewal-status matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.license_form}-${r.renewal_status}-${i}`} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly expiry trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.expiry_month ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Expiry-exposure digest</h2>
        <DataTable rows={exposureRows} columns={exposureCols} emptyMessage="No exposure data." rowKey={(r, i) => String(r.exposure_bucket ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk renewal queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No high-risk licenses." rowKey={(r, i) => `${r.registration_cert_no}-${i}`} />
      </section>
    </main>
  );
}
