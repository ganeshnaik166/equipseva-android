import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { lifecycle_verdict: string; devices: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_devices: number;
  healthy: number;
  plan_replace: number;
  replace_now: number;
  failed: number;
  runtime_fail: number;
  overdue: number;
  healthy_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  battery_chemistry: string;
  devices: number;
  healthy: number;
  avg_degradation_pct: number;
  avg_charge_cycles: number;
};
type TrendRow = {
  assessment_date: string;
  devices: number;
  healthy: number;
  failed: number;
  runtime_fail: number;
  replace_now: number;
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
  device_code: string;
  equipment_type: string;
  battery_chemistry: string;
  assessment_date: string;
  measured_capacity_pct: number | null;
  capacity_degradation_pct: number | null;
  runtime_meets_spec: boolean | null;
  health_status: string;
  lifecycle_verdict: string;
  replacement_due_date: string | null;
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
    supabase.rpc('founder_r3364_lifecycle_verdict_rollup'),
    supabase.rpc('founder_r3364_hospital_scorecard'),
    supabase.rpc('founder_r3364_equipment_chemistry_matrix'),
    supabase.rpc('founder_r3364_daily_assessment_trend'),
    supabase.rpc('founder_r3364_capa_status_board'),
    supabase.rpc('founder_r3364_root_cause_pareto'),
    supabase.rpc('founder_r3364_regulatory_impact_digest'),
    supabase.rpc('founder_r3364_high_risk_queue'),
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
    { key: 'lifecycle_verdict', header: 'Lifecycle Verdict' },
    { key: 'devices', header: 'Devices' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_devices', header: 'Devices' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'plan_replace', header: 'Plan Replace' },
    { key: 'replace_now', header: 'Replace Now' },
    { key: 'failed', header: 'Failed' },
    { key: 'runtime_fail', header: 'Runtime Fail' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'battery_chemistry', header: 'Chemistry' },
    { key: 'devices', header: 'Devices' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'avg_degradation_pct', header: 'Avg Degradation %' },
    { key: 'avg_charge_cycles', header: 'Avg Charge Cycles' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'assessment_date', header: 'Date' },
    { key: 'devices', header: 'Devices' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'failed', header: 'Failed' },
    { key: 'runtime_fail', header: 'Runtime Fail' },
    { key: 'replace_now', header: 'Replace Now' },
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
    { key: 'device_code', header: 'Device' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'battery_chemistry', header: 'Chemistry' },
    { key: 'assessment_date', header: 'Date' },
    { key: 'measured_capacity_pct', header: 'Measured %' },
    { key: 'capacity_degradation_pct', header: 'Degradation %' },
    { key: 'runtime_meets_spec', header: 'Runtime OK' },
    { key: 'health_status', header: 'Health' },
    { key: 'lifecycle_verdict', header: 'Verdict' },
    { key: 'replacement_due_date', header: 'Replace Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Equipment Battery Health &amp; Replacement Lifecycle Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Battery-backed device fleet — equipment type &times; battery chemistry &times; measured
        capacity %  &times; capacity degradation &times; charge cycles &times; runtime-test minutes
        &times; battery age &times; replacement-due date &times; health status &times; lifecycle
        verdict &amp; CAPA closure. Founder-gated view: lifecycle verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces so ageing
        monitors, pumps, ventilators, defibrillators &amp; UPS packs get replaced before they fail.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Lifecycle verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No battery assessments logged yet."
          rowKey={(r, i) => String(r.lifecycle_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital battery health scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; chemistry matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No devices by type."
          rowKey={(r, i) => `${r.equipment_type}-${r.battery_chemistry}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily assessment trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.assessment_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk battery queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk batteries."
          rowKey={(r, i) => `${r.device_code}-${r.assessment_date}-${i}`}
        />
      </section>
    </main>
  );
}
