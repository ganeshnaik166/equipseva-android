import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; fleets: number; pct: number };
type PlatformRow = {
  os_platform: string;
  fleets: number;
  devices: number;
  enrolled: number;
  avg_enrollment_pct: number;
  avg_encrypted_pct: number;
  avg_patched_pct: number;
  jailbroken: number;
  non_compliant: number;
  compliant_fleet_pct: number;
};
type MatrixRow = {
  device_class: string;
  compliance_status: string;
  fleets: number;
  devices: number;
  avg_enrollment_pct: number;
};
type TrendRow = {
  period_month: string;
  fleets: number;
  devices: number;
  enrolled: number;
  avg_enrollment_pct: number;
  avg_encrypted_pct: number;
  non_compliant: number;
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
  exposure_level: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  fleet_code: string;
  fleet_name: string;
  os_platform: string;
  device_class: string;
  period_month: string;
  compliance_status: string;
  enrollment_pct: number | null;
  encrypted_pct: number | null;
  jailbroken_rooted: number;
  non_compliant_devices: number;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    platformRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3672_compliance_status_rollup'),
    supabase.rpc('founder_r3672_os_platform_scorecard'),
    supabase.rpc('founder_r3672_device_class_status_matrix'),
    supabase.rpc('founder_r3672_monthly_enrollment_trend'),
    supabase.rpc('founder_r3672_capa_status_board'),
    supabase.rpc('founder_r3672_root_cause_pareto'),
    supabase.rpc('founder_r3672_exposure_digest'),
    supabase.rpc('founder_r3672_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const platformRows: PlatformRow[] = (platformRes.data as PlatformRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'fleets', header: 'Fleets' },
    { key: 'pct', header: 'Share %' },
  ];

  const platformCols: Column<PlatformRow>[] = [
    { key: 'os_platform', header: 'OS Platform' },
    { key: 'fleets', header: 'Fleets' },
    { key: 'devices', header: 'Devices' },
    { key: 'enrolled', header: 'MDM Enrolled' },
    { key: 'avg_enrollment_pct', header: 'Avg Enroll %' },
    { key: 'avg_encrypted_pct', header: 'Avg Encrypted %' },
    { key: 'avg_patched_pct', header: 'Avg Patched %' },
    { key: 'jailbroken', header: 'Jailbroken/Rooted' },
    { key: 'non_compliant', header: 'Non-compliant' },
    { key: 'compliant_fleet_pct', header: 'Compliant Fleet %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'fleets', header: 'Fleets' },
    { key: 'devices', header: 'Devices' },
    { key: 'avg_enrollment_pct', header: 'Avg Enroll %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'fleets', header: 'Fleets' },
    { key: 'devices', header: 'Devices' },
    { key: 'enrolled', header: 'MDM Enrolled' },
    { key: 'avg_enrollment_pct', header: 'Avg Enroll %' },
    { key: 'avg_encrypted_pct', header: 'Avg Encrypted %' },
    { key: 'non_compliant', header: 'Non-compliant' },
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
    { key: 'exposure_level', header: 'Exposure Level' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'fleet_code', header: 'Fleet Code' },
    { key: 'fleet_name', header: 'Fleet' },
    { key: 'os_platform', header: 'OS' },
    { key: 'device_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'enrollment_pct', header: 'Enroll %' },
    { key: 'encrypted_pct', header: 'Encrypted %' },
    { key: 'jailbroken_rooted', header: 'Jailbroken/Rooted' },
    { key: 'non_compliant_devices', header: 'Non-compliant' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        IT MDM / Endpoint-Encryption / BYOD Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-fleet endpoint governance — MDM enrollment &times; full-disk encryption &times; OS patch
        currency &times; jailbreak/root detection &times; BYOD work-profile coverage &times;
        remote-wipe readiness across company laptops, mobiles, BYOD handsets, field tablets &amp;
        shared kiosks. Founder-gated view: compliance-status distribution, OS-platform scorecards,
        device-class &times; status matrix, monthly enrollment trend, CAPA board, root-cause pareto
        &amp; exposure digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No fleet snapshots logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. OS platform scorecard</h2>
        <DataTable
          rows={platformRows}
          columns={platformCols}
          emptyMessage="No platform rollups."
          rowKey={(r, i) => String(r.os_platform ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device class &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No snapshots by device class."
          rowKey={(r, i) => `${r.device_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly enrollment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.exposure_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk fleet queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk fleets."
          rowKey={(r, i) => `${r.fleet_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
