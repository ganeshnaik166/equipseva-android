import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { renewal_status: string; licenses: number; pct: number };
type ClassRow = {
  device_class: string;
  total_licenses: number;
  valid: number;
  renewal_due: number;
  under_renewal: number;
  expired: number;
  app_pending: number;
  fee_unpaid: number;
  avg_dossier_readiness_pct: number;
};
type MatrixRow = {
  license_type: string;
  renewal_status: string;
  licenses: number;
  avg_days_to_expiry: number;
  avg_dossier_readiness_pct: number;
};
type TrendRow = {
  period_month: string;
  licenses: number;
  expiring_soon: number;
  expired: number;
  renewal_due: number;
  avg_days_to_expiry: number;
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
type ExposureRow = {
  exposure_band: string;
  licenses: number;
  fee_unpaid: number;
  renewal_action_needed: number;
  avg_dossier_readiness_pct: number;
};
type RiskRow = {
  device_name: string;
  registration_number: string;
  device_class: string;
  license_type: string;
  expiry_date: string;
  days_to_expiry: number;
  renewal_status: string;
  dossier_readiness_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3638_renewal_status_rollup'),
    supabase.rpc('founder_r3638_device_class_scorecard'),
    supabase.rpc('founder_r3638_license_type_status_matrix'),
    supabase.rpc('founder_r3638_monthly_expiry_trend'),
    supabase.rpc('founder_r3638_capa_status_board'),
    supabase.rpc('founder_r3638_root_cause_pareto'),
    supabase.rpc('founder_r3638_expiry_exposure_digest'),
    supabase.rpc('founder_r3638_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
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

  const classCols: Column<ClassRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'total_licenses', header: 'Licenses' },
    { key: 'valid', header: 'Valid' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'under_renewal', header: 'Under Renewal' },
    { key: 'expired', header: 'Expired' },
    { key: 'app_pending', header: 'App Pending' },
    { key: 'fee_unpaid', header: 'Fee Unpaid' },
    { key: 'avg_dossier_readiness_pct', header: 'Avg Dossier %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'license_type', header: 'License Type' },
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'avg_dossier_readiness_pct', header: 'Avg Dossier %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'expiring_soon', header: 'Expiring ≤ 90d' },
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
    { key: 'exposure_band', header: 'Exposure Band' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'fee_unpaid', header: 'Fee Unpaid' },
    { key: 'renewal_action_needed', header: 'Action Needed' },
    { key: 'avg_dossier_readiness_pct', header: 'Avg Dossier %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'registration_number', header: 'Reg. No.' },
    { key: 'device_class', header: 'Class' },
    { key: 'license_type', header: 'License Type' },
    { key: 'expiry_date', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'renewal_status', header: 'Status' },
    { key: 'dossier_readiness_pct', header: 'Dossier %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Registration / License Renewal Portfolio Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-device MDR-2017 registration &amp; license portfolio — device class (A&ndash;D) &times;
        license type (manufacturing, import, wholesale, test &amp; loan licence) &times; issue/expiry
        dates &times; days-to-expiry &times; renewal lead time &times; dossier readiness &times; fee
        status &times; renewal status &amp; CAPA closure. Founder-gated view: renewal-status rollups,
        device-class scorecards, expiry-exposure banding, root-cause pareto, and the high-risk renewal
        queue across CDSCO &amp; ISO 13485 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Renewal status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No licenses logged yet."
          rowKey={(r, i) => String(r.renewal_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-class scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No device-class rollups."
          rowKey={(r, i) => String(r.device_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. License type &times; renewal status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No licenses by type."
          rowKey={(r, i) => `${r.license_type}-${r.renewal_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Expiry-exposure digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure data."
          rowKey={(r, i) => String(r.exposure_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk renewal queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk licenses."
          rowKey={(r, i) => `${r.registration_number}-${i}`}
        />
      </section>
    </main>
  );
}
