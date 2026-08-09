import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { db_status: string; snapshots: number; pct: number };
type AreaRow = {
  schema_area: string;
  snapshots: number;
  healthy: number;
  tuning_due: number;
  index_gap: number;
  critical_or_bloat: number;
  total_slow_queries: number;
  avg_p95_ms: number;
  avg_bloat_pct: number;
};
type MatrixRow = {
  area_class: string;
  db_status: string;
  snapshots: number;
  total_slow_queries: number;
  avg_bloat_pct: number;
  total_lock_waits: number;
};
type TrendRow = {
  period_month: string;
  snapshots: number;
  total_slow_queries: number;
  avg_p95_ms: number;
  total_lock_waits: number;
  worsening_areas: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_ms_saved: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_ms_saved: number;
  pct: number;
};
type IdxRow = {
  table_group: string;
  schema_area: string;
  snapshots: number;
  total_unused_indexes: number;
  total_missing_candidates: number;
  total_seq_scans_heavy: number;
};
type RiskRow = {
  snapshot_code: string;
  schema_area: string;
  table_group: string;
  period_month: string;
  db_status: string;
  trend_dir: string;
  slow_queries: number;
  p95_query_ms: number | null;
  table_bloat_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    areaRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    idxRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3701_db_status_rollup'),
    supabase.rpc('founder_r3701_schema_area_scorecard'),
    supabase.rpc('founder_r3701_area_class_status_matrix'),
    supabase.rpc('founder_r3701_monthly_slow_query_trend'),
    supabase.rpc('founder_r3701_capa_status_board'),
    supabase.rpc('founder_r3701_root_cause_pareto'),
    supabase.rpc('founder_r3701_index_gap_digest'),
    supabase.rpc('founder_r3701_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const areaRows: AreaRow[] = (areaRes.data as AreaRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const idxRows: IdxRow[] = (idxRes.data as IdxRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'db_status', header: 'DB Status' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'pct', header: 'Share %' },
  ];

  const areaCols: Column<AreaRow>[] = [
    { key: 'schema_area', header: 'Schema Area' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'tuning_due', header: 'Tuning Due' },
    { key: 'index_gap', header: 'Index Gap' },
    { key: 'critical_or_bloat', header: 'Critical / Bloat' },
    { key: 'total_slow_queries', header: 'Slow Queries' },
    { key: 'avg_p95_ms', header: 'Avg p95 ms' },
    { key: 'avg_bloat_pct', header: 'Avg Bloat %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'area_class', header: 'Area Class' },
    { key: 'db_status', header: 'DB Status' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'total_slow_queries', header: 'Slow Queries' },
    { key: 'avg_bloat_pct', header: 'Avg Bloat %' },
    { key: 'total_lock_waits', header: 'Lock Waits' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'total_slow_queries', header: 'Slow Queries' },
    { key: 'avg_p95_ms', header: 'Avg p95 ms' },
    { key: 'total_lock_waits', header: 'Lock Waits' },
    { key: 'worsening_areas', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_ms_saved', header: 'Avg ms Saved' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_ms_saved', header: 'Total ms Saved' },
    { key: 'pct', header: 'Share %' },
  ];

  const idxCols: Column<IdxRow>[] = [
    { key: 'table_group', header: 'Table Group' },
    { key: 'schema_area', header: 'Schema Area' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'total_unused_indexes', header: 'Unused Indexes' },
    { key: 'total_missing_candidates', header: 'Missing Candidates' },
    { key: 'total_seq_scans_heavy', header: 'Heavy Seq Scans' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'snapshot_code', header: 'Snapshot' },
    { key: 'schema_area', header: 'Schema Area' },
    { key: 'table_group', header: 'Table Group' },
    { key: 'period_month', header: 'Month' },
    { key: 'db_status', header: 'DB Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'slow_queries', header: 'Slow Queries' },
    { key: 'p95_query_ms', header: 'p95 ms' },
    { key: 'table_bloat_pct', header: 'Bloat %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Database Slow-Query / Index-Health Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Database internals health board — schema area &times; table group &times; slow queries
        &times; p95 query ms &times; heavy seq scans &times; unused indexes &times; missing-index
        candidates &times; table bloat % &times; connection peaks &times; lock waits &times;
        autovacuum lag &amp; tuning CAPA closure. Founder-gated view: DB status rollups,
        schema-area scorecards, root-cause pareto, and index-gap digest across marketplace_core,
        payments_ledger, notifications_queue, analytics_rollups &amp; auth_identity.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. DB status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No DB health snapshots logged yet."
          rowKey={(r, i) => String(r.db_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Schema-area scorecard</h2>
        <DataTable
          rows={areaRows}
          columns={areaCols}
          emptyMessage="No schema-area rollups."
          rowKey={(r, i) => String(r.schema_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Area class &times; DB status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No snapshots by area class."
          rowKey={(r, i) => `${r.area_class}-${r.db_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly slow-query trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Index-gap digest</h2>
        <DataTable
          rows={idxRows}
          columns={idxCols}
          emptyMessage="No index-gap rollups."
          rowKey={(r, i) => `${r.table_group}-${r.schema_area}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk snapshots."
          rowKey={(r, i) => `${r.snapshot_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
