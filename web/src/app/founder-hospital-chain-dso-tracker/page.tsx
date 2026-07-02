import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_outstanding_rupees: number;
  total_invoices: number;
  weighted_dso_days: number;
  overdue_90_plus_rupees: number;
  chains_with_dues: number;
  collection_rate_pct: number;
};

type AgingBucket = {
  bucket: string;
  invoice_count: number;
  total_amount_rupees: number;
  pct_of_total: number;
};

type DraggingChain = {
  chain_id: string;
  chain_name: string;
  hospital_count: number;
  open_invoices: number;
  total_outstanding_rupees: number;
  oldest_invoice_age_days: number;
  chain_dso_days: number;
};

type PriorityRow = {
  receivable_id: string;
  chain_name: string;
  invoice_number: string;
  outstanding_rupees: number;
  aging_days: number;
  aging_bucket: string;
  priority_score: number;
};

type ActionRow = {
  action_id: string;
  chain_name: string;
  invoice_number: string;
  action_type: string;
  action_notes: string;
  amount_promised_rupees: number;
  action_taken_at: string;
};

type DisputeRow = {
  status: string;
  invoice_count: number;
  amount_rupees: number;
};

function fmtINR(rupees: number): string {
  if (!rupees) return '₹0';
  if (rupees >= 10000000) return `₹${(rupees / 10000000).toFixed(2)} Cr`;
  if (rupees >= 100000) return `₹${(rupees / 100000).toFixed(2)} L`;
  return `₹${rupees.toLocaleString('en-IN')}`;
}

function bucketLabel(b: string): string {
  switch (b) {
    case 'current': return 'Current (not yet due)';
    case '1_30': return '1-30 days';
    case '31_60': return '31-60 days';
    case '61_90': return '61-90 days';
    case '90_plus': return '90+ days';
    default: return b;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [{ data: ovRaw }, { data: agingRaw }, { data: chainsRaw }, { data: priorityRaw }, { data: actionsRaw }, { data: disputesRaw }] = await Promise.all([
    sb.rpc('r2263_dso_overview'),
    sb.rpc('r2263_aging_buckets'),
    sb.rpc('r2263_top_dragging_chains'),
    sb.rpc('r2263_collection_priority'),
    sb.rpc('r2263_recent_actions'),
    sb.rpc('r2263_dispute_summary'),
  ]);

  const ov: Overview = (ovRaw?.[0] ?? {
    total_outstanding_rupees: 0,
    total_invoices: 0,
    weighted_dso_days: 0,
    overdue_90_plus_rupees: 0,
    chains_with_dues: 0,
    collection_rate_pct: 0,
  }) as Overview;
  const aging: AgingBucket[] = (agingRaw ?? []) as AgingBucket[];
  const chains: DraggingChain[] = (chainsRaw ?? []) as DraggingChain[];
  const priority: PriorityRow[] = (priorityRaw ?? []) as PriorityRow[];
  const actions: ActionRow[] = (actionsRaw ?? []) as ActionRow[];
  const disputes: DisputeRow[] = (disputesRaw ?? []) as DisputeRow[];

  const agingCols: Column<AgingBucket>[] = [
    { key: 'bucket', header: 'Aging bucket', render: (r) => bucketLabel(r.bucket) },
    { key: 'invoice_count', header: 'Invoices', render: (r) => r.invoice_count },
    { key: 'total_amount_rupees', header: 'Outstanding', render: (r) => fmtINR(r.total_amount_rupees) },
    { key: 'pct_of_total', header: '% of total', render: (r) => `${r.pct_of_total}%` },
  ];

  const chainCols: Column<DraggingChain>[] = [
    { key: 'chain_name', header: 'Hospital chain', render: (r) => r.chain_name },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'open_invoices', header: 'Open invoices', render: (r) => r.open_invoices },
    { key: 'total_outstanding_rupees', header: 'Outstanding', render: (r) => fmtINR(r.total_outstanding_rupees) },
    { key: 'oldest_invoice_age_days', header: 'Oldest (days)', render: (r) => r.oldest_invoice_age_days },
    { key: 'chain_dso_days', header: 'Chain DSO', render: (r) => `${r.chain_dso_days}d` },
  ];

  const priorityCols: Column<PriorityRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'invoice_number', header: 'Invoice #', render: (r) => r.invoice_number },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r) => fmtINR(r.outstanding_rupees) },
    { key: 'aging_days', header: 'Age (days)', render: (r) => r.aging_days },
    { key: 'aging_bucket', header: 'Bucket', render: (r) => bucketLabel(r.aging_bucket) },
    { key: 'priority_score', header: 'Priority score', render: (r) => r.priority_score.toLocaleString('en-IN') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_taken_at', header: 'When', render: (r) => new Date(r.action_taken_at).toLocaleString('en-IN') },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'invoice_number', header: 'Invoice', render: (r) => r.invoice_number },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type.replace(/_/g, ' ') },
    { key: 'amount_promised_rupees', header: 'Promised', render: (r) => r.amount_promised_rupees ? fmtINR(r.amount_promised_rupees) : '—' },
    { key: 'action_notes', header: 'Notes', render: (r) => r.action_notes },
  ];

  const disputeCols: Column<DisputeRow>[] = [
    { key: 'status', header: 'Status', render: (r) => r.status.replace(/_/g, ' ') },
    { key: 'invoice_count', header: 'Invoices', render: (r) => r.invoice_count },
    { key: 'amount_rupees', header: 'Amount', render: (r) => fmtINR(r.amount_rupees) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Hospital Chain DSO Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Receivables aging by hospital chain, top dragging accounts, and collection priority queue.
        Target DSO &lt; 45 days; chains overdue &gt;= 90 days flagged for escalation.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 14, marginBottom: 28 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Total outstanding</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtINR(ov.total_outstanding_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Open invoices</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{ov.total_invoices}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Weighted DSO</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{ov.weighted_dso_days}d</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fecaca', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#991b1b', marginBottom: 4 }}>Overdue (&gt;= 90 days)</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#991b1b' }}>{fmtINR(ov.overdue_90_plus_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Chains with dues</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{ov.chains_with_dues}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>Collection rate</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{ov.collection_rate_pct}%</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Aging bucket breakdown</h2>
        <DataTable columns={agingCols} rows={aging} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Top dragging chains (by outstanding)</h2>
        <DataTable columns={chainCols} rows={chains} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Collection priority queue</h2>
        <p style={{ color: '#6b7280', fontSize: 13, marginBottom: 10 }}>
          Score = outstanding amount × aging days. Higher = more urgent to chase.
        </p>
        <DataTable columns={priorityCols} rows={priority} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent collection actions</h2>
        <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Disputes & resolved</h2>
        <DataTable columns={disputeCols} rows={disputes} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
