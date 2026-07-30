import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  recovery_status: string;
  advances: number;
  total_outstanding_rupees: number;
  pct: number;
};
type CategoryRow = {
  category: string;
  advances: number;
  total_paid_rupees: number;
  total_adjusted_rupees: number;
  total_outstanding_rupees: number;
  total_overdue_rupees: number;
  stuck_or_writeoff: number;
  avg_po_linked_pct: number;
  current_pct: number;
};
type MatrixRow = {
  aging_bucket: string;
  recovery_status: string;
  advances: number;
  total_outstanding_rupees: number;
  total_overdue_rupees: number;
};
type TrendRow = {
  period_month: string;
  advances: number;
  total_paid_rupees: number;
  total_adjusted_rupees: number;
  total_outstanding_rupees: number;
  total_overdue_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type PriorityRow = {
  recovery_priority: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  vendor_name: string;
  advance_ref: string;
  category: string;
  period_month: string;
  aging_bucket: string;
  recovery_status: string;
  advance_outstanding_rupees: number;
  overdue_rupees: number;
  po_linked_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    priorityRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3616_recovery_status_rollup'),
    supabase.rpc('founder_r3616_category_scorecard'),
    supabase.rpc('founder_r3616_aging_recovery_matrix'),
    supabase.rpc('founder_r3616_monthly_advance_trend'),
    supabase.rpc('founder_r3616_capa_status_board'),
    supabase.rpc('founder_r3616_root_cause_pareto'),
    supabase.rpc('founder_r3616_overdue_impact_digest'),
    supabase.rpc('founder_r3616_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const priorityRows: PriorityRow[] = (priorityRes.data as PriorityRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'recovery_status', header: 'Recovery Status' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_paid_rupees', header: 'Paid (INR)' },
    { key: 'total_adjusted_rupees', header: 'Adjusted (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
    { key: 'stuck_or_writeoff', header: 'Stuck / Write-off' },
    { key: 'avg_po_linked_pct', header: 'Avg PO-Linked %' },
    { key: 'current_pct', header: 'On-Track %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'aging_bucket', header: 'Aging Bucket' },
    { key: 'recovery_status', header: 'Recovery Status' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_paid_rupees', header: 'Paid (INR)' },
    { key: 'total_adjusted_rupees', header: 'Adjusted (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const priorityCols: Column<PriorityRow>[] = [
    { key: 'recovery_priority', header: 'Recovery Priority' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'advance_ref', header: 'Advance Ref' },
    { key: 'category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'aging_bucket', header: 'Aging' },
    { key: 'recovery_status', header: 'Status' },
    { key: 'advance_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'overdue_rupees', header: 'Overdue (INR)' },
    { key: 'po_linked_pct', header: 'PO-Linked %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Vendor Advance-Recoverable Aging Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated vendor / supplier advance-recoverable aging &amp; settlement-recovery board &mdash;
        vendor &times; category (AMC services, spare parts, projects, diagnostics, rentals, installation)
        &times; period &times; advance paid / adjusted / outstanding &times; PO-linkage &times; aging bucket
        &times; recovery status &times; trend &times; overdue exposure &amp; CAPA recovery actions. Rollups
        cover recovery-status distribution, category scorecards, aging &times; status matrix, monthly trend,
        CAPA closure, root-cause pareto, overdue-impact digest, and the high-risk (stuck &amp; write-off-risk)
        recovery queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Recovery status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No vendor advances logged yet."
          rowKey={(r, i) => String(r.recovery_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Aging bucket &times; recovery status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No advances by aging bucket."
          rowKey={(r, i) => `${r.aging_bucket}-${r.recovery_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly advance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overdue-impact digest</h2>
        <DataTable
          rows={priorityRows}
          columns={priorityCols}
          emptyMessage="No overdue-impact rollups."
          rowKey={(r, i) => String(r.recovery_priority ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recovery queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk advances."
          rowKey={(r, i) => `${r.advance_ref}-${i}`}
        />
      </section>
    </main>
  );
}
