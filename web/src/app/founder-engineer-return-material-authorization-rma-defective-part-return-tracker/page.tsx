import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { return_status: string; rmas: number; pct: number };
type SupplierRow = {
  supplier_name: string;
  total_rmas: number;
  credited: number;
  rejected: number;
  replaced: number;
  no_fault_found: number;
  total_credit_rupees: number;
  avg_turnaround_days: number;
  credit_recovery_pct: number;
};
type MatrixRow = {
  defect_category: string;
  warranty_status: string;
  rmas: number;
  credited: number;
  rejected: number;
  avg_credit_rupees: number;
  avg_turnaround_days: number;
};
type TrendRow = {
  month: string;
  rmas: number;
  credited: number;
  rejected: number;
  replaced: number;
  avg_turnaround_days: number;
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
type DigestRow = {
  warranty_status: string;
  rmas: number;
  credited_count: number;
  total_credit_rupees: number;
  avg_credit_rupees: number;
  pending_credit: number;
};
type RiskRow = {
  engineer_name: string;
  rma_number: string;
  part_name: string;
  supplier_name: string;
  defect_category: string;
  warranty_status: string;
  return_status: string;
  raised_date: string;
  credit_amount_rupees: number | null;
  escalated: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    supplierRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3428_return_status_rollup'),
    supabase.rpc('founder_r3428_supplier_scorecard'),
    supabase.rpc('founder_r3428_defect_warranty_matrix'),
    supabase.rpc('founder_r3428_monthly_rma_trend'),
    supabase.rpc('founder_r3428_capa_status_board'),
    supabase.rpc('founder_r3428_root_cause_pareto'),
    supabase.rpc('founder_r3428_credit_recovery_digest'),
    supabase.rpc('founder_r3428_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const supplierRows: SupplierRow[] = (supplierRes.data as SupplierRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'return_status', header: 'Return Status' },
    { key: 'rmas', header: 'RMAs' },
    { key: 'pct', header: 'Share %' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'total_rmas', header: 'RMAs' },
    { key: 'credited', header: 'Credited' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'replaced', header: 'Replaced' },
    { key: 'no_fault_found', header: 'No-Fault-Found' },
    { key: 'total_credit_rupees', header: 'Credit Recovered (INR)' },
    { key: 'avg_turnaround_days', header: 'Avg TAT Days' },
    { key: 'credit_recovery_pct', header: 'Credit Rec %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'defect_category', header: 'Defect Category' },
    { key: 'warranty_status', header: 'Warranty' },
    { key: 'rmas', header: 'RMAs' },
    { key: 'credited', header: 'Credited' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'avg_credit_rupees', header: 'Avg Credit (INR)' },
    { key: 'avg_turnaround_days', header: 'Avg TAT Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'rmas', header: 'RMAs' },
    { key: 'credited', header: 'Credited' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'replaced', header: 'Replaced' },
    { key: 'avg_turnaround_days', header: 'Avg TAT Days' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'warranty_status', header: 'Warranty Status' },
    { key: 'rmas', header: 'RMAs' },
    { key: 'credited_count', header: 'Credited' },
    { key: 'total_credit_rupees', header: 'Total Credit (INR)' },
    { key: 'avg_credit_rupees', header: 'Avg Credit (INR)' },
    { key: 'pending_credit', header: 'Pending Credit' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'rma_number', header: 'RMA' },
    { key: 'part_name', header: 'Part' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'defect_category', header: 'Defect' },
    { key: 'warranty_status', header: 'Warranty' },
    { key: 'return_status', header: 'Status' },
    { key: 'raised_date', header: 'Raised' },
    { key: 'credit_amount_rupees', header: 'Credit (INR)' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Return-Material-Authorization (RMA) / Defective-Part Return Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer RMA / defective-part return-to-supplier workflow — defect category
        (DOA, infant-mortality, wear-out, no-fault-found, physical damage, counterfeit-suspected)
        &times; warranty status &times; return status (initiated &rarr; picked-up &rarr; in-transit
        &rarr; received &rarr; credited / replaced / rejected) &times; turnaround days &times; credit
        recovery &amp; CAPA closure. Founder-gated view: return-status mix, supplier scorecards,
        root-cause pareto, and credit-recovery digest across CDSCO &amp; supplier-SLA surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Return-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No RMAs logged yet."
          rowKey={(r, i) => String(r.return_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supplier scorecard</h2>
        <DataTable
          rows={supplierRows}
          columns={supplierCols}
          emptyMessage="No supplier rollups."
          rowKey={(r, i) => String(r.supplier_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Defect category &times; warranty matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No RMAs by defect category."
          rowKey={(r, i) => `${r.defect_category}-${r.warranty_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly RMA trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Credit-recovery digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No credit-recovery rollups."
          rowKey={(r, i) => String(r.warranty_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk RMA queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk RMAs."
          rowKey={(r, i) => `${r.rma_number}-${i}`}
        />
      </section>
    </main>
  );
}
