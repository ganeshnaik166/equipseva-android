import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_investors: number | null;
  total_committed_rupees: number | null;
  total_allocated_rupees: number | null;
  signed_count: number | null;
  pending_count: number | null;
  waitlist_count: number | null;
  capacity_remaining_rupees: number | null;
};

type AllocationRow = {
  id: string;
  investor_name: string | null;
  investor_email: string | null;
  round_label: string | null;
  committed_amount_rupees: number | null;
  allocated_amount_rupees: number | null;
  pre_money_valuation_rupees: number | null;
  ownership_pct: number | null;
  decision: string | null;
  signed_at: string | null;
  created_at: string | null;
};

type CapacityRow = {
  round_label: string | null;
  committed_rupees: number | null;
  allocated_rupees: number | null;
  signed_rupees: number | null;
  investor_count: number | null;
};

type LetterRow = {
  id: string;
  allocation_id: string;
  investor_name: string | null;
  allocated_amount_rupees: number | null;
  status: string | null;
  queued_at: string | null;
  sent_at: string | null;
  countersigned_at: string | null;
  template_version: string | null;
};

function fmtRupees(v: number | null | undefined): string {
  if (v == null) return '—';
  return '₹' + Number(v).toLocaleString('en-IN');
}

function fmtDate(v: string | null | undefined): string {
  if (!v) return '—';
  return new Date(v).toLocaleDateString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  let summary: SummaryRow | null = null;
  let allocations: AllocationRow[] = [];
  let capacity: CapacityRow[] = [];
  let letters: LetterRow[] = [];

  try {
    const r = await sb.rpc('founder_investor_allocation_final_summary');
    const rows = (r.data as SummaryRow[] | null) ?? [];
    summary = rows[0] ?? null;
  } catch {
    summary = null;
  }

  try {
    const r = await sb.rpc('founder_investor_allocation_final_list');
    allocations = (r.data as AllocationRow[] | null) ?? [];
  } catch {
    allocations = [];
  }

  try {
    const r = await sb.rpc('founder_investor_allocation_capacity');
    capacity = (r.data as CapacityRow[] | null) ?? [];
  } catch {
    capacity = [];
  }

  try {
    const r = await sb.rpc('founder_commitment_letter_queue_list');
    letters = (r.data as LetterRow[] | null) ?? [];
  } catch {
    letters = [];
  }

  const allocCols: Column<AllocationRow>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'round_label', header: 'Round', render: (r) => r.round_label ?? '—' },
    { key: 'committed_amount_rupees', header: 'Committed', render: (r) => fmtRupees(r.committed_amount_rupees) },
    { key: 'allocated_amount_rupees', header: 'Allocated', render: (r) => fmtRupees(r.allocated_amount_rupees) },
    { key: 'ownership_pct', header: 'Ownership %', render: (r) => (r.ownership_pct == null ? '—' : String(r.ownership_pct) + '%') },
    { key: 'decision', header: 'Decision', render: (r) => r.decision ?? '—' },
    { key: 'signed_at', header: 'Signed', render: (r) => fmtDate(r.signed_at) },
  ];

  const capCols: Column<CapacityRow>[] = [
    { key: 'round_label', header: 'Round', render: (r) => r.round_label ?? '—' },
    { key: 'investor_count', header: 'Investors', render: (r) => String(r.investor_count ?? 0) },
    { key: 'committed_rupees', header: 'Committed', render: (r) => fmtRupees(r.committed_rupees) },
    { key: 'allocated_rupees', header: 'Allocated', render: (r) => fmtRupees(r.allocated_rupees) },
    { key: 'signed_rupees', header: 'Signed', render: (r) => fmtRupees(r.signed_rupees) },
  ];

  const letterCols: Column<LetterRow>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'allocated_amount_rupees', header: 'Amount', render: (r) => fmtRupees(r.allocated_amount_rupees) },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'queued_at', header: 'Queued', render: (r) => fmtDate(r.queued_at) },
    { key: 'sent_at', header: 'Sent', render: (r) => fmtDate(r.sent_at) },
    { key: 'countersigned_at', header: 'Countersigned', render: (r) => fmtDate(r.countersigned_at) },
    { key: 'template_version', header: 'Template', render: (r) => r.template_version ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor Allocation — Final</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Final per-investor allocation decisions, signed allocations + capacity, and commitment letter queue.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Stat label="Investors" value={String(summary?.total_investors ?? 0)} />
        <Stat label="Total Committed" value={fmtRupees(summary?.total_committed_rupees ?? 0)} />
        <Stat label="Total Allocated" value={fmtRupees(summary?.total_allocated_rupees ?? 0)} />
        <Stat label="Signed" value={String(summary?.signed_count ?? 0)} />
        <Stat label="Pending" value={String(summary?.pending_count ?? 0)} />
        <Stat label="Waitlist" value={String(summary?.waitlist_count ?? 0)} />
        <Stat label="Capacity Remaining" value={fmtRupees(summary?.capacity_remaining_rupees ?? 0)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Capacity by Round</h2>
        <DataTable rows={capacity} columns={capCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Final Allocations</h2>
        <DataTable rows={allocations} columns={allocCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Commitment Letter Queue</h2>
        <DataTable rows={letters} columns={letterCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600 }}>{value}</div>
    </div>
  );
}
