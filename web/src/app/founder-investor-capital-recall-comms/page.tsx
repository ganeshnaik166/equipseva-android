import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CommRow = {
  id: string;
  investor_id: string | null;
  investor_email: string | null;
  comm_type: string;
  message_md: string | null;
  sent_at: string | null;
  status: string;
  created_at: string | null;
};

type RecentRow = {
  id: string;
  investor_id: string | null;
  investor_email: string | null;
  comm_type: string;
  status: string;
  sent_at: string | null;
};

type RateRow = {
  comm_type: string;
  sent_count: number;
  responded_count: number;
  acknowledged_count: number;
  disputed_count: number;
  closed_count: number;
  response_rate_pct: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [commsRes, recentRes, rateRes] = await Promise.all([
    sb.rpc('list_recall_comms_r1885'),
    sb.rpc('recent_recall_comms_r1885', { p_days: 30 }),
    sb.rpc('recall_comm_response_rate_r1885'),
  ]);

  const comms: CommRow[] = (commsRes.data as CommRow[]) || [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) || [];
  const rates: RateRow[] = (rateRes.data as RateRow[]) || [];

  const commsColumns: Column<CommRow>[] = [
    { key: 'created_at', header: 'Created', render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleString() : '—') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email || '—' },
    { key: 'comm_type', header: 'Type', render: (r: any) => r.comm_type },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'sent_at', header: 'Sent', render: (r: any) => (r.sent_at ? new Date(r.sent_at).toLocaleString() : '—') },
    { key: 'message_md', header: 'Message', render: (r: any) => (r.message_md ? String(r.message_md).slice(0, 80) : '—') },
  ];

  const recentColumns: Column<RecentRow>[] = [
    { key: 'sent_at', header: 'Sent', render: (r: any) => (r.sent_at ? new Date(r.sent_at).toLocaleString() : '—') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email || '—' },
    { key: 'comm_type', header: 'Type', render: (r: any) => r.comm_type },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const rateColumns: Column<RateRow>[] = [
    { key: 'comm_type', header: 'Type', render: (r: any) => r.comm_type },
    { key: 'sent_count', header: 'Sent', render: (r: any) => r.sent_count },
    { key: 'responded_count', header: 'Responded', render: (r: any) => r.responded_count },
    { key: 'acknowledged_count', header: 'Acknowledged', render: (r: any) => r.acknowledged_count },
    { key: 'disputed_count', header: 'Disputed', render: (r: any) => r.disputed_count },
    { key: 'closed_count', header: 'Closed', render: (r: any) => r.closed_count },
    { key: 'response_rate_pct', header: 'Rate %', render: (r: any) => (r.response_rate_pct == null ? '—' : `${r.response_rate_pct}%`) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Capital Recall Communications</h1>
        <p className="text-sm text-gray-600 mt-1">
          Pre-emptive comms about capital recalls & fund actions. Tracks notices sent, investor acknowledgments & disputes.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Comms (latest 200)</h2>
        <DataTable rows={comms} columns={commsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent (last 30 days)</h2>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Response Rate by Type</h2>
        <DataTable rows={rates} columns={rateColumns} rowKey={(r: any, i: number) => String(r.comm_type ?? i)} />
      </section>
    </div>
  );
}
