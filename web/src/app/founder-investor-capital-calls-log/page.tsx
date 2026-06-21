import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorCapitalCallsLogPage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, callsRes, lateRes] = await Promise.all([
    sb.rpc('capital_call_summary_r1697'),
    sb.rpc('list_calls_r1697'),
    sb.rpc('late_calls_r1697'),
  ]);

  const summary = (summaryRes.data?.[0] ?? null) as any;
  const calls = (callsRes.data ?? []) as any[];
  const late = (lateRes.data ?? []) as any[];

  const fmtMoney = (n: number | null | undefined) =>
    n == null ? '—' : `Rs ${Number(n).toLocaleString('en-IN')}`;

  const callColumns: Column<any>[] = [
    { key: 'call_label', header: 'Call', render: (r: any) => r.call_label ?? '—' },
    {
      key: 'investor_email',
      header: 'Investor',
      render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—',
    },
    { key: 'called_amount_rupees', header: 'Called', render: (r: any) => fmtMoney(r.called_amount_rupees) },
    { key: 'funded_amount_rupees', header: 'Funded', render: (r: any) => fmtMoney(r.funded_amount_rupees) },
    { key: 'call_date', header: 'Call Date', render: (r: any) => r.call_date ?? '—' },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ?? '—' },
    {
      key: 'days_to_due',
      header: 'Days to Due',
      render: (r: any) => {
        const d = r.days_to_due;
        if (d == null) return '—';
        if (d < 0) return `${Math.abs(d)}d overdue`;
        return `${d}d`;
      },
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const lateColumns: Column<any>[] = [
    { key: 'call_label', header: 'Call', render: (r: any) => r.call_label ?? '—' },
    {
      key: 'investor_email',
      header: 'Investor',
      render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—',
    },
    { key: 'called_amount_rupees', header: 'Called', render: (r: any) => fmtMoney(r.called_amount_rupees) },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ?? '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Capital Calls Log</h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>
        Track LP capital calls and responses. Late calls (&gt;0d overdue) need follow-up.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        {summary ? (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
              gap: 12,
            }}
          >
            <Card label="Total Calls" value={String(summary.total_calls ?? 0)} />
            <Card label="Open" value={String(summary.open_calls ?? 0)} />
            <Card label="Funded" value={String(summary.funded_calls ?? 0)} />
            <Card label="Late" value={String(summary.late_calls ?? 0)} />
            <Card label="Skipped" value={String(summary.skipped_calls ?? 0)} />
            <Card label="Total Called" value={fmtMoney(summary.total_called_rupees)} />
            <Card label="Total Funded" value={fmtMoney(summary.total_funded_rupees)} />
            <Card label="Outstanding" value={fmtMoney(summary.outstanding_rupees)} />
          </div>
        ) : (
          <p style={{ color: '#9ca3af' }}>No data.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Late Calls (overdue &gt;0d)
        </h2>
        <DataTable
          rows={late}
          columns={lateColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Capital Calls</h2>
        <DataTable
          rows={calls}
          columns={callColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: 12,
        background: '#fff',
      }}
    >
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600 }}>{value}</div>
    </div>
  );
}
