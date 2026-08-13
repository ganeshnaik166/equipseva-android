import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { retention_status: string; records: number; pct: number };
type SystemRow = {
  system_name: string;
  records: number;
  compliant_records: number;
  purge_backlog_records: number;
  total_purge_backlog: number;
  avg_purge_delay_days: number | null;
  total_storage_cost_rupees: number | null;
};
type MatrixRow = {
  category_class: string;
  retention_status: string;
  records: number;
  avg_purge_delay_days: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_backlog: number;
  total_due_for_purge: number;
  total_purged: number;
  worsening_records: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  category_class: string;
  records: number;
  total_backlog: number;
  legal_hold_records: number;
  verification_not_logged: number;
  avg_purge_delay_days: number | null;
  total_storage_cost_rupees: number | null;
};
type RiskRow = {
  data_category: string;
  system_name: string;
  category_class: string;
  period_month: string;
  retention_status: string;
  purge_backlog: number | null;
  avg_purge_delay_days: number | null;
  legal_hold_override: boolean;
  purge_verification_logged: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    systemRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3737_retention_status_rollup'),
    supabase.rpc('founder_r3737_system_name_scorecard'),
    supabase.rpc('founder_r3737_category_class_status_matrix'),
    supabase.rpc('founder_r3737_monthly_purge_backlog_trend'),
    supabase.rpc('founder_r3737_capa_status_board'),
    supabase.rpc('founder_r3737_root_cause_pareto'),
    supabase.rpc('founder_r3737_backlog_digest'),
    supabase.rpc('founder_r3737_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const systemRows: SystemRow[] = (systemRes.data as SystemRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const systemCols: Column<SystemRow>[] = [
    { key: 'system_name', header: 'System' },
    { key: 'records', header: 'Records' },
    { key: 'compliant_records', header: 'Compliant' },
    { key: 'purge_backlog_records', header: 'Backlog Records' },
    { key: 'total_purge_backlog', header: 'Total Backlog' },
    { key: 'avg_purge_delay_days', header: 'Avg Purge Delay (days)' },
    { key: 'total_storage_cost_rupees', header: 'Storage Cost (₹)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category_class', header: 'Category Class' },
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_purge_delay_days', header: 'Avg Purge Delay (days)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_backlog', header: 'Total Backlog' },
    { key: 'total_due_for_purge', header: 'Total Due for Purge' },
    { key: 'total_purged', header: 'Total Purged' },
    { key: 'worsening_records', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'category_class', header: 'Category Class' },
    { key: 'records', header: 'Records' },
    { key: 'total_backlog', header: 'Total Backlog' },
    { key: 'legal_hold_records', header: 'Legal Hold' },
    { key: 'verification_not_logged', header: 'Verification Not Logged' },
    { key: 'avg_purge_delay_days', header: 'Avg Purge Delay (days)' },
    { key: 'total_storage_cost_rupees', header: 'Storage Cost (₹)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'data_category', header: 'Data Category' },
    { key: 'system_name', header: 'System' },
    { key: 'category_class', header: 'Category Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'purge_backlog', header: 'Purge Backlog' },
    { key: 'avg_purge_delay_days', header: 'Avg Purge Delay (days)' },
    { key: 'legal_hold_override', header: 'Legal Hold' },
    { key: 'purge_verification_logged', header: 'Verification Logged' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Data-Retention Policy / Data-Purge Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Retention-schedule adherence &amp; systematic data-purge compliance per data category
        (customer PII, employee records, financial records, clinical service logs, marketing
        data) &times; system &times; period month &mdash; retention period vs actual, purge-due
        backlog, legal-hold overrides, purge-verification logging, average purge delay &amp;
        storage cost &times; CAPA closure. This board tracks proactive, systematic
        retention-schedule compliance specifically &mdash; it is distinct from any DPDP
        data-principal-request/DSAR-fulfilment page (individual request-driven access/erasure)
        and from any legal-hold/e-discovery page (preservation, not scheduled purge).
        Founder-gated view: retention-status distribution, system scorecards, backlog digest,
        root-cause pareto, and a high-risk queue of policy-violation or backlog categories.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Retention-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No retention rows logged yet."
          rowKey={(r, i) => String(r.retention_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. System-name scorecard</h2>
        <DataTable
          rows={systemRows}
          columns={systemCols}
          emptyMessage="No system rollups."
          rowKey={(r, i) => String(r.system_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category class &times; retention status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by category class."
          rowKey={(r, i) => `${r.category_class}-${r.retention_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly purge-backlog trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Purge-backlog digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No purge-backlog risk identified."
          rowKey={(r, i) => String(r.category_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk retention queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk retention categories."
          rowKey={(r, i) => `${r.data_category}-${r.system_name}-${i}`}
        />
      </section>
    </main>
  );
}
