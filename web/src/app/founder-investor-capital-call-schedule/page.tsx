import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CallRow = {
  id: string;
  investor_id: string;
  call_date: string;
  call_amount_rupees: number;
  call_purpose_md: string | null;
  status: string;
  sent_at: string | null;
  paid_at: string | null;
  created_at: string;
};

type LateRow = {
  id: string;
  investor_id: string;
  call_date: string;
  call_amount_rupees: number;
  status: string;
  days_overdue: number;
};

type LogRow = {
  id: string;
  call_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  note_md: string | null;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '—';
  return '₹' + (n / 100000).toFixed(2) + ' L';
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  return new Date(s).toLocaleDateString('en-IN');
}

function fmtDateTime(s: string | null | undefined) {
  if (!s) return '—';
  return new Date(s).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [callsRes, lateRes, logsRes] = await Promise.all([
    sb.rpc('list_capital_calls_r1909'),
    sb.rpc('list_late_capital_calls_r1909'),
    sb.rpc('list_recent_capital_call_logs_r1909'),
  ]);

  const calls: CallRow[] = (callsRes.data as CallRow[] | null) ?? [];
  const lates: LateRow[] = (lateRes.data as LateRow[] | null) ?? [];
  const logs: LogRow[] = (logsRes.data as LogRow[] | null) ?? [];

  const totalScheduled = calls
    .filter((c) => c.status === 'scheduled' || c.status === 'sent')
    .reduce((s, c) => s + (c.call_amount_rupees || 0), 0);
  const totalPaid = calls
    .filter((c) => c.status === 'paid')
    .reduce((s, c) => s + (c.call_amount_rupees || 0), 0);
  const lateCount = lates.length;

  const callCols: Column<CallRow>[] = [
    { key: 'call_date', header: 'Call Date', render: (r: any) => fmtDate(r.call_date) },
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id).slice(0, 8)}</span> },
    { key: 'call_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.call_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs font-semibold uppercase">{r.status}</span> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDateTime(r.sent_at) },
    { key: 'paid_at', header: 'Paid', render: (r: any) => fmtDateTime(r.paid_at) },
    { key: 'call_purpose_md', header: 'Purpose', render: (r: any) => <span className="text-xs text-gray-600">{r.call_purpose_md ?? '—'}</span> },
  ];

  const lateCols: Column<LateRow>[] = [
    { key: 'call_date', header: 'Due Date', render: (r: any) => fmtDate(r.call_date) },
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id).slice(0, 8)}</span> },
    { key: 'call_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.call_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs font-semibold uppercase text-red-700">{r.status}</span> },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => <span className="font-semibold text-red-700">{r.days_overdue}</span> },
  ];

  const logCols: Column<LogRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => fmtDateTime(r.taken_at) },
    { key: 'call_id', header: 'Call', render: (r: any) => <span className="font-mono text-xs">{String(r.call_id).slice(0, 8)}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span className="text-xs font-semibold uppercase">{r.action_type}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email ?? '—'}</span> },
    { key: 'note_md', header: 'Note', render: (r: any) => <span className="text-xs text-gray-600">{r.note_md ?? '—'}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Capital Call Schedule</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track scheduled capital calls per investor. Calls past due date with status &lt;&gt; paid are flagged late.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Outstanding (scheduled &amp; sent)</div>
          <div className="text-2xl font-bold mt-1">{fmtRupees(totalScheduled)}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Paid to date</div>
          <div className="text-2xl font-bold mt-1 text-green-700">{fmtRupees(totalPaid)}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Late calls (date &lt; today)</div>
          <div className="text-2xl font-bold mt-1 text-red-700">{lateCount}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All capital calls</h2>
        <p className="text-xs text-gray-500 mb-2">Showing up to 200 rows, most recent call date first.</p>
        <DataTable rows={calls} columns={callCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Late calls (call_date &lt; today &amp; not paid)</h2>
        <DataTable rows={lates} columns={lateCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent action log</h2>
        <p className="text-xs text-gray-500 mb-2">Latest 100 actions across all calls.</p>
        <DataTable rows={logs} columns={logCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
