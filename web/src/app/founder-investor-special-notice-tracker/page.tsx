import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type NoticeRow = {
  id: string;
  notice_type: string;
  investor_count: number;
  notice_amount_rupees: number;
  notice_window_days: number;
  sent_at: string;
  status: string;
  closed_at: string | null;
  response_count: number;
};

type SummaryRow = {
  notice_type: string;
  total_notices: number;
  total_responses: number;
  accepted_count: number;
  declined_count: number;
  waived_count: number;
  no_response_count: number;
};

type RecentRow = {
  id: string;
  notice_type: string;
  investor_count: number;
  notice_amount_rupees: number;
  sent_at: string;
  status: string;
  days_open: number;
};

function fmtRupees(n: number | null | undefined) {
  if (!n) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [noticesRes, summaryRes, recentRes] = await Promise.all([
    sb.rpc('list_notices_r1881'),
    sb.rpc('response_rate_summary_r1881'),
    sb.rpc('recent_notices_r1881'),
  ]);

  const notices: NoticeRow[] = (noticesRes.data as NoticeRow[]) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[]) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];

  const noticeCols: Column<NoticeRow>[] = [
    { key: 'notice_type', header: 'Type', render: (r: any) => <span className="font-mono text-xs">{r.notice_type}</span> },
    { key: 'investor_count', header: 'Investors', render: (r: any) => <span>{r.investor_count}</span> },
    { key: 'notice_amount_rupees', header: 'Amount', render: (r: any) => <span>{fmtRupees(r.notice_amount_rupees)}</span> },
    { key: 'notice_window_days', header: 'Window (d)', render: (r: any) => <span>{r.notice_window_days}</span> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => <span>{fmtDate(r.sent_at)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="font-mono text-xs">{r.status}</span> },
    { key: 'response_count', header: 'Responses', render: (r: any) => <span>{r.response_count}</span> },
    { key: 'closed_at', header: 'Closed', render: (r: any) => <span>{fmtDate(r.closed_at)}</span> },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'notice_type', header: 'Type', render: (r: any) => <span className="font-mono text-xs">{r.notice_type}</span> },
    { key: 'total_notices', header: 'Total Notices', render: (r: any) => <span>{r.total_notices}</span> },
    { key: 'total_responses', header: 'Total Responses', render: (r: any) => <span>{r.total_responses}</span> },
    { key: 'accepted_count', header: 'Accepted', render: (r: any) => <span className="text-emerald-700">{r.accepted_count}</span> },
    { key: 'declined_count', header: 'Declined', render: (r: any) => <span className="text-rose-700">{r.declined_count}</span> },
    { key: 'waived_count', header: 'Waived', render: (r: any) => <span className="text-slate-600">{r.waived_count}</span> },
    { key: 'no_response_count', header: 'No Resp', render: (r: any) => <span className="text-amber-700">{r.no_response_count}</span> },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'notice_type', header: 'Type', render: (r: any) => <span className="font-mono text-xs">{r.notice_type}</span> },
    { key: 'investor_count', header: 'Investors', render: (r: any) => <span>{r.investor_count}</span> },
    { key: 'notice_amount_rupees', header: 'Amount', render: (r: any) => <span>{fmtRupees(r.notice_amount_rupees)}</span> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => <span>{fmtDate(r.sent_at)}</span> },
    { key: 'days_open', header: 'Days Open', render: (r: any) => <span>{r.days_open}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="font-mono text-xs">{r.status}</span> },
  ];

  const totalNotices = notices.length;
  const openNotices = notices.filter((n) => n.status === 'sent' || n.status === 'responses_pending').length;
  const closedNotices = notices.filter((n) => n.status === 'closed').length;
  const disputedNotices = notices.filter((n) => n.status === 'disputed').length;

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-widest text-slate-500">Round 1881 · Founder Console</p>
        <h1 className="text-3xl font-semibold text-slate-900">Investor Special Notice Tracker</h1>
        <p className="text-sm text-slate-600 max-w-3xl">
          Track special notices sent to investors — ROFR, drag-along, tag-along, recall, buyout offers. Monitor
          response rates & deadlines.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Total Notices</div>
          <div className="mt-1 text-2xl font-semibold text-slate-900">{totalNotices}</div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Open</div>
          <div className="mt-1 text-2xl font-semibold text-amber-700">{openNotices}</div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Closed</div>
          <div className="mt-1 text-2xl font-semibold text-emerald-700">{closedNotices}</div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-slate-500">Disputed</div>
          <div className="mt-1 text-2xl font-semibold text-rose-700">{disputedNotices}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">All Notices</h2>
        <p className="text-sm text-slate-600">Every special notice issued to investors, newest first (limit 200).</p>
        <DataTable rows={notices} columns={noticeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Response Rate by Notice Type</h2>
        <p className="text-sm text-slate-600">Aggregate response distribution per notice category.</p>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.notice_type ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Recent Notices (Last 30 Days)</h2>
        <p className="text-sm text-slate-600">Notices sent in the last 30 days with days-open counter.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
