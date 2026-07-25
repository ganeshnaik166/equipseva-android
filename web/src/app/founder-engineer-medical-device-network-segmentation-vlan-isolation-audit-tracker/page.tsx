import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { segmentation_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fully_isolated: number;
  minor_gap: number;
  exposed: number;
  not_on_vlan: number;
  default_creds_present: number;
  open_vuln_total: number;
  isolated_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  region: string;
  audits: number;
  fully_isolated: number;
  exposed: number;
  avg_open_vulnerabilities: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fully_isolated: number;
  exposed: number;
  not_on_vlan: number;
  open_vuln_total: number;
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
  exposure_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  device_code: string;
  equipment_type: string;
  region: string;
  audit_date: string;
  segmentation_verdict: string;
  antivirus_or_whitelist_ok: string | null;
  open_vulnerabilities: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3416_segmentation_verdict_rollup'),
    supabase.rpc('founder_r3416_hospital_scorecard'),
    supabase.rpc('founder_r3416_equipment_region_matrix'),
    supabase.rpc('founder_r3416_daily_audit_trend'),
    supabase.rpc('founder_r3416_capa_status_board'),
    supabase.rpc('founder_r3416_root_cause_pareto'),
    supabase.rpc('founder_r3416_exposure_impact_digest'),
    supabase.rpc('founder_r3416_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'segmentation_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fully_isolated', header: 'Isolated' },
    { key: 'minor_gap', header: 'Minor Gap' },
    { key: 'exposed', header: 'Exposed' },
    { key: 'not_on_vlan', header: 'Not On VLAN' },
    { key: 'default_creds_present', header: 'Default Creds' },
    { key: 'open_vuln_total', header: 'Open Vulns' },
    { key: 'isolated_pct', header: 'Isolated %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'region', header: 'Region' },
    { key: 'audits', header: 'Audits' },
    { key: 'fully_isolated', header: 'Isolated' },
    { key: 'exposed', header: 'Exposed' },
    { key: 'avg_open_vulnerabilities', header: 'Avg Open Vulns' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fully_isolated', header: 'Isolated' },
    { key: 'exposed', header: 'Exposed' },
    { key: 'not_on_vlan', header: 'Not On VLAN' },
    { key: 'open_vuln_total', header: 'Open Vulns' },
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
    { key: 'exposure_impact', header: 'Exposure Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_code', header: 'Device' },
    { key: 'equipment_type', header: 'Type' },
    { key: 'region', header: 'Region' },
    { key: 'audit_date', header: 'Date' },
    { key: 'segmentation_verdict', header: 'Verdict' },
    { key: 'antivirus_or_whitelist_ok', header: 'AV / Whitelist' },
    { key: 'open_vulnerabilities', header: 'Open Vulns' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Medical-Device Network-Segmentation &amp; VLAN-Isolation Audit Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field cyber-hygiene audit of networked medical devices — equipment type (imaging PACS,
        patient monitoring, lab analyzer, infusion-pump network, OT integration, dialysis network)
        &times; region &times; isolated-VLAN &times; firewall-rules review &times; default-credential
        rotation &times; port hardening &times; OS patch currency &times; antivirus / whitelisting
        &times; remote-access control &times; data-at-rest encryption &times; vulnerability scan &amp;
        open vulns &amp; CAPA hardening closure. Founder-gated view: segmentation verdicts, hospital
        scorecards, root-cause pareto, and exposure-impact digest across HIPAA &amp; patient-safety
        surfaces. Networked devices must sit on segmented VLANs isolated from hospital IT so an IT
        breach cannot pivot into clinical equipment.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Segmentation verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No segmentation audits logged yet."
          rowKey={(r, i) => String(r.segmentation_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital segmentation scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; region matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by equipment type."
          rowKey={(r, i) => `${r.equipment_type}-${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure impact digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure-impact rollups."
          rowKey={(r, i) => String(r.exposure_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk exposure queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
