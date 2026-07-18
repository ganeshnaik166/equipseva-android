import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  road_ready: number;
  conditionally_ready: number;
  grounded: number;
  test_failures: number;
  avg_battery_hours: number | null;
  readiness_pct: number;
};
type MatrixRow = {
  equipment_category: string;
  ambulance_type: string;
  audits: number;
  road_ready: number;
  avg_battery_hours: number | null;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  road_ready: number;
  conditionally_ready: number;
  grounded: number;
  test_failures: number;
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
  ambulance_reg_no: string;
  equipment_category: string;
  asset_tag: string;
  audit_date: string;
  readiness_verdict: string;
  battery_status: string | null;
  o2_pressure_verdict: string | null;
  inverter_status: string | null;
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
    supabase.rpc('founder_r3215_readiness_verdict_rollup'),
    supabase.rpc('founder_r3215_hospital_scorecard'),
    supabase.rpc('founder_r3215_equipment_type_matrix'),
    supabase.rpc('founder_r3215_daily_readiness_trend'),
    supabase.rpc('founder_r3215_capa_status_board'),
    supabase.rpc('founder_r3215_root_cause_pareto'),
    supabase.rpc('founder_r3215_regulatory_impact_digest'),
    supabase.rpc('founder_r3215_high_risk_queue'),
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
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'road_ready', header: 'Road Ready' },
    { key: 'conditionally_ready', header: 'Conditional' },
    { key: 'grounded', header: 'Grounded' },
    { key: 'test_failures', header: 'Test Fails' },
    { key: 'avg_battery_hours', header: 'Avg Battery Hrs' },
    { key: 'readiness_pct', header: 'Readiness %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_category', header: 'Equipment' },
    { key: 'ambulance_type', header: 'Ambulance Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'road_ready', header: 'Road Ready' },
    { key: 'avg_battery_hours', header: 'Avg Battery Hrs' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'road_ready', header: 'Road Ready' },
    { key: 'conditionally_ready', header: 'Conditional' },
    { key: 'grounded', header: 'Grounded' },
    { key: 'test_failures', header: 'Test Fails' },
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
    { key: 'ambulance_reg_no', header: 'Reg No' },
    { key: 'equipment_category', header: 'Equipment' },
    { key: 'asset_tag', header: 'Asset' },
    { key: 'audit_date', header: 'Date' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'battery_status', header: 'Battery' },
    { key: 'o2_pressure_verdict', header: 'O2' },
    { key: 'inverter_status', header: 'Inverter' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Ambulance Equipment (Transport-Vent / Monitor / Suction) Readiness Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Ambulance readiness log — vehicle reg &times; equipment category &times; battery backup &times;
        O2 cylinder pressure &times; mounting &amp; inverter checks &times; last-drill date with CAPA closure.
        Founder-gated view: readiness verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; state-transport surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment category &times; ambulance type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by equipment category."
          rowKey={(r, i) => `${r.equipment_category}-${r.ambulance_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily readiness trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk equipment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
