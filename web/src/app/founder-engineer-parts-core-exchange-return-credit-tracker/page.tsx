import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { core_status: string; cores: number; pct: number };
type SupplierRow = {
  supplier_name: string;
  total_cores: number;
  credited: number;
  rejected: number;
  scrapped: number;
  pending: number;
  core_value_rupees: number;
  credit_received_rupees: number;
  recovery_pct: number;
};
type MatrixRow = {
  core_type: string;
  core_status: string;
  cores: number;
  core_value_rupees: number;
  credit_received_rupees: number;
};
type TrendRow = {
  return_month: string;
  cores: number;
  credited: number;
  rejected: number;
  scrapped: number;
  credit_received_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_credit_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_credit_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  core_status: string;
  cores: number;
  total_core_value_rupees: number;
  total_credit_received_rupees: number;
  credit_gap_rupees: number;
  recovery_pct: number;
};
type RiskRow = {
  engineer_name: string;
  core_ref: string;
  part_name: string;
  part_serial: string;
  supplier_name: string;
  core_type: string;
  core_status: string;
  core_value_rupees: number | null;
  days_outstanding: number | null;
  return_deadline: string | null;
  within_deadline: boolean | null;
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
    supabase.rpc('founder_r3564_core_status_rollup'),
    supabase.rpc('founder_r3564_supplier_scorecard'),
    supabase.rpc('founder_r3564_core_type_status_matrix'),
    supabase.rpc('founder_r3564_monthly_return_trend'),
    supabase.rpc('founder_r3564_capa_status_board'),
    supabase.rpc('founder_r3564_root_cause_pareto'),
    supabase.rpc('founder_r3564_credit_recovery_digest'),
    supabase.rpc('founder_r3564_high_risk_queue'),
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
    { key: 'core_status', header: 'Core Status' },
    { key: 'cores', header: 'Cores' },
    { key: 'pct', header: 'Share %' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'total_cores', header: 'Cores' },
    { key: 'credited', header: 'Credited' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'scrapped', header: 'Scrapped' },
    { key: 'pending', header: 'In Flight' },
    { key: 'core_value_rupees', header: 'Core Value (INR)' },
    { key: 'credit_received_rupees', header: 'Credit Received (INR)' },
    { key: 'recovery_pct', header: 'Recovery %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'core_type', header: 'Core Type' },
    { key: 'core_status', header: 'Core Status' },
    { key: 'cores', header: 'Cores' },
    { key: 'core_value_rupees', header: 'Core Value (INR)' },
    { key: 'credit_received_rupees', header: 'Credit Received (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'return_month', header: 'Return Month' },
    { key: 'cores', header: 'Cores' },
    { key: 'credited', header: 'Credited' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'scrapped', header: 'Scrapped' },
    { key: 'credit_received_rupees', header: 'Credit Received (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_credit_impact_rupees', header: 'Avg Credit Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_credit_impact_rupees', header: 'Total Credit Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'core_status', header: 'Core Status' },
    { key: 'cores', header: 'Cores' },
    { key: 'total_core_value_rupees', header: 'Core Value (INR)' },
    { key: 'total_credit_received_rupees', header: 'Credit Received (INR)' },
    { key: 'credit_gap_rupees', header: 'Credit Gap (INR)' },
    { key: 'recovery_pct', header: 'Recovery %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'core_ref', header: 'Core Ref' },
    { key: 'part_name', header: 'Part' },
    { key: 'part_serial', header: 'Serial' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'core_type', header: 'Type' },
    { key: 'core_status', header: 'Status' },
    { key: 'core_value_rupees', header: 'Core Value (INR)' },
    { key: 'days_outstanding', header: 'Days Out' },
    { key: 'return_deadline', header: 'Deadline' },
    { key: 'within_deadline', header: 'Within Deadline' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Parts Core-Exchange / Return-for-Credit Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Repairable-part core-exchange log &mdash; engineer &times; part &amp; serial &times; supplier
        &times; core type (probe, board, battery, detector, tube, module, handpiece) &times; core status
        (pending return &rarr; shipped &rarr; received at OEM &rarr; credited / rejected / scrapped)
        &times; core value &times; credit received &times; days outstanding &times; return deadline &amp;
        within-deadline flag &amp; CAPA closure. Founder-gated view: status distribution, supplier
        scorecards, root-cause pareto, and credit-recovery impact across the OEM return pipeline.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Core status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No core-exchange records yet."
          rowKey={(r, i) => String(r.core_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Core type &times; core status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cores by type."
          rowKey={(r, i) => `${r.core_type}-${r.core_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly return trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.return_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Credit-recovery impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No credit-recovery rollups."
          rowKey={(r, i) => String(r.core_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk core queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cores."
          rowKey={(r, i) => `${r.core_ref}-${i}`}
        />
      </section>
    </main>
  );
}
