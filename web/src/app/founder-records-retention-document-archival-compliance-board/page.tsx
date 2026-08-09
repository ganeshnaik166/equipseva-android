import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { retention_status: string; record_rows: number; pct: number };
type FuncRow = {
  owning_function: string;
  total_rows: number;
  compliant: number;
  backlog: number;
  overdue_destruction: number;
  legal_holds: number;
  untracked: number;
  avg_archived_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  storage_medium: string;
  retention_status: string;
  record_rows: number;
  records_active_total: number;
  avg_archived_pct: number;
};
type TrendRow = {
  period_month: string;
  record_rows: number;
  records_active_total: number;
  due_archival_total: number;
  avg_archived_pct: number;
  destruction_due_total: number;
  destroyed_on_schedule_total: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_impact_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_cost_rupees: number;
  pct: number;
};
type DigestRow = {
  record_class: string;
  rows_tracked: number;
  due_archival_total: number;
  destruction_due_total: number;
  legal_hold_total: number;
  storage_cost_total_rupees: number;
  avg_archived_pct: number;
};
type RiskRow = {
  site_name: string;
  record_code: string;
  record_class: string;
  owning_function: string;
  period_month: string;
  retention_status: string;
  archived_pct: number | null;
  destruction_due: number;
  legal_hold_count: number;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    funcRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3674_retention_status_rollup'),
    supabase.rpc('founder_r3674_owning_function_scorecard'),
    supabase.rpc('founder_r3674_storage_medium_status_matrix'),
    supabase.rpc('founder_r3674_monthly_archival_trend'),
    supabase.rpc('founder_r3674_capa_status_board'),
    supabase.rpc('founder_r3674_root_cause_pareto'),
    supabase.rpc('founder_r3674_backlog_digest'),
    supabase.rpc('founder_r3674_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const funcRows: FuncRow[] = (funcRes.data as FuncRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'record_rows', header: 'Record Classes' },
    { key: 'pct', header: 'Share %' },
  ];

  const funcCols: Column<FuncRow>[] = [
    { key: 'owning_function', header: 'Owning Function' },
    { key: 'total_rows', header: 'Tracked' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'backlog', header: 'Archival Backlog' },
    { key: 'overdue_destruction', header: 'Destruction Overdue' },
    { key: 'legal_holds', header: 'Legal Hold' },
    { key: 'untracked', header: 'Untracked' },
    { key: 'avg_archived_pct', header: 'Avg Archived %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'storage_medium', header: 'Storage Medium' },
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'record_rows', header: 'Rows' },
    { key: 'records_active_total', header: 'Active Records' },
    { key: 'avg_archived_pct', header: 'Avg Archived %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'record_rows', header: 'Rows' },
    { key: 'records_active_total', header: 'Active Records' },
    { key: 'due_archival_total', header: 'Due Archival' },
    { key: 'avg_archived_pct', header: 'Avg Archived %' },
    { key: 'destruction_due_total', header: 'Destruction Due' },
    { key: 'destroyed_on_schedule_total', header: 'Destroyed On Schedule' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_impact_cost_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_cost_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'record_class', header: 'Record Class' },
    { key: 'rows_tracked', header: 'Rows' },
    { key: 'due_archival_total', header: 'Due Archival' },
    { key: 'destruction_due_total', header: 'Destruction Due' },
    { key: 'legal_hold_total', header: 'Legal Holds' },
    { key: 'storage_cost_total_rupees', header: 'Storage Cost (INR)' },
    { key: 'avg_archived_pct', header: 'Avg Archived %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'record_code', header: 'Record Code' },
    { key: 'record_class', header: 'Class' },
    { key: 'owning_function', header: 'Function' },
    { key: 'period_month', header: 'Month' },
    { key: 'retention_status', header: 'Status' },
    { key: 'archived_pct', header: 'Archived %' },
    { key: 'destruction_due', header: 'Destruction Due' },
    { key: 'legal_hold_count', header: 'Legal Holds' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Records-Retention / Document-Archival Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Records-retention and archival compliance log — record class (BMR, DHR, invoice ledgers,
        calibration certificates, import licenses, training records) &times; owning function
        &times; retention years &times; archived % &times; destruction schedule &times; legal
        holds &times; storage medium (physical vault, onsite cabinet, cloud archive, offsite
        vendor, hybrid) &amp; CAPA closure. Founder-gated view: retention-status rollups,
        owning-function scorecards, root-cause pareto, and a high-risk queue for untracked
        &amp; destruction-overdue record classes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Retention status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No retention rows logged yet."
          rowKey={(r, i) => String(r.retention_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Owning-function compliance scorecard</h2>
        <DataTable
          rows={funcRows}
          columns={funcCols}
          emptyMessage="No owning-function rollups."
          rowKey={(r, i) => String(r.owning_function ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Storage medium &times; retention status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No storage-medium rollups."
          rowKey={(r, i) => `${r.storage_medium}-${r.retention_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly archival trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Backlog digest by record class</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No backlog digest rows."
          rowKey={(r, i) => String(r.record_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk retention queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk record classes."
          rowKey={(r, i) => `${r.record_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
