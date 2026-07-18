import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { calibration_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  passed: number;
  deviations: number;
  failed: number;
  quarantined: number;
  recal_required: number;
  pass_pct: number;
};
type DeviceRow = {
  device_type: string;
  audits: number;
  passed: number;
  avg_rpm_error: number | null;
  avg_temp_error: number | null;
};
type TrendRow = {
  calibration_date: string;
  audits: number;
  passed: number;
  failed: number;
  quarantined: number;
  deviations: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  lab_section: string;
  device_asset_tag: string;
  device_type: string;
  calibration_date: string;
  calibration_verdict: string;
  rpm_error_pct: number | null;
  temp_error_pct: number | null;
  rotor_integrity: string;
  lid_interlock_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    deviceRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3179_calibration_verdict_rollup'),
    supabase.rpc('founder_r3179_hospital_scorecard'),
    supabase.rpc('founder_r3179_device_type_matrix'),
    supabase.rpc('founder_r3179_calibration_daily_trend'),
    supabase.rpc('founder_r3179_capa_status_board'),
    supabase.rpc('founder_r3179_root_cause_pareto'),
    supabase.rpc('founder_r3179_regulatory_impact_digest'),
    supabase.rpc('founder_r3179_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const deviceRows: DeviceRow[] = (deviceRes.data as DeviceRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'calibration_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'deviations', header: 'Deviations' },
    { key: 'failed', header: 'Failed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'recal_required', header: 'Recal Reqd' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const deviceCols: Column<DeviceRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_rpm_error', header: 'Avg RPM Err %' },
    { key: 'avg_temp_error', header: 'Avg Temp Err %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'calibration_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'deviations', header: 'Deviations' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'lab_section', header: 'Lab Section' },
    { key: 'device_asset_tag', header: 'Asset' },
    { key: 'device_type', header: 'Device' },
    { key: 'calibration_date', header: 'Date' },
    { key: 'calibration_verdict', header: 'Verdict' },
    { key: 'rpm_error_pct', header: 'RPM Err %' },
    { key: 'temp_error_pct', header: 'Temp Err %' },
    { key: 'rotor_integrity', header: 'Rotor' },
    { key: 'lid_interlock_status', header: 'Lid Interlock' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Laboratory Centrifuge &amp; Incubator-Shaker Calibration Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Lab equipment QA log — device type &times; set/measured rpm &amp; temperature &times; error % &times;
        timer accuracy &times; rotor integrity &times; lid interlock &amp; CAPA closure. Founder-gated view:
        calibration verdicts, hospital scorecards, device-type matrix, root-cause pareto, and
        regulatory-impact digest across NABL, NABH &amp; ISO 15189 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Calibration verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No calibration audits logged yet."
          rowKey={(r, i) => String(r.calibration_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital calibration scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device-type performance matrix</h2>
        <DataTable
          rows={deviceRows}
          columns={deviceCols}
          emptyMessage="No device-type data."
          rowKey={(r, i) => String(r.device_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Calibration daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.calibration_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk device priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_asset_tag}-${r.calibration_date}-${i}`}
        />
      </section>
    </main>
  );
}
