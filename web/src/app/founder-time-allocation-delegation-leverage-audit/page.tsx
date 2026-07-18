import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  roi_verdict: string;
  entries: number;
  total_hours: number;
  pct: number;
};
type EntityRow = {
  entity_name: string;
  entries: number;
  total_hours: number;
  avg_leverage: number;
  delegable_hours: number;
  firefighting_hours: number;
  keep_pct: number;
};
type MatrixRow = {
  activity_bucket: string;
  energy_rating: string;
  entries: number;
  total_hours: number;
  avg_leverage: number;
};
type TrendRow = {
  week_start: string;
  total_hours: number;
  deep_work_hours: number;
  firefighting_hours: number;
  delegable_hours: number;
  avg_leverage: number;
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
type QueueRow = {
  entity_name: string;
  entry_ref: string;
  work_date: string;
  activity_bucket: string;
  hours_spent: number;
  leverage_score: number;
  delegated_to: string;
  energy_rating: string;
  roi_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3197_roi_verdict_rollup'),
    supabase.rpc('founder_r3197_entity_scorecard'),
    supabase.rpc('founder_r3197_bucket_energy_matrix'),
    supabase.rpc('founder_r3197_weekly_time_trend'),
    supabase.rpc('founder_r3197_capa_status_board'),
    supabase.rpc('founder_r3197_root_cause_pareto'),
    supabase.rpc('founder_r3197_regulatory_impact_digest'),
    supabase.rpc('founder_r3197_delegation_priority_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'roi_verdict', header: 'ROI Verdict' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_hours', header: 'Hours' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity / Hospital' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_hours', header: 'Hours' },
    { key: 'avg_leverage', header: 'Avg Leverage' },
    { key: 'delegable_hours', header: 'Delegable Hrs' },
    { key: 'firefighting_hours', header: 'Firefighting Hrs' },
    { key: 'keep_pct', header: 'Keep %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'activity_bucket', header: 'Bucket' },
    { key: 'energy_rating', header: 'Energy' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_hours', header: 'Hours' },
    { key: 'avg_leverage', header: 'Avg Leverage' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_start', header: 'Week Start' },
    { key: 'total_hours', header: 'Total Hrs' },
    { key: 'deep_work_hours', header: 'Deep Work Hrs' },
    { key: 'firefighting_hours', header: 'Firefighting Hrs' },
    { key: 'delegable_hours', header: 'Delegable Hrs' },
    { key: 'avg_leverage', header: 'Avg Leverage' },
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
    { key: 'regulatory_impact', header: 'Reporting Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'entity_name', header: 'Entity / Hospital' },
    { key: 'entry_ref', header: 'Entry' },
    { key: 'work_date', header: 'Date' },
    { key: 'activity_bucket', header: 'Bucket' },
    { key: 'hours_spent', header: 'Hours' },
    { key: 'leverage_score', header: 'Leverage' },
    { key: 'delegated_to', header: 'Delegated To' },
    { key: 'energy_rating', header: 'Energy' },
    { key: 'roi_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Time Allocation &amp; Delegation-Leverage Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Weekly founder time audit &mdash; activity bucket &times; hours &times; leverage score &times;
        delegable flag &times; delegated-to &times; energy rating &amp; ROI verdict, plus rebalance CAPA
        closure. Founder-gated view: verdict rollups, entity scorecards, weekly trend, root-cause
        pareto, and a delegation priority queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. ROI verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No time entries logged yet."
          rowKey={(r, i) => String(r.roi_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity / hospital scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Activity bucket &times; energy matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No bucket rollups."
          rowKey={(r, i) => `${r.activity_bucket}-${r.energy_rating}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Weekly founder-time trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.week_start ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory / reporting impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Delegation priority queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No rebalance candidates."
          rowKey={(r, i) => `${r.entry_ref}-${r.work_date}-${i}`}
        />
      </section>
    </main>
  );
}
