import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyInvestorUpdatePipelinePage() {
  const supabase = await getSupabaseServerClient();

  const [
    updatesRes,
    repliesRes,
    funnelRes,
    topInvestorsRes,
    followUpsRes,
    trendRes,
    askPipelineRes,
  ] = await Promise.all([
    supabase.rpc('list_updates_r2441'),
    supabase.rpc('list_replies_r2441'),
    supabase.rpc('status_funnel_r2441'),
    supabase.rpc('top_reply_investors_r2441'),
    supabase.rpc('follow_up_calendar_r2441'),
    supabase.rpc('monthly_open_rate_trend_r2441'),
    supabase.rpc('ask_pipeline_summary_r2441'),
  ]);

  const updates = (updatesRes.data ?? []) as any[];
  const replies = (repliesRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const topInvestors = (topInvestorsRes.data ?? []) as any[];
  const followUps = (followUpsRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const askPipeline = (askPipelineRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');
  const fmtDateTime = (v: any) => (v ? new Date(v).toLocaleString() : '—');

  const updatesColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'recipient_count', header: 'Recipients', render: (r: any) => r.recipient_count },
    { key: 'opened_count', header: 'Opens', render: (r: any) => r.opened_count },
    { key: 'replied_count', header: 'Replies', render: (r: any) => r.replied_count },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => `${r.open_rate_pct}%` },
    { key: 'reply_rate_pct', header: 'Reply %', render: (r: any) => `${r.reply_rate_pct}%` },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const repliesColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'replied_at', header: 'Replied', render: (r: any) => fmtDateTime(r.replied_at) },
    { key: 'reply_kind', header: 'Kind', render: (r: any) => r.reply_kind },
    { key: 'reply_summary', header: 'Summary', render: (r: any) => r.reply_summary ?? '—' },
    { key: 'follow_up_required', header: 'F/U?', render: (r: any) => (r.follow_up_required ? 'yes' : 'no') },
    { key: 'follow_up_at', header: 'F/U at', render: (r: any) => fmtDateTime(r.follow_up_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'update_count', header: 'Updates', render: (r: any) => r.update_count },
    { key: 'total_recipients', header: 'Recipients', render: (r: any) => r.total_recipients },
    { key: 'total_opens', header: 'Opens', render: (r: any) => r.total_opens },
    { key: 'total_replies', header: 'Replies', render: (r: any) => r.total_replies },
  ];

  const topInvestorsColumns: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'reply_count', header: 'Replies', render: (r: any) => r.reply_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'intro_offer_count', header: 'Intros', render: (r: any) => r.intro_offer_count },
    { key: 'ask_count', header: 'Asks', render: (r: any) => r.ask_count },
    { key: 'last_replied_at', header: 'Last reply', render: (r: any) => fmtDateTime(r.last_replied_at) },
  ];

  const followUpsColumns: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'follow_up_at', header: 'When', render: (r: any) => fmtDateTime(r.follow_up_at) },
    { key: 'days_out', header: 'Days out', render: (r: any) => r.days_out },
    { key: 'reply_kind', header: 'Kind', render: (r: any) => r.reply_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'reply_summary', header: 'Summary', render: (r: any) => r.reply_summary ?? '—' },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'recipient_count', header: 'Recipients', render: (r: any) => r.recipient_count },
    { key: 'opened_count', header: 'Opens', render: (r: any) => r.opened_count },
    { key: 'replied_count', header: 'Replies', render: (r: any) => r.replied_count },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => `${r.open_rate_pct}%` },
    { key: 'reply_rate_pct', header: 'Reply %', render: (r: any) => `${r.reply_rate_pct}%` },
  ];

  const askPipelineColumns: Column<any>[] = [
    { key: 'reply_kind', header: 'Kind', render: (r: any) => r.reply_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'in_progress_count', header: 'In progress', render: (r: any) => r.in_progress_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'follow_up_required_count', header: 'F/U needed', render: (r: any) => r.follow_up_required_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder — Monthly Investor Update Pipeline</h1>
        <p className="text-sm text-gray-600">
          Month & status funnel: draft =&gt; sent =&gt; opened =&gt; replied =&gt; closed. KPI hits, asks & commitments tracked per month.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          emptyMessage="No updates yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly updates</h2>
        <DataTable
          rows={updates}
          columns={updatesColumns}
          emptyMessage="No monthly updates."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open & reply rate trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No sent updates yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replies</h2>
        <DataTable
          rows={replies}
          columns={repliesColumns}
          emptyMessage="No replies yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top reply investors</h2>
        <DataTable
          rows={topInvestors}
          columns={topInvestorsColumns}
          emptyMessage="No investor replies."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-up calendar</h2>
        <DataTable
          rows={followUps}
          columns={followUpsColumns}
          emptyMessage="No open follow-ups."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Ask pipeline summary</h2>
        <DataTable
          rows={askPipeline}
          columns={askPipelineColumns}
          emptyMessage="No asks tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
