import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Wire = {
  id: string;
  investor_email: string | null;
  commitment_amount_rupees: number | null;
  wire_received_amount_rupees: number | null;
  wire_received_at: string | null;
  bank_reference: string | null;
  mismatch_flag: boolean | null;
  status: string | null;
  created_at: string | null;
};

type Thanks = {
  id: string;
  wire_id: string;
  investor_email: string | null;
  thank_you_method: string | null;
  sent_at: string | null;
  by_email: string | null;
  response: string | null;
  created_at: string | null;
};

type Pending = {
  wire_id: string;
  investor_email: string | null;
  wire_received_amount_rupees: number | null;
  wire_received_at: string | null;
  days_since_received: number | null;
};

type Summary = {
  total_wires: number | null;
  total_received_rupees: number | null;
  total_committed_rupees: number | null;
  mismatches: number | null;
  reconciled: number | null;
  pending_thanks: number | null;
};

function rupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + (n as number).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [wiresRes, thanksRes, pendingRes, summaryRes] = await Promise.all([
    sb.rpc('list_wires_r1757'),
    sb.rpc('list_thanks_r1757'),
    sb.rpc('pending_thanks_queue_r1757'),
    sb.rpc('recent_wires_summary_r1757'),
  ]);

  const wires: Wire[] = (wiresRes.data as Wire[]) ?? [];
  const thanks: Thanks[] = (thanksRes.data as Thanks[]) ?? [];
  const pending: Pending[] = (pendingRes.data as Pending[]) ?? [];
  const summaryArr = (summaryRes.data as Summary[]) ?? [];
  const summary: Summary = summaryArr[0] ?? {
    total_wires: 0,
    total_received_rupees: 0,
    total_committed_rupees: 0,
    mismatches: 0,
    reconciled: 0,
    pending_thanks: 0,
  };

  const wireCols: Column<Wire>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'commitment', header: 'Committed', render: (r: any) => rupees(r.commitment_amount_rupees) },
    { key: 'received', header: 'Received', render: (r: any) => rupees(r.wire_received_amount_rupees) },
    { key: 'wire_received_at', header: 'Received At', render: (r: any) => fmtDate(r.wire_received_at) },
    { key: 'bank_reference', header: 'Bank Ref', render: (r: any) => r.bank_reference ?? '-' },
    { key: 'mismatch_flag', header: 'Mismatch', render: (r: any) => (r.mismatch_flag ? 'YES' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const thanksCols: Column<Thanks>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'thank_you_method', header: 'Method', render: (r: any) => r.thank_you_method ?? '-' },
    { key: 'sent_at', header: 'Sent At', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'response', header: 'Response', render: (r: any) => r.response ?? '-' },
  ];

  const pendingCols: Column<Pending>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '-' },
    { key: 'amount', header: 'Wire Amount', render: (r: any) => rupees(r.wire_received_amount_rupees) },
    { key: 'wire_received_at', header: 'Received At', render: (r: any) => fmtDate(r.wire_received_at) },
    { key: 'days_since_received', header: 'Days Waiting', render: (r: any) => String(r.days_since_received ?? '-') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Investor Wire Confirmation Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round 1757 — track wire transfers from investors against committed amounts and queue thank-you follow-ups.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary (last 90 days)</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total wires</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_wires ?? 0}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Received</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(summary.total_received_rupees)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Committed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(summary.total_committed_rupees)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Mismatches</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.mismatches ?? 0}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Reconciled</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.reconciled ?? 0}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Pending thanks</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.pending_thanks ?? 0}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent wires</h2>
        <DataTable
          rows={wires}
          columns={wireCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pending thank-you queue</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Confirmed wires with no thank-you sent yet — oldest first.
        </p>
        <DataTable
          rows={pending}
          columns={pendingCols}
          rowKey={(r: any, i: number) => String(r.wire_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Thank-you log</h2>
        <DataTable
          rows={thanks}
          columns={thanksCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
