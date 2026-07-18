import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { utilisation_verdict: string; engineer_weeks: number; pct: number };
type HospRow = {
  hospital_name: string;
  engineer_weeks: number;
  avg_utilisation_pct: number;
  total_billable_hours: number;
  total_bench_hours: number;
  cross_vertical_jobs: number;
  skill_gaps_requested: number;
};
type VerticalRow = {
  primary_vertical: string;
  engineer_weeks: number;
  avg_utilisation_pct: number;
  avg_secondary_verticals: number;
  cross_vertical_jobs: number;
  bench_heavy: number;
};
type TrendRow = {
  week_start_date: string;
  engineer_weeks: number;
  avg_utilisation_pct: number;
  total_billable_hours: number;
  total_bench_hours: number;
  cross_vertical_jobs: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  escalated_or_overdue: number;
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
  engineer_name: string;
  engineer_code: string;
  week_start_date: string;
  primary_vertical: string;
  utilisation_pct: number;
  bench_hours: number;
  skill_gap_requested: string;
  utilisation_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    verticalRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3204_verdict_rollup'),
    supabase.rpc('founder_r3204_hospital_scorecard'),
    supabase.rpc('founder_r3204_vertical_matrix'),
    supabase.rpc('founder_r3204_weekly_trend'),
    supabase.rpc('founder_r3204_capa_status_board'),
    supabase.rpc('founder_r3204_root_cause_pareto'),
    supabase.rpc('founder_r3204_regulatory_impact_digest'),
    supabase.rpc('founder_r3204_bench_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const verticalRows: VerticalRow[] = (verticalRes.data as VerticalRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'utilisation_verdict', header: 'Verdict' },
    { key: 'engineer_weeks', header: 'Engineer-Weeks' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_weeks', header: 'Engineer-Weeks' },
    { key: 'avg_utilisation_pct', header: 'Avg Utilisation %' },
    { key: 'total_billable_hours', header: 'Billable Hrs' },
    { key: 'total_bench_hours', header: 'Bench Hrs' },
    { key: 'cross_vertical_jobs', header: 'Cross-Vertical Jobs' },
    { key: 'skill_gaps_requested', header: 'Skill Gaps' },
  ];

  const verticalCols: Column<VerticalRow>[] = [
    { key: 'primary_vertical', header: 'Primary Vertical' },
    { key: 'engineer_weeks', header: 'Engineer-Weeks' },
    { key: 'avg_utilisation_pct', header: 'Avg Utilisation %' },
    { key: 'avg_secondary_verticals', header: 'Avg Secondary Verticals' },
    { key: 'cross_vertical_jobs', header: 'Cross-Vertical Jobs' },
    { key: 'bench_heavy', header: 'Bench-Heavy / Under' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_start_date', header: 'Week Start' },
    { key: 'engineer_weeks', header: 'Engineer-Weeks' },
    { key: 'avg_utilisation_pct', header: 'Avg Utilisation %' },
    { key: 'total_billable_hours', header: 'Billable Hrs' },
    { key: 'total_bench_hours', header: 'Bench Hrs' },
    { key: 'cross_vertical_jobs', header: 'Cross-Vertical Jobs' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'escalated_or_overdue', header: 'Escalated / Overdue' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'engineer_code', header: 'Code' },
    { key: 'week_start_date', header: 'Week' },
    { key: 'primary_vertical', header: 'Primary Vertical' },
    { key: 'utilisation_pct', header: 'Utilisation %' },
    { key: 'bench_hours', header: 'Bench Hrs' },
    { key: 'skill_gap_requested', header: 'Skill Gap Requested' },
    { key: 'utilisation_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Multi-Skill Cross-Vertical Utilisation &amp; Bench-Time Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Weekly engineer utilisation log — primary vertical &times; secondary verticals &times;
        billable vs bench hours &times; cross-vertical jobs &times; skill-gap requests &amp; CAPA closure.
        Founder-gated view: utilisation verdicts, hospital scorecards, vertical matrices,
        root-cause pareto, and the bench-risk queue across the field-engineer fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Utilisation verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No utilisation snapshots logged yet."
          rowKey={(r, i) => String(r.utilisation_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital utilisation scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Primary vertical matrix</h2>
        <DataTable
          rows={verticalRows}
          columns={verticalCols}
          emptyMessage="No vertical rollups."
          rowKey={(r, i) => String(r.primary_vertical ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Weekly utilisation trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Bench-risk &amp; skill-gap queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No bench-risk engineers."
          rowKey={(r, i) => `${r.engineer_code}-${r.week_start_date}-${i}`}
        />
      </section>
    </main>
  );
}
