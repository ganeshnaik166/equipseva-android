import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { security_status: string; audits: number; pct: number };
type VendorRow = {
  security_vendor: string;
  total_audits: number;
  secure_sites: number;
  minor_gap_sites: number;
  gap_or_vulnerable: number;
  avg_cctv_uptime_pct: number;
  avg_guard_attendance_pct: number;
  total_tailgating: number;
  secure_pct: number;
};
type MatrixRow = {
  site_zone: string;
  security_status: string;
  audits: number;
  avg_cctv_uptime_pct: number;
  total_incidents: number;
};
type TrendRow = {
  period_month: string;
  audits: number;
  avg_cctv_uptime_pct: number;
  avg_guard_attendance_pct: number;
  total_incidents: number;
  total_tailgating: number;
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
type GapRow = {
  site_name: string;
  site_zone: string;
  audits: number;
  cameras_offline: number;
  faulty_readers: number;
  tailgating_total: number;
  incidents_total: number;
  worst_uptime_pct: number;
};
type RiskRow = {
  audit_code: string;
  site_name: string;
  site_zone: string;
  security_vendor: string;
  period_month: string;
  security_status: string;
  cctv_uptime_pct: number | null;
  guard_attendance_pct: number | null;
  tailgating_events: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    vendorRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3682_security_status_rollup'),
    supabase.rpc('founder_r3682_vendor_scorecard'),
    supabase.rpc('founder_r3682_zone_status_matrix'),
    supabase.rpc('founder_r3682_monthly_uptime_trend'),
    supabase.rpc('founder_r3682_capa_status_board'),
    supabase.rpc('founder_r3682_root_cause_pareto'),
    supabase.rpc('founder_r3682_coverage_gap_digest'),
    supabase.rpc('founder_r3682_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const vendorRows: VendorRow[] = (vendorRes.data as VendorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'security_status', header: 'Security Status' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'security_vendor', header: 'Vendor' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'secure_sites', header: 'Secure' },
    { key: 'minor_gap_sites', header: 'Minor Gaps' },
    { key: 'gap_or_vulnerable', header: 'Gap / Vendor Issue / Vulnerable' },
    { key: 'avg_cctv_uptime_pct', header: 'Avg CCTV Uptime %' },
    { key: 'avg_guard_attendance_pct', header: 'Avg Guard Attendance %' },
    { key: 'total_tailgating', header: 'Tailgating' },
    { key: 'secure_pct', header: 'Secure %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'site_zone', header: 'Site Zone' },
    { key: 'security_status', header: 'Status' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_cctv_uptime_pct', header: 'Avg CCTV Uptime %' },
    { key: 'total_incidents', header: 'Incidents' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_cctv_uptime_pct', header: 'Avg CCTV Uptime %' },
    { key: 'avg_guard_attendance_pct', header: 'Avg Guard Attendance %' },
    { key: 'total_incidents', header: 'Incidents' },
    { key: 'total_tailgating', header: 'Tailgating' },
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

  const gapCols: Column<GapRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'site_zone', header: 'Zone' },
    { key: 'audits', header: 'Audits' },
    { key: 'cameras_offline', header: 'Cameras Offline' },
    { key: 'faulty_readers', header: 'Faulty Readers' },
    { key: 'tailgating_total', header: 'Tailgating' },
    { key: 'incidents_total', header: 'Incidents' },
    { key: 'worst_uptime_pct', header: 'Worst Uptime %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'audit_code', header: 'Audit' },
    { key: 'site_name', header: 'Site' },
    { key: 'site_zone', header: 'Zone' },
    { key: 'security_vendor', header: 'Vendor' },
    { key: 'period_month', header: 'Month' },
    { key: 'security_status', header: 'Status' },
    { key: 'cctv_uptime_pct', header: 'CCTV Uptime %' },
    { key: 'guard_attendance_pct', header: 'Guard Attendance %' },
    { key: 'tailgating_events', header: 'Tailgating' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Premises Physical-Security / CCTV / Access-Control Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-premises physical-security audit log — site (Mumbai HQ, Chennai branch, Delhi warehouse,
        Bengaluru refurb center) &times; zone (office, warehouse, server room, parking perimeter)
        &times; security vendor &times; CCTV uptime &amp; recording retention &times; access-reader
        health &times; guard-post attendance &times; incidents &amp; tailgating &amp; CAPA closure.
        Founder-gated view: status distribution, vendor scorecards, zone &times; status matrix,
        monthly uptime trend, root-cause pareto, coverage-gap digest, and the vulnerable /
        coverage-gap high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Security status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No security audits logged yet."
          rowKey={(r, i) => String(r.security_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Security-vendor scorecard</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor rollups."
          rowKey={(r, i) => String(r.security_vendor ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Site zone &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by zone."
          rowKey={(r, i) => `${r.site_zone}-${r.security_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly uptime trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Coverage-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No coverage gaps flagged."
          rowKey={(r, i) => `${r.site_name}-${r.site_zone}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk site queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk sites."
          rowKey={(r, i) => `${r.audit_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
