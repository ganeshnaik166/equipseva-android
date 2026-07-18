import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  restricted: number;
  out_of_service: number;
  alarm_fails: number;
  avg_abs_temp_error_c: number;
  fit_pct: number;
};
type DeviceTypeRow = {
  device_type: string;
  audits: number;
  fit_for_use: number;
  alarm_fails: number;
  avg_abs_temp_error_c: number;
};
type TrendRow = {
  test_date: string;
  audits: number;
  alarm_pass: number;
  alarm_fail: number;
  flow_ok: number;
  flow_not_ok: number;
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
  ward_code: string;
  device_asset_tag: string;
  device_type: string;
  test_date: string;
  audit_verdict: string;
  over_temp_alarm_result: string | null;
  temp_error_c: number | null;
  disposable_set_compatibility: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    deviceTypeRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3219_verdict_rollup'),
    supabase.rpc('founder_r3219_hospital_scorecard'),
    supabase.rpc('founder_r3219_device_type_matrix'),
    supabase.rpc('founder_r3219_daily_trend'),
    supabase.rpc('founder_r3219_capa_status_board'),
    supabase.rpc('founder_r3219_root_cause_pareto'),
    supabase.rpc('founder_r3219_regulatory_impact_digest'),
    supabase.rpc('founder_r3219_high_risk_devices'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const deviceTypeRows: DeviceTypeRow[] = (deviceTypeRes.data as DeviceTypeRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'restricted', header: 'Restricted' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'alarm_fails', header: 'Alarm Fails' },
    { key: 'avg_abs_temp_error_c', header: 'Avg |Temp Err| °C' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const deviceTypeCols: Column<DeviceTypeRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'alarm_fails', header: 'Alarm Fails' },
    { key: 'avg_abs_temp_error_c', header: 'Avg |Temp Err| °C' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'alarm_pass', header: 'Alarm Pass' },
    { key: 'alarm_fail', header: 'Alarm Fail' },
    { key: 'flow_ok', header: 'Flow OK' },
    { key: 'flow_not_ok', header: 'Flow Restricted' },
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
    { key: 'ward_code', header: 'Ward' },
    { key: 'device_asset_tag', header: 'Asset' },
    { key: 'device_type', header: 'Type' },
    { key: 'test_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'over_temp_alarm_result', header: 'Alarm' },
    { key: 'temp_error_c', header: 'Temp Err °C' },
    { key: 'disposable_set_compatibility', header: 'Set Compat' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Blood-Warmer &amp; Fluid-Infusion Warming Device Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Warmer QA log — device type &times; set/output temperature &times; temp error &times;
        over-temp alarm test &times; flow-rate range &times; disposable-set compatibility &amp; CAPA closure.
        Founder-gated view: audit verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No warmer audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital warmer scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type matrix</h2>
        <DataTable
          rows={deviceTypeRows}
          columns={deviceTypeCols}
          emptyMessage="No audits by device type."
          rowKey={(r, i) => `${r.device_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Alarm &amp; flow daily trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk devices queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
