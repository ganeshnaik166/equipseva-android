import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { latency_verdict: string; tests: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_tests: number;
  within_target: number;
  breaches: number;
  critical_breaches: number;
  dead_zones: number;
  annunciator_failures: number;
  avg_trigger_display_sec: number;
  compliance_pct: number;
};
type CallTypeRow = {
  call_type: string;
  escalation_tier_result: string | null;
  tests: number;
  within_target: number;
  avg_trigger_display_sec: number;
};
type TrendRow = {
  test_date: string;
  tests: number;
  code_blue_tests: number;
  avg_trigger_display_sec: number;
  avg_display_ack_sec: number | null;
  breaches: number;
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
  ward_name: string;
  zone_code: string;
  test_date: string;
  call_type: string;
  trigger_to_display_seconds: number;
  latency_verdict: string;
  escalation_tier_result: string | null;
  dead_zone_found: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    callTypeRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3191_latency_verdict_rollup'),
    supabase.rpc('founder_r3191_hospital_scorecard'),
    supabase.rpc('founder_r3191_call_type_matrix'),
    supabase.rpc('founder_r3191_daily_latency_trend'),
    supabase.rpc('founder_r3191_capa_status_board'),
    supabase.rpc('founder_r3191_root_cause_pareto'),
    supabase.rpc('founder_r3191_regulatory_impact_digest'),
    supabase.rpc('founder_r3191_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const callTypeRows: CallTypeRow[] = (callTypeRes.data as CallTypeRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'latency_verdict', header: 'Verdict' },
    { key: 'tests', header: 'Tests' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_tests', header: 'Tests' },
    { key: 'within_target', header: 'Within Target' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'critical_breaches', header: 'Critical' },
    { key: 'dead_zones', header: 'Dead Zones' },
    { key: 'annunciator_failures', header: 'Annunciator Fails' },
    { key: 'avg_trigger_display_sec', header: 'Avg Trigger-Display s' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const callTypeCols: Column<CallTypeRow>[] = [
    { key: 'call_type', header: 'Call Type' },
    { key: 'escalation_tier_result', header: 'Escalation Tier' },
    { key: 'tests', header: 'Tests' },
    { key: 'within_target', header: 'Within Target' },
    { key: 'avg_trigger_display_sec', header: 'Avg Trigger-Display s' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'tests', header: 'Tests' },
    { key: 'code_blue_tests', header: 'Code Blue' },
    { key: 'avg_trigger_display_sec', header: 'Avg Trigger-Display s' },
    { key: 'avg_display_ack_sec', header: 'Avg Display-Ack s' },
    { key: 'breaches', header: 'Breaches' },
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
    { key: 'ward_name', header: 'Ward' },
    { key: 'zone_code', header: 'Zone' },
    { key: 'test_date', header: 'Date' },
    { key: 'call_type', header: 'Call Type' },
    { key: 'trigger_to_display_seconds', header: 'Trigger-Display s' },
    { key: 'latency_verdict', header: 'Verdict' },
    { key: 'escalation_tier_result', header: 'Escalation' },
    { key: 'dead_zone_found', header: 'Dead Zone' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Nurse-Call &amp; Code-Blue Alert System Latency Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Nurse-call QA log — zone/ward &times; call type &times; trigger-to-display &times;
        display-to-ack &times; annunciator &times; battery backup &times; escalation tier &amp; CAPA closure.
        Founder-gated view: latency verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; patient-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Latency verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No latency tests logged yet."
          rowKey={(r, i) => String(r.latency_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital latency scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Call type &times; escalation tier matrix</h2>
        <DataTable
          rows={callTypeRows}
          columns={callTypeCols}
          emptyMessage="No tests by call type."
          rowKey={(r, i) => `${r.call_type}-${r.escalation_tier_result}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily latency trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk test queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tests."
          rowKey={(r, i) => `${r.zone_code}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
