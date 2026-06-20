import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
  if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
  return `Rs ${v.toLocaleString('en-IN')}`;
}

export default async function FounderInvestorSignalInterpreterPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = {};
  let recent: any[] = [];
  let actions: any[] = [];
  let concerns: any[] = [];
  let leaderboard: any[] = [];

  try {
    const r = await sb.rpc('founder_isi_overview');
    overview = (r.data && r.data[0]) ?? {};
  } catch { overview = {}; }
  try {
    const r = await sb.rpc('founder_isi_recent_messages', { p_limit: 50 });
    recent = r.data ?? [];
  } catch { recent = []; }
  try {
    const r = await sb.rpc('founder_isi_open_actions');
    actions = r.data ?? [];
  } catch { actions = []; }
  try {
    const r = await sb.rpc('founder_isi_top_concerns');
    concerns = r.data ?? [];
  } catch { concerns = []; }
  try {
    const r = await sb.rpc('founder_isi_investor_leaderboard');
    leaderboard = r.data ?? [];
  } catch { leaderboard = []; }

  const kpis: Kpi[] = [
    { label: 'Total messages', value: fmtInt(overview.total_messages) },
    { label: 'Last 24h', value: fmtInt(overview.msgs_24h) },
    { label: 'Last 7d', value: fmtInt(overview.msgs_7d) },
    { label: 'Strong positive', value: fmtInt(overview.strong_positive) },
    { label: 'Positive', value: fmtInt(overview.positive) },
    { label: 'Neutral', value: fmtInt(overview.neutral) },
    { label: 'Concerned', value: fmtInt(overview.concerned) },
    { label: 'Negative', value: fmtInt(overview.negative) },
    { label: 'Leads', value: fmtInt(overview.leads) },
    { label: 'Soft commits', value: fmtInt(overview.soft_commits) },
    { label: 'Term sheets', value: fmtInt(overview.term_sheets) },
    { label: 'Passes', value: fmtInt(overview.passes) },
    { label: 'Exploring', value: fmtInt(overview.exploring_count) },
    { label: 'Indicated pipeline', value: fmtRupees(overview.total_pipeline_rupees) },
    { label: 'Open actions', value: fmtInt(overview.open_actions) },
    { label: 'Overdue actions', value: fmtInt(overview.overdue_actions) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'received_at', header: 'When', render: (r: any) => new Date(r.received_at).toLocaleString('en-IN') },
    { key: 'investor_handle', header: 'Investor', render: (r: any) => r.investor_name ?? r.investor_handle ?? '-' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '-' },
    { key: 'subject', header: 'Subject', render: (r: any) => r.subject ?? '-' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => `${r.sentiment ?? '-'} (${Number(r.sentiment_score ?? 0).toFixed(2)})` },
    { key: 'commit_signal', header: 'Commit signal', render: (r: any) => r.commit_signal ?? '-' },
    { key: 'commit_amount_rupees', header: 'Indicated', render: (r: any) => fmtRupees(r.commit_amount_rupees) },
    { key: 'next_step', header: 'Next step', render: (r: any) => r.next_step ?? '-' },
    { key: 'age_hours', header: 'Age (hrs)', render: (r: any) => Number(r.age_hours ?? 0).toFixed(1) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority ?? '-' },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind ?? '-' },
    { key: 'investor_handle', header: 'Investor', render: (r: any) => r.investor_handle ?? '-' },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleString('en-IN') : '-' },
    { key: 'overdue', header: 'Overdue', render: (r: any) => r.overdue ? 'YES' : 'no' },
    { key: 'hours_to_due', header: 'Hrs to due', render: (r: any) => r.hours_to_due === null || r.hours_to_due === undefined ? '-' : Number(r.hours_to_due).toFixed(1) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '-' },
  ];

  const concernCols: Column<any>[] = [
    { key: 'concern_tag', header: 'Concern tag', render: (r: any) => r.concern_tag ?? '-' },
    { key: 'mentions', header: 'Mentions', render: (r: any) => fmtInt(r.mentions) },
    { key: 'unique_investors', header: 'Unique investors', render: (r: any) => fmtInt(r.unique_investors) },
    { key: 'last_seen', header: 'Last seen', render: (r: any) => r.last_seen ? new Date(r.last_seen).toLocaleString('en-IN') : '-' },
  ];

  const leaderCols: Column<any>[] = [
    { key: 'investor_handle', header: 'Investor', render: (r: any) => r.investor_name ?? r.investor_handle ?? '-' },
    { key: 'message_count', header: 'Msgs', render: (r: any) => fmtInt(r.message_count) },
    { key: 'latest_sentiment', header: 'Latest sentiment', render: (r: any) => r.latest_sentiment ?? '-' },
    { key: 'latest_commit_signal', header: 'Latest signal', render: (r: any) => r.latest_commit_signal ?? '-' },
    { key: 'total_indicated_rupees', header: 'Indicated', render: (r: any) => fmtRupees(r.total_indicated_rupees) },
    { key: 'last_contact', header: 'Last contact', render: (r: any) => r.last_contact ? new Date(r.last_contact).toLocaleString('en-IN') : '-' },
    { key: 'days_since_contact', header: 'Days idle', render: (r: any) => Number(r.days_since_contact ?? 0).toFixed(1) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Signal Interpreter</h1>
        <p className="text-sm text-gray-600">Parse investor email and Slack replies, classify sentiment + commit signals + concerns, and drive the founder action queue.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border p-3 bg-white">
            <div className="text-xs uppercase text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open founder action queue</h2>
        <DataTable<any> columns={actionCols} rows={actions} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent investor messages</h2>
        <DataTable<any> columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top concerns</h2>
        <DataTable<any> columns={concernCols} rows={concerns} rowKey={(r: any) => r.concern_tag} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Investor leaderboard</h2>
        <DataTable<any> columns={leaderCols} rows={leaderboard} rowKey={(r: any) => r.investor_handle} />
      </section>
    </div>
  );
}
