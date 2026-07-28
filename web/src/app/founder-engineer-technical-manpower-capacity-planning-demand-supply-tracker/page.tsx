import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type CoverageRow = { coverage_status: string; plans: number; pct: number };
type SkillRow = {
  skill_category: string;
  plans: number;
  total_demand_hours: number;
  total_supply_hours: number;
  total_gap_hours: number;
  avg_utilization_pct: number;
  shortfall_plans: number;
  hiring_needed_total: number;
};
type MatrixRow = {
  skill_category: string;
  coverage_status: string;
  plans: number;
  total_gap_hours: number;
  avg_utilization_pct: number;
};
type TrendRow = {
  period_month: string;
  plans: number;
  total_demand_hours: number;
  total_supply_hours: number;
  total_gap_hours: number;
  avg_utilization_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_gap_impact: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_gap_impact: number;
  pct: number;
};
type ImpactRow = {
  service_impact: string;
  findings: number;
  open_findings: number;
  total_gap_impact: number;
};
type RiskRow = {
  region: string;
  plan_code: string;
  skill_category: string;
  period_month: string;
  coverage_status: string;
  demand_hours: number;
  supply_hours: number;
  capacity_gap_hours: number;
  utilization_pct: number | null;
  hiring_needed: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    coverageRes,
    skillRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3544_coverage_status_rollup'),
    supabase.rpc('founder_r3544_skill_category_scorecard'),
    supabase.rpc('founder_r3544_skill_coverage_matrix'),
    supabase.rpc('founder_r3544_monthly_capacity_trend'),
    supabase.rpc('founder_r3544_capa_status_board'),
    supabase.rpc('founder_r3544_root_cause_pareto'),
    supabase.rpc('founder_r3544_capacity_gap_impact_digest'),
    supabase.rpc('founder_r3544_high_risk_queue'),
  ]);

  const coverageRows: CoverageRow[] = (coverageRes.data as CoverageRow[]) ?? [];
  const skillRows: SkillRow[] = (skillRes.data as SkillRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const coverageCols: Column<CoverageRow>[] = [
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'plans', header: 'Plans' },
    { key: 'pct', header: 'Share %' },
  ];

  const skillCols: Column<SkillRow>[] = [
    { key: 'skill_category', header: 'Skill Category' },
    { key: 'plans', header: 'Plans' },
    { key: 'total_demand_hours', header: 'Demand Hrs' },
    { key: 'total_supply_hours', header: 'Supply Hrs' },
    { key: 'total_gap_hours', header: 'Gap Hrs' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'shortfall_plans', header: 'Shortfall Plans' },
    { key: 'hiring_needed_total', header: 'Hiring Needed' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'skill_category', header: 'Skill Category' },
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'plans', header: 'Plans' },
    { key: 'total_gap_hours', header: 'Gap Hrs' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'plans', header: 'Plans' },
    { key: 'total_demand_hours', header: 'Demand Hrs' },
    { key: 'total_supply_hours', header: 'Supply Hrs' },
    { key: 'total_gap_hours', header: 'Gap Hrs' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_gap_impact', header: 'Avg Gap Impact (Hrs)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_gap_impact', header: 'Total Gap Impact (Hrs)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'service_impact', header: 'Service Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_gap_impact', header: 'Total Gap Impact (Hrs)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'plan_code', header: 'Plan' },
    { key: 'skill_category', header: 'Skill' },
    { key: 'period_month', header: 'Month' },
    { key: 'coverage_status', header: 'Coverage' },
    { key: 'demand_hours', header: 'Demand Hrs' },
    { key: 'supply_hours', header: 'Supply Hrs' },
    { key: 'capacity_gap_hours', header: 'Gap Hrs' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'hiring_needed', header: 'Hiring' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Technical-Manpower Capacity-Planning (Demand/Supply) Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineering capacity plans — region &times; skill category (imaging, lab, biomedical,
        IT/network, HVAC/utility, general) &times; month &times; demand hours &times; available FTE
        &times; supply hours &times; capacity gap &times; utilization &times; contractor hours &times;
        hiring needed &amp; coverage-status verdict, with CAPA closure. Founder-gated view: coverage
        distribution, skill scorecards, demand/supply matrix, monthly trend, root-cause pareto, and a
        high-risk shortfall queue where demand &gt; supply.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage-status distribution</h2>
        <DataTable
          rows={coverageRows}
          columns={coverageCols}
          emptyMessage="No capacity plans logged yet."
          rowKey={(r, i) => String(r.coverage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Skill-category scorecard</h2>
        <DataTable
          rows={skillRows}
          columns={skillCols}
          emptyMessage="No skill-category rollups."
          rowKey={(r, i) => String(r.skill_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Skill-category &times; coverage-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No plans by skill category."
          rowKey={(r, i) => `${r.skill_category}-${r.coverage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly capacity trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Capacity-gap impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.service_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk capacity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk plans."
          rowKey={(r, i) => `${r.plan_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
