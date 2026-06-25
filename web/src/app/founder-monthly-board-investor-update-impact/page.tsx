import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyBoardInvestorUpdateImpactPage() {
  const supabase = await getSupabaseServerClient();

  const [
    updatesRes,
    actionsRes,
    topFocusRes,
    actionDistRes,
    statusFunnelRes,
    monthlyTrendRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_updates_r2669'),
    supabase.rpc('list_followup_actions_r2669'),
    supabase.rpc('top_response_focus_r2669'),
    supabase.rpc('action_kind_distribution_r2669'),
    supabase.rpc('status_funnel_r2669'),
    supabase.rpc('monthly_update_trend_r2669'),
    supabase.rpc('founder_pulse_summary_r2669'),
  ]);

  const updates = (updatesRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topFocus = (topFocusRes.data ?? []) as any[];
  const actionDist = (actionDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const pulse = (pulseRes.data ?? [])[0] ?? null;

  const updateCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'sent_at', header: 'Sent At', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '-' },
    { key: 'recipients_count', header: 'Recipients', render: (r: any) => r.recipients_count },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => `${r.open_rate_pct}%` },
    { key: 'reply_count', header: 'Replies', render: (r: any) => r.reply_count },
    { key: 'ask_resolved_count', header: 'Asks Resolved', render: (r: any) => r.ask_resolved_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'top_takeaway_md', header: 'Takeaway', render: (r: any) => r.top_takeaway_md ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'month_label', header: 'Update Month', render: (r: any) => r.month_label },
    { key: 'action_at', header: 'Action At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '-' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topFocusCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'reply_count', header: 'Replies', render: (r: any) => r.reply_count },
    { key: 'ask_resolved_count', header: 'Asks Resolved', render: (r: any) => r.ask_resolved_count },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => `${r.open_rate_pct}%` },
  ];

  const actionDistCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
  ];

  const statusFunnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'update_count', header: 'Count', render: (r: any) => r.update_count },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'sent_at', header: 'Sent At', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '-' },
    { key: 'recipients_count', header: 'Recipients', render: (r: any) => r.recipients_count },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => `${r.open_rate_pct}%` },
    { key: 'reply_count', header: 'Replies', render: (r: any) => r.reply_count },
    { key: 'reply_rate_pct', header: 'Reply %', render: (r: any) => `${r.reply_rate_pct}%` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Monthly Board & Investor Update Impact</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track engagement, replies, and follow-up actions from monthly investor updates.
        </p>
      </header>

      {pulse && (
        <section>
          <h2 className="text-lg font-semibold mb-3">Pulse Summary</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Total Updates</div>
              <div className="text-xl font-semibold">{pulse.total_updates}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Total Recipients</div>
              <div className="text-xl font-semibold">{pulse.total_recipients}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Total Replies</div>
              <div className="text-xl font-semibold">{pulse.total_replies}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Asks Resolved</div>
              <div className="text-xl font-semibold">{pulse.total_asks_resolved}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Avg Open Rate</div>
              <div className="text-xl font-semibold">{pulse.avg_open_rate_pct}%</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Open Actions</div>
              <div className="text-xl font-semibold">{pulse.open_actions}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Positive Actions</div>
              <div className="text-xl font-semibold">{pulse.positive_actions}</div>
            </div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-3">Board Updates</h2>
        <DataTable
          rows={updates}
          columns={updateCols}
          emptyMessage="No updates logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Follow-up Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No follow-up actions recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Response Focus</h2>
        <DataTable
          rows={topFocus}
          columns={topFocusCols}
          emptyMessage="No sent updates yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Action Kind Distribution</h2>
        <DataTable
          rows={actionDist}
          columns={actionDistCols}
          emptyMessage="No actions yet"
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusFunnelCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Monthly Update Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
