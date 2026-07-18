import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { machine_verdict: string; checks: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  released: number;
  quarantined: number;
  withdrawn: number;
  lp_leak_fail: number;
  circuit_fail: number;
  vaporizer_drift: number;
  fitness_pct: number;
};
type AgentVapRow = {
  anaesthetic_agent: string;
  vaporizer_type: string;
  checks: number;
  released: number;
  avg_output_pct: number;
};
type TrendRow = {
  check_date: string;
  lp_pass: number;
  lp_fail: number;
  lp_borderline: number;
  circuit_pass: number;
  circuit_fail: number;
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
  ot_room_code: string;
  machine_asset_tag: string;
  check_date: string;
  machine_verdict: string;
  vaporizer_output_verdict: string | null;
  low_pressure_leak_verdict: string | null;
  circuit_leak_test: string | null;
  scavenging_test: string | null;
  backup_o2_cylinder: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    agentVapRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3140_verdict_rollup'),
    supabase.rpc('founder_r3140_hospital_scorecard'),
    supabase.rpc('founder_r3140_agent_vaporizer_matrix'),
    supabase.rpc('founder_r3140_leak_daily_trend'),
    supabase.rpc('founder_r3140_capa_status_board'),
    supabase.rpc('founder_r3140_root_cause_pareto'),
    supabase.rpc('founder_r3140_regulatory_impact_digest'),
    supabase.rpc('founder_r3140_high_risk_checks'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const agentVapRows: AgentVapRow[] = (agentVapRes.data as AgentVapRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'machine_verdict', header: 'Verdict' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'withdrawn', header: 'Withdrawn' },
    { key: 'lp_leak_fail', header: 'LP Leak Fail' },
    { key: 'circuit_fail', header: 'Circuit Fail' },
    { key: 'vaporizer_drift', header: 'Vaporizer Drift' },
    { key: 'fitness_pct', header: 'Fitness %' },
  ];

  const agentVapCols: Column<AgentVapRow>[] = [
    { key: 'anaesthetic_agent', header: 'Agent' },
    { key: 'vaporizer_type', header: 'Vaporizer' },
    { key: 'checks', header: 'Checks' },
    { key: 'released', header: 'Released' },
    { key: 'avg_output_pct', header: 'Avg Output %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'lp_pass', header: 'LP Pass' },
    { key: 'lp_fail', header: 'LP Fail' },
    { key: 'lp_borderline', header: 'LP Borderline' },
    { key: 'circuit_pass', header: 'Circuit Pass' },
    { key: 'circuit_fail', header: 'Circuit Fail' },
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
    { key: 'ot_room_code', header: 'OT' },
    { key: 'machine_asset_tag', header: 'Asset' },
    { key: 'check_date', header: 'Date' },
    { key: 'machine_verdict', header: 'Verdict' },
    { key: 'vaporizer_output_verdict', header: 'Vaporizer' },
    { key: 'low_pressure_leak_verdict', header: 'LP Leak' },
    { key: 'circuit_leak_test', header: 'Circuit' },
    { key: 'scavenging_test', header: 'Scavenging' },
    { key: 'backup_o2_cylinder', header: 'Backup O2' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Anaesthesia Machine Vaporizer &amp; Circuit-Leak Pre-Use Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Pre-use anaesthesia machine check log — anaesthetic agent &times; vaporizer output % &times;
        low-pressure leak (mL/min) &times; circuit leak &times; O2 flush &times; scavenging &times; backup O2 &amp; CAPA
        closure. Founder-gated view: machine verdicts, hospital fitness scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Machine verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No machine checks logged yet."
          rowKey={(r, i) => String(r.machine_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital fitness scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Agent &times; vaporizer matrix</h2>
        <DataTable
          rows={agentVapRows}
          columns={agentVapCols}
          emptyMessage="No checks by agent."
          rowKey={(r, i) => `${r.anaesthetic_agent}-${r.vaporizer_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Low-pressure &amp; circuit leak daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk machines queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk machines."
          rowKey={(r, i) => `${r.machine_asset_tag}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
