import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Receipt = {
  id: string;
  investor_name: string;
  investor_email: string | null;
  commitment_rupees: number;
  wire_amount_rupees: number;
  bank_reference: string | null;
  wired_at: string;
  reconciled: boolean;
  reconciliation_variance_rupees: number;
  acknowledged: boolean;
  thank_you_sent_at: string | null;
  notes: string | null;
};

type Summary = {
  total_wires: number;
  total_received_rupees: number;
  total_commitment_rupees: number;
  reconciled_count: number;
  unreconciled_count: number;
  acknowledged_count: number;
  pending_ack_count: number;
  thank_you_sent_count: number;
  variance_rupees: number;
};

type ByInvestor = {
  investor_name: string;
  wire_count: number;
  total_wired_rupees: number;
  total_commitment_rupees: number;
  outstanding_rupees: number;
  last_wired_at: string | null;
  pending_ack_count: number;
};

type AckEvent = {
  id: string;
  receipt_id: string;
  investor_name: string;
  event_kind: string;
  message: string | null;
  created_at: string;
};

function fmtINR(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  const d = new Date(s);
  return d.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function InvestorWireConfirmationPage() {
  const sb = await getSupabaseServerClient();

  const receiptsRes = await sb.rpc('founder_wire_receipts_list', { p_limit: 100 });
  const summaryRes = await sb.rpc('founder_wire_receipts_summary');
  const investorsRes = await sb.rpc('founder_wire_receipts_by_investor');
  const eventsRes = await sb.rpc('founder_wire_ack_events_recent', { p_limit: 50 });

  const receipts: Receipt[] = (receiptsRes.data ?? []) as Receipt[];
  const summary: Summary | null = Array.isArray(summaryRes.data)
    ? (summaryRes.data[0] ?? null)
    : (summaryRes.data ?? null);
  const byInvestor: ByInvestor[] = (investorsRes.data ?? []) as ByInvestor[];
  const events: AckEvent[] = (eventsRes.data ?? []) as AckEvent[];

  const error =
    receiptsRes.error?.message ??
    summaryRes.error?.message ??
    investorsRes.error?.message ??
    eventsRes.error?.message ??
    null;

  const receiptCols: Column<Receipt>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'wire_amount_rupees', header: 'Wired', render: (r) => fmtINR(r.wire_amount_rupees) },
    { key: 'commitment_rupees', header: 'Commitment', render: (r) => fmtINR(r.commitment_rupees) },
    {
      key: 'reconciliation_variance_rupees',
      header: 'Variance',
      render: (r) => (r.reconciled ? fmtINR(r.reconciliation_variance_rupees) : '—'),
    },
    { key: 'bank_reference', header: 'Bank Ref', render: (r) => r.bank_reference ?? '—' },
    { key: 'wired_at', header: 'Wired At', render: (r) => fmtDate(r.wired_at) },
    {
      key: 'reconciled',
      header: 'Reconciled',
      render: (r) => (r.reconciled ? 'Yes' : 'No'),
    },
    {
      key: 'acknowledged',
      header: 'Acked',
      render: (r) => (r.acknowledged ? 'Yes' : 'Pending'),
    },
    {
      key: 'thank_you_sent_at',
      header: 'Thank-you',
      render: (r) => fmtDate(r.thank_you_sent_at),
    },
  ];

  const investorCols: Column<ByInvestor>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'wire_count', header: 'Wires', render: (r) => String(r.wire_count ?? 0) },
    { key: 'total_wired_rupees', header: 'Total Wired', render: (r) => fmtINR(r.total_wired_rupees) },
    {
      key: 'total_commitment_rupees',
      header: 'Commitment',
      render: (r) => fmtINR(r.total_commitment_rupees),
    },
    {
      key: 'outstanding_rupees',
      header: 'Outstanding',
      render: (r) => fmtINR(r.outstanding_rupees),
    },
    { key: 'last_wired_at', header: 'Last Wire', render: (r) => fmtDate(r.last_wired_at) },
    {
      key: 'pending_ack_count',
      header: 'Pending Ack',
      render: (r) => String(r.pending_ack_count ?? 0),
    },
  ];

  const eventCols: Column<AckEvent>[] = [
    { key: 'created_at', header: 'When', render: (r) => fmtDate(r.created_at) },
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name ?? '—' },
    { key: 'event_kind', header: 'Event', render: (r) => r.event_kind ?? '—' },
    { key: 'message', header: 'Note', render: (r) => r.message ?? '—' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>
          Investor Wire Confirmation Log
        </h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Log incoming investor wires, reconcile vs commitment, founder ack & thank-you per wire.
        </p>
      </header>

      {error ? (
        <div
          style={{
            padding: 12,
            background: '#fee2e2',
            color: '#991b1b',
            borderRadius: 8,
            marginBottom: 16,
          }}
        >
          {error}
        </div>
      ) : null}

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Capital Snapshot</h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 12,
            marginTop: 12,
          }}
        >
          <Stat label="Total Wires" value={String(summary?.total_wires ?? 0)} />
          <Stat label="Received" value={fmtINR(summary?.total_received_rupees ?? 0)} />
          <Stat label="Committed" value={fmtINR(summary?.total_commitment_rupees ?? 0)} />
          <Stat
            label="Variance"
            value={fmtINR(summary?.variance_rupees ?? 0)}
            tone={(summary?.variance_rupees ?? 0) < 0 ? 'warn' : 'ok'}
          />
          <Stat
            label="Reconciled"
            value={String(summary?.reconciled_count ?? 0) + ' / ' + String(summary?.total_wires ?? 0)}
          />
          <Stat
            label="Pending Ack"
            value={String(summary?.pending_ack_count ?? 0)}
            tone={(summary?.pending_ack_count ?? 0) > 0 ? 'warn' : 'ok'}
          />
          <Stat label="Thank-yous Sent" value={String(summary?.thank_you_sent_count ?? 0)} />
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Per-Investor Rollup</h2>
        <DataTable
          rows={byInvestor}
          columns={investorCols}
          rowKey={(r: any, i: number) => String(r.investor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Wire Receipts</h2>
        <DataTable
          rows={receipts}
          columns={receiptCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Recent Ack & Thank-you Events</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Stat({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone?: 'ok' | 'warn';
}) {
  const bg = tone === 'warn' ? '#fef3c7' : '#f1f5f9';
  const fg = tone === 'warn' ? '#92400e' : '#0f172a';
  return (
    <div style={{ background: bg, color: fg, padding: 14, borderRadius: 10 }}>
      <div style={{ fontSize: 12, opacity: 0.7, textTransform: 'uppercase', letterSpacing: 0.5 }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
