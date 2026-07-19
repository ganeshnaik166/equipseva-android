import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  margin_verdict: string;
  entries: number;
  total_revenue_rupees: number;
  total_gross_margin_rupees: number;
  pct: number;
};
type ScorecardRow = {
  service_line: string;
  entries: number;
  total_revenue_rupees: number;
  total_gross_margin_rupees: number;
  avg_gross_margin_pct: number;
  parts_cost_rupees: number;
  field_labour_cost_rupees: number;
  travel_logistics_cost_rupees: number;
  warranty_rework_cost_rupees: number;
  potential_uplift_rupees: number;
};
type MatrixRow = {
  service_line: string;
  biggest_cost_driver: string;
  entries: number;
  total_revenue_rupees: number;
  avg_gross_margin_pct: number;
  potential_uplift_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_revenue_rupees: number;
  total_gross_margin_rupees: number;
  avg_gross_margin_pct: number;
  potential_uplift_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_uplift_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_uplift_rupees: number;
  pct: number;
};
type ImpactRow = {
  financial_impact: string;
  findings: number;
  open_findings: number;
  total_uplift_rupees: number;
};
type LeakRow = {
  service_line: string;
  period_month: string;
  revenue_rupees: number;
  gross_margin_pct: number;
  margin_vs_target_pct: number;
  biggest_cost_driver: string | null;
  improvement_lever: string | null;
  potential_uplift_rupees: number;
  margin_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    leakRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3381_margin_verdict_rollup'),
    supabase.rpc('founder_r3381_service_line_scorecard'),
    supabase.rpc('founder_r3381_service_line_driver_matrix'),
    supabase.rpc('founder_r3381_period_margin_trend'),
    supabase.rpc('founder_r3381_capa_status_board'),
    supabase.rpc('founder_r3381_root_cause_pareto'),
    supabase.rpc('founder_r3381_financial_impact_digest'),
    supabase.rpc('founder_r3381_margin_leak_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const leakRows: LeakRow[] = (leakRes.data as LeakRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'margin_verdict', header: 'Margin Verdict' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_gross_margin_rupees', header: 'Gross Margin (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'service_line', header: 'Service Line' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_gross_margin_rupees', header: 'Gross Margin (INR)' },
    { key: 'avg_gross_margin_pct', header: 'Avg GM %' },
    { key: 'parts_cost_rupees', header: 'Parts Cost (INR)' },
    { key: 'field_labour_cost_rupees', header: 'Labour Cost (INR)' },
    { key: 'travel_logistics_cost_rupees', header: 'Travel Cost (INR)' },
    { key: 'warranty_rework_cost_rupees', header: 'Rework Cost (INR)' },
    { key: 'potential_uplift_rupees', header: 'Potential Uplift (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_line', header: 'Service Line' },
    { key: 'biggest_cost_driver', header: 'Biggest Cost Driver' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'avg_gross_margin_pct', header: 'Avg GM %' },
    { key: 'potential_uplift_rupees', header: 'Potential Uplift (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_gross_margin_rupees', header: 'Gross Margin (INR)' },
    { key: 'avg_gross_margin_pct', header: 'Avg GM %' },
    { key: 'potential_uplift_rupees', header: 'Potential Uplift (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_uplift_rupees', header: 'Avg Uplift (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_uplift_rupees', header: 'Total Uplift (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_uplift_rupees', header: 'Total Uplift (INR)' },
  ];

  const leakCols: Column<LeakRow>[] = [
    { key: 'service_line', header: 'Service Line' },
    { key: 'period_month', header: 'Period' },
    { key: 'revenue_rupees', header: 'Revenue (INR)' },
    { key: 'gross_margin_pct', header: 'GM %' },
    { key: 'margin_vs_target_pct', header: 'GM vs Target %' },
    { key: 'biggest_cost_driver', header: 'Cost Driver' },
    { key: 'improvement_lever', header: 'Lever' },
    { key: 'potential_uplift_rupees', header: 'Potential Uplift (INR)' },
    { key: 'margin_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Gross-Margin Bridge &amp; Cost-of-Service Decomposition Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder finance board — service line &times; period &times; revenue &rarr; gross margin,
        decomposed by cost driver (parts &times; field labour &times; travel-logistics &times;
        warranty-rework). Surfaces where margin leaks, the biggest cost driver and improvement lever
        per line, potential-uplift priorities, and CAPA closure. Founder-gated view: margin verdicts,
        service-line scorecards, driver matrix, period trend, root-cause pareto, and
        financial-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Margin verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No margin bridge rows yet."
          rowKey={(r, i) => String(r.margin_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Service-line margin scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No service-line rollups."
          rowKey={(r, i) => String(r.service_line ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service-line &times; cost-driver matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No rows by driver."
          rowKey={(r, i) => `${r.service_line}-${r.biggest_cost_driver}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Period margin trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.financial_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Margin-leak queue</h2>
        <DataTable
          rows={leakRows}
          columns={leakCols}
          emptyMessage="No margin-leak rows."
          rowKey={(r, i) => `${r.service_line}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
