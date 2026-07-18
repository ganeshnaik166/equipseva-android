import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { collection_verdict: string; invoices: number; pct: number };
type CustomerRow = {
  customer_name: string;
  total_invoices: number;
  total_outstanding: number;
  overdue_90_plus: number;
  disputed: number;
  avg_days_overdue: number;
  collected: number;
  recovery_pct: number;
};
type MatrixRow = {
  aging_bucket: string;
  customer_segment: string;
  invoices: number;
  outstanding_rupees: number;
  avg_days_overdue: number;
};
type TrendRow = {
  invoice_date: string;
  invoices: number;
  invoiced_rupees: number;
  collected_rupees: number;
  disputed: number;
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
type QueueRow = {
  customer_name: string;
  invoice_number: string;
  invoice_amount_rupees: number;
  due_date: string;
  days_overdue: number;
  aging_bucket: string;
  collection_status: string;
  collection_verdict: string;
  dispute_flag: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    customerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3169_collection_verdict_rollup'),
    supabase.rpc('founder_r3169_customer_scorecard'),
    supabase.rpc('founder_r3169_bucket_segment_matrix'),
    supabase.rpc('founder_r3169_invoice_date_trend'),
    supabase.rpc('founder_r3169_capa_status_board'),
    supabase.rpc('founder_r3169_root_cause_pareto'),
    supabase.rpc('founder_r3169_regulatory_impact_digest'),
    supabase.rpc('founder_r3169_priority_collection_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const customerRows: CustomerRow[] = (customerRes.data as CustomerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'collection_verdict', header: 'Verdict', render: (r) => String(r.collection_verdict ?? '') },
    { key: 'invoices', header: 'Invoices', render: (r) => String(r.invoices ?? '') },
    { key: 'pct', header: 'Share %', render: (r) => String(r.pct ?? '') },
  ];

  const customerCols: Column<CustomerRow>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => String(r.customer_name ?? '') },
    { key: 'total_invoices', header: 'Invoices', render: (r) => String(r.total_invoices ?? '') },
    { key: 'total_outstanding', header: 'Outstanding (INR)', render: (r) => String(r.total_outstanding ?? '') },
    { key: 'overdue_90_plus', header: '90+ Overdue', render: (r) => String(r.overdue_90_plus ?? '') },
    { key: 'disputed', header: 'Disputed', render: (r) => String(r.disputed ?? '') },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue', render: (r) => String(r.avg_days_overdue ?? '') },
    { key: 'collected', header: 'Collected (INR)', render: (r) => String(r.collected ?? '') },
    { key: 'recovery_pct', header: 'Recovery %', render: (r) => String(r.recovery_pct ?? '') },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'aging_bucket', header: 'Aging Bucket', render: (r) => String(r.aging_bucket ?? '') },
    { key: 'customer_segment', header: 'Segment', render: (r) => String(r.customer_segment ?? '') },
    { key: 'invoices', header: 'Invoices', render: (r) => String(r.invoices ?? '') },
    { key: 'outstanding_rupees', header: 'Outstanding (INR)', render: (r) => String(r.outstanding_rupees ?? '') },
    { key: 'avg_days_overdue', header: 'Avg Days Overdue', render: (r) => String(r.avg_days_overdue ?? '') },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'invoice_date', header: 'Invoice Date', render: (r) => String(r.invoice_date ?? '') },
    { key: 'invoices', header: 'Invoices', render: (r) => String(r.invoices ?? '') },
    { key: 'invoiced_rupees', header: 'Invoiced (INR)', render: (r) => String(r.invoiced_rupees ?? '') },
    { key: 'collected_rupees', header: 'Collected (INR)', render: (r) => String(r.collected_rupees ?? '') },
    { key: 'disputed', header: 'Disputed', render: (r) => String(r.disputed ?? '') },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status', render: (r) => String(r.capa_status ?? '') },
    { key: 'findings', header: 'Findings', render: (r) => String(r.findings ?? '') },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)', render: (r) => String(r.avg_cost_rupees ?? '') },
    { key: 'overdue_flag', header: 'Overdue / Escalated', render: (r) => String(r.overdue_flag ?? '') },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause', render: (r) => String(r.root_cause ?? '') },
    { key: 'occurrences', header: 'Occurrences', render: (r) => String(r.occurrences ?? '') },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)', render: (r) => String(r.total_cost_rupees ?? '') },
    { key: 'pct', header: 'Share %', render: (r) => String(r.pct ?? '') },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact', render: (r) => String(r.regulatory_impact ?? '') },
    { key: 'findings', header: 'Findings', render: (r) => String(r.findings ?? '') },
    { key: 'open_findings', header: 'Open', render: (r) => String(r.open_findings ?? '') },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)', render: (r) => String(r.total_cost_rupees ?? '') },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'customer_name', header: 'Customer', render: (r) => String(r.customer_name ?? '') },
    { key: 'invoice_number', header: 'Invoice', render: (r) => String(r.invoice_number ?? '') },
    { key: 'invoice_amount_rupees', header: 'Amount (INR)', render: (r) => String(r.invoice_amount_rupees ?? '') },
    { key: 'due_date', header: 'Due Date', render: (r) => String(r.due_date ?? '') },
    { key: 'days_overdue', header: 'Days Overdue', render: (r) => String(r.days_overdue ?? '') },
    { key: 'aging_bucket', header: 'Bucket', render: (r) => String(r.aging_bucket ?? '') },
    { key: 'collection_status', header: 'Status', render: (r) => String(r.collection_status ?? '') },
    { key: 'collection_verdict', header: 'Verdict', render: (r) => String(r.collection_verdict ?? '') },
    { key: 'dispute_flag', header: 'Disputed', render: (r) => (r.dispute_flag ? 'yes' : 'no') },
    { key: 'notes', header: 'Notes', render: (r) => String(r.notes ?? '') },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Cash-Collection &amp; Accounts-Receivable Aging Discipline Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Outstanding-invoice AR aging log — customer &times; invoice &times; aging bucket
        (0&ndash;30 / 31&ndash;60 / 61&ndash;90 / 90+) &times; collection status &times; dispute flag &times; DSO
        &amp; CAPA closure. Founder-gated view: collection verdicts, customer scorecards,
        root-cause pareto, and a prioritised collection queue for receivables at risk.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Collection verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No invoices logged yet."
          rowKey={(r, i) => String(r.collection_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer collection scorecard</h2>
        <DataTable
          rows={customerRows}
          columns={customerCols}
          emptyMessage="No customer rollups."
          rowKey={(r, i) => String(r.customer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Aging bucket &times; segment matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No aging by segment."
          rowKey={(r, i) => `${r.aging_bucket}-${r.customer_segment}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Invoice date trend (billed vs collected)</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.invoice_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Priority collection queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk receivables."
          rowKey={(r, i) => `${r.invoice_number}-${i}`}
        />
      </section>
    </main>
  );
}
