import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { roster_status: string; weeks: number; pct: number };
type EngRow = {
  engineer_name: string;
  hospital_name: string;
  weeks: number;
  total_hours: number;
  total_calls: number;
  avg_response_min: number;
  avg_sla_met_pct: number;
  avg_fairness_index: number;
  comp_off_due: number;
};
type TierShiftRow = {
  on_call_tier: string;
  shift_pattern: string;
  weeks: number;
  avg_hours: number;
  avg_response_min: number;
  avg_sla_met_pct: number;
};
type TrendRow = {
  week_start_date: string;
  engineers_on_call: number;
  total_calls: number;
  avg_response_min: number;
  avg_sla_met_pct: number;
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
  engineer_name: string;
  hospital_name: string;
  week_start_date: string;
  roster_status: string;
  avg_response_minutes: number | null;
  sla_met_pct: number | null;
  fairness_index: number | null;
  comp_off_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    engRes,
    tierShiftRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3188_roster_status_rollup'),
    supabase.rpc('founder_r3188_engineer_scorecard'),
    supabase.rpc('founder_r3188_tier_shift_matrix'),
    supabase.rpc('founder_r3188_weekly_trend'),
    supabase.rpc('founder_r3188_capa_status_board'),
    supabase.rpc('founder_r3188_root_cause_pareto'),
    supabase.rpc('founder_r3188_regulatory_impact_digest'),
    supabase.rpc('founder_r3188_high_risk_roster_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const tierShiftRows: TierShiftRow[] = (tierShiftRes.data as TierShiftRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'roster_status', header: 'Status' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'total_hours', header: 'On-Call Hours' },
    { key: 'total_calls', header: 'Calls' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
    { key: 'avg_sla_met_pct', header: 'SLA Met %' },
    { key: 'avg_fairness_index', header: 'Fairness Index' },
    { key: 'comp_off_due', header: 'Comp-Off Due' },
  ];

  const tierShiftCols: Column<TierShiftRow>[] = [
    { key: 'on_call_tier', header: 'Tier' },
    { key: 'shift_pattern', header: 'Shift Pattern' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'avg_hours', header: 'Avg Hours' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
    { key: 'avg_sla_met_pct', header: 'SLA Met %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_start_date', header: 'Week Start' },
    { key: 'engineers_on_call', header: 'Engineers' },
    { key: 'total_calls', header: 'Calls' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
    { key: 'avg_sla_met_pct', header: 'SLA Met %' },
    { key: 'breaches', header: 'SLA Breaches' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'week_start_date', header: 'Week Start' },
    { key: 'roster_status', header: 'Status' },
    { key: 'avg_response_minutes', header: 'Avg Response (min)' },
    { key: 'sla_met_pct', header: 'SLA Met %' },
    { key: 'fairness_index', header: 'Fairness' },
    { key: 'comp_off_status', header: 'Comp-Off' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer On-Call Roster Fairness &amp; Response-Time Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        On-call week log &mdash; engineer &times; tier &times; shift pattern &times; response SLA &times;
        weekend share &times; fairness index &times; comp-off &amp; CAPA closure. Founder-gated view:
        roster status rollups, engineer scorecards, weekly response trends, root-cause pareto,
        and regulatory-impact digest across labour-law &amp; contract-SLA surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Roster status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No roster weeks logged yet."
          rowKey={(r, i) => String(r.roster_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer fairness scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => `${r.engineer_name}-${r.hospital_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Tier &times; shift-pattern matrix</h2>
        <DataTable
          rows={tierShiftRows}
          columns={tierShiftCols}
          emptyMessage="No weeks by tier and shift."
          rowKey={(r, i) => `${r.on_call_tier}-${r.shift_pattern}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Weekly response-time trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.week_start_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk roster queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk roster weeks."
          rowKey={(r, i) => `${r.engineer_name}-${r.week_start_date}-${i}`}
        />
      </section>
    </main>
  );
}
