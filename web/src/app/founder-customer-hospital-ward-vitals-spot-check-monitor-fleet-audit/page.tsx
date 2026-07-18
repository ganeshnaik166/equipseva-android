import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; wards: number; pct: number };
type HospRow = {
  hospital_name: string;
  wards_audited: number;
  devices_total: number;
  devices_functional: number;
  fleet_fit_wards: number;
  critical_wards: number;
  avg_battery_pct: number;
  avg_availability_pct: number;
};
type MatrixRow = {
  spo2_probe_condition: string;
  temp_probe_cal_status: string;
  wards: number;
  avg_battery_pct: number;
};
type TrendRow = {
  audit_date: string;
  wards: number;
  fleet_fit: number;
  degraded_or_worse: number;
  avg_availability_pct: number;
  avg_battery_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
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
  ward_name: string;
  audit_date: string;
  audit_verdict: string;
  battery_health_pct: number;
  fleet_availability_pct: number;
  dropped_device_damage: string;
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
    supabase.rpc('founder_r3235_verdict_rollup'),
    supabase.rpc('founder_r3235_hospital_scorecard'),
    supabase.rpc('founder_r3235_probe_cal_matrix'),
    supabase.rpc('founder_r3235_daily_trend'),
    supabase.rpc('founder_r3235_capa_status_board'),
    supabase.rpc('founder_r3235_root_cause_pareto'),
    supabase.rpc('founder_r3235_regulatory_impact_digest'),
    supabase.rpc('founder_r3235_high_risk_wards'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'wards', header: 'Wards' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'wards_audited', header: 'Wards' },
    { key: 'devices_total', header: 'Devices' },
    { key: 'devices_functional', header: 'Functional' },
    { key: 'fleet_fit_wards', header: 'Fleet Fit' },
    { key: 'critical_wards', header: 'Critical' },
    { key: 'avg_battery_pct', header: 'Avg Battery %' },
    { key: 'avg_availability_pct', header: 'Avg Availability %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'spo2_probe_condition', header: 'SpO2 Probe Condition' },
    { key: 'temp_probe_cal_status', header: 'Temp Cal Status' },
    { key: 'wards', header: 'Wards' },
    { key: 'avg_battery_pct', header: 'Avg Battery %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'wards', header: 'Wards' },
    { key: 'fleet_fit', header: 'Fleet Fit' },
    { key: 'degraded_or_worse', header: 'Degraded+' },
    { key: 'avg_availability_pct', header: 'Avg Availability %' },
    { key: 'avg_battery_pct', header: 'Avg Battery %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
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
    { key: 'ward_code', header: 'Ward Code' },
    { key: 'ward_name', header: 'Ward' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'battery_health_pct', header: 'Battery %' },
    { key: 'fleet_availability_pct', header: 'Availability %' },
    { key: 'dropped_device_damage', header: 'Drop Damage' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Ward Vital-Signs Spot-Check Monitor Fleet Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Spot-check monitor fleet log — ward &times; device count &times; NIBP cuff set &times;
        SpO2 probe condition &times; temp-probe calibration &times; battery health &times;
        cleaning compliance &times; drop damage &amp; CAPA closure. Founder-gated view: ward verdicts,
        hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH &amp; biomedical surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No ward audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital fleet scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. SpO2 probe &times; temp cal matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No condition matrix data."
          rowKey={(r, i) => `${r.spo2_probe_condition}-${r.temp_probe_cal_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk wards queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk wards."
          rowKey={(r, i) => `${r.ward_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
