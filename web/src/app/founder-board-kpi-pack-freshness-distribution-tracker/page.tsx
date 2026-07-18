import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { pack_verdict: string; packs: number; pct: number };
type EntityRow = {
  hospital_name: string;
  total_kpis: number;
  green: number;
  amber: number;
  red: number;
  on_time: number;
  stale_or_expired: number;
  avg_freshness_days: number;
  green_pct: number;
};
type CategoryRow = {
  metric_category: string;
  owner_function: string;
  kpis: number;
  green: number;
  red: number;
  avg_variance_pct: number;
};
type TrendRow = {
  sent_to_board_date: string;
  packs: number;
  on_time: number;
  late: number;
  avg_freshness_days: number;
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
type PriorityRow = {
  hospital_name: string;
  metric_name: string;
  metric_category: string;
  owner_name: string;
  rag_status: string;
  freshness_band: string;
  variance_pct: number | null;
  sent_to_board_date: string | null;
  pack_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    categoryRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    priorityRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3149_pack_verdict_rollup'),
    supabase.rpc('founder_r3149_entity_scorecard'),
    supabase.rpc('founder_r3149_category_matrix'),
    supabase.rpc('founder_r3149_freshness_trend'),
    supabase.rpc('founder_r3149_capa_status_board'),
    supabase.rpc('founder_r3149_root_cause_pareto'),
    supabase.rpc('founder_r3149_regulatory_impact_digest'),
    supabase.rpc('founder_r3149_priority_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const priorityRows: PriorityRow[] = (priorityRes.data as PriorityRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'pack_verdict', header: 'Pack Verdict' },
    { key: 'packs', header: 'KPIs' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_kpis', header: 'KPIs' },
    { key: 'green', header: 'Green' },
    { key: 'amber', header: 'Amber' },
    { key: 'red', header: 'Red' },
    { key: 'on_time', header: 'On Time' },
    { key: 'stale_or_expired', header: 'Stale / Expired' },
    { key: 'avg_freshness_days', header: 'Avg Freshness (days)' },
    { key: 'green_pct', header: 'Green %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'metric_category', header: 'Category' },
    { key: 'owner_function', header: 'Owner Function' },
    { key: 'kpis', header: 'KPIs' },
    { key: 'green', header: 'Green' },
    { key: 'red', header: 'Red' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'sent_to_board_date', header: 'Sent To Board' },
    { key: 'packs', header: 'KPIs' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'avg_freshness_days', header: 'Avg Freshness (days)' },
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
    { key: 'regulatory_impact', header: 'Governance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const priorityCols: Column<PriorityRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'metric_name', header: 'Metric' },
    { key: 'metric_category', header: 'Category' },
    { key: 'owner_name', header: 'Owner' },
    { key: 'rag_status', header: 'RAG' },
    { key: 'freshness_band', header: 'Freshness' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'sent_to_board_date', header: 'Sent To Board' },
    { key: 'pack_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Monthly Board-KPI Pack Freshness &amp; Distribution Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Board pack KPI log — metric &times; owner &times; target/actual &times; variance &times; data
        freshness &times; RAG status &times; distribution channel &amp; CAPA follow-up. Founder-gated view:
        pack verdicts, entity freshness scorecards, category matrix, root-cause pareto, and
        board-governance impact digest across the monthly board pack.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Pack verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No board-pack KPIs logged yet."
          rowKey={(r, i) => String(r.pack_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity freshness scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; owner-function matrix</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No KPIs by category."
          rowKey={(r, i) => `${r.metric_category}-${r.owner_function}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Distribution &amp; freshness trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No distribution trend data."
          rowKey={(r, i) => String(r.sent_to_board_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Governance impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No governance-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk KPI priority queue</h2>
        <DataTable
          rows={priorityRows}
          columns={priorityCols}
          emptyMessage="No high-risk KPIs."
          rowKey={(r, i) => `${r.hospital_name}-${r.metric_name}-${i}`}
        />
      </section>
    </main>
  );
}
