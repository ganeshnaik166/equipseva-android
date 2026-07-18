import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; devices: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_devices: number;
  ready: number;
  not_ready: number;
  out_of_service: number;
  self_test_fail: number;
  pads_expired: number;
  avg_energy_error: number;
  readiness_pct: number;
};
type DeviceMatrixRow = {
  device_type: string;
  tests: number;
  ready: number;
  avg_set_energy: number;
  avg_delivered_energy: number;
  avg_energy_error: number;
};
type TrendRow = {
  test_date: string;
  tests: number;
  ready: number;
  not_ready: number;
  self_test_fail: number;
  pads_expired: number;
  avg_energy_error: number;
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
  device_location: string;
  defib_asset_tag: string;
  test_date: string;
  readiness_verdict: string;
  self_test_result: string | null;
  battery_health: string | null;
  pads_status: string | null;
  energy_error_pct: number | null;
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
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3146_readiness_verdict_rollup'),
    supabase.rpc('founder_r3146_hospital_scorecard'),
    supabase.rpc('founder_r3146_device_energy_matrix'),
    supabase.rpc('founder_r3146_readiness_daily_trend'),
    supabase.rpc('founder_r3146_capa_status_board'),
    supabase.rpc('founder_r3146_root_cause_pareto'),
    supabase.rpc('founder_r3146_regulatory_impact_digest'),
    supabase.rpc('founder_r3146_high_risk_devices'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: DeviceMatrixRow[] = (matrixRes.data as DeviceMatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'devices', header: 'Devices' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_devices', header: 'Devices' },
    { key: 'ready', header: 'Ready' },
    { key: 'not_ready', header: 'Not Ready' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'self_test_fail', header: 'Self-Test Fail' },
    { key: 'pads_expired', header: 'Pads Expired' },
    { key: 'avg_energy_error', header: 'Avg Energy Err %' },
    { key: 'readiness_pct', header: 'Readiness %' },
  ];

  const matrixCols: Column<DeviceMatrixRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'tests', header: 'Tests' },
    { key: 'ready', header: 'Ready' },
    { key: 'avg_set_energy', header: 'Avg Set J' },
    { key: 'avg_delivered_energy', header: 'Avg Delivered J' },
    { key: 'avg_energy_error', header: 'Avg Energy Err %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'tests', header: 'Tests' },
    { key: 'ready', header: 'Ready' },
    { key: 'not_ready', header: 'Not Ready' },
    { key: 'self_test_fail', header: 'Self-Test Fail' },
    { key: 'pads_expired', header: 'Pads Expired' },
    { key: 'avg_energy_error', header: 'Avg Energy Err %' },
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
    { key: 'device_location', header: 'Location' },
    { key: 'defib_asset_tag', header: 'Asset' },
    { key: 'test_date', header: 'Date' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'self_test_result', header: 'Self-Test' },
    { key: 'battery_health', header: 'Battery' },
    { key: 'pads_status', header: 'Pads' },
    { key: 'energy_error_pct', header: 'Energy Err %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Defibrillator &amp; AED Readiness / Energy-Delivery Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Defibrillator &amp; AED readiness log — device type &times; set/delivered energy &times; energy
        error % &times; charge time &times; battery &amp; pads expiry &times; self-test &times; ECG trace &amp; CAPA
        closure. Founder-gated view: readiness verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No devices logged yet."
          rowKey={(r, i) => String(r.readiness_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital readiness scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type &times; energy matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No devices by type."
          rowKey={(r, i) => `${r.device_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Readiness daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk device queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.defib_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
