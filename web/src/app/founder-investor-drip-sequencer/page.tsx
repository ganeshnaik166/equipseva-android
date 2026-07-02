import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Sequence = {
  id: string;
  sequence_label: string;
  sequence_md: string;
  audience_segment: string;
  status: string;
  captured_at: string;
};

type SendLog = {
  id: string;
  sequence_id: string;
  send_to_investor_id: string | null;
  sent_at: string;
  by_email: string | null;
  response_received: boolean;
  response_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [allRes, activeRes, sendsRes] = await Promise.all([
    sb.rpc('list_sequences_r2062'),
    sb.rpc('active_sequences_r2062'),
    sb.rpc('recent_sends_r2062'),
  ]);

  const allSequences: Sequence[] = (allRes.data ?? []) as Sequence[];
  const activeSequences: Sequence[] = (activeRes.data ?? []) as Sequence[];
  const recentSends: SendLog[] = (sendsRes.data ?? []) as SendLog[];

  const sequenceCols: Column<Sequence>[] = [
    { key: 'sequence_label', header: 'Label', render: (r: any) => String(r.sequence_label ?? '') },
    { key: 'audience_segment', header: 'Segment', render: (r: any) => String(r.audience_segment ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'sequence_md', header: 'Preview', render: (r: any) => String(r.sequence_md ?? '').slice(0, 80) },
  ];

  const sendCols: Column<SendLog>[] = [
    { key: 'sequence_id', header: 'Sequence', render: (r: any) => String(r.sequence_id ?? '').slice(0, 8) },
    { key: 'send_to_investor_id', header: 'Investor', render: (r: any) => r.send_to_investor_id ? String(r.send_to_investor_id).slice(0, 8) : 'n/a' },
    { key: 'by_email', header: 'By Email', render: (r: any) => String(r.by_email ?? '') },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '' },
    { key: 'response_received', header: 'Response', render: (r: any) => r.response_received ? 'yes' : 'no' },
    { key: 'response_md', header: 'Notes', render: (r: any) => String(r.response_md ?? '').slice(0, 60) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder Investor Drip Sequencer</h1>
        <p className="text-sm text-gray-600">Sequence investor outreach drips. Track sends, responses, and lifecycle status across warm, cold, follow-up, cold-outbound, and champion segments.</p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Active Sequences</h2>
        <p className="text-sm text-gray-500">Currently running drip campaigns.</p>
        <DataTable
          rows={activeSequences}
          columns={sequenceCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All Sequences</h2>
        <p className="text-sm text-gray-500">Full history including paused, completed, and abandoned.</p>
        <DataTable
          rows={allSequences}
          columns={sequenceCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent Sends</h2>
        <p className="text-sm text-gray-500">Latest drip touches with response capture.</p>
        <DataTable
          rows={recentSends}
          columns={sendCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
