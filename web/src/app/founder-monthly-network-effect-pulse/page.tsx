import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyNetworkEffectPulsePage() {
  const supabase = await getSupabaseServerClient();

  const [
    networkRes,
    actionsRes,
    weaknessRes,
    trendRes,
    statusRes,
    actionKindRes,
    summaryRes,
  ] = await Promise.all([
    supabase.rpc('list_network_r2661'),
    supabase.rpc('list_recovery_actions_r2661'),
    supabase.rpc('top_weakness_focus_r2661'),
    supabase.rpc('monthly_network_trend_r2661'),
    supabase.rpc('status_funnel_r2661'),
    supabase.rpc('action_kind_distribution_r2661'),
    supabase.rpc('founder_pulse_summary_r2661'),
  ]);

  const network = (networkRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const weakness = (weaknessRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const statusFunnel = (statusRes.data ?? []) as any[];
  const actionKinds = (actionKindRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;

  const networkCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'network_score', header: 'Score', render: (r: any) => `${r.network_score}/100` },
    { key: 'intros_made_count', header: 'Intros Made', render: (r: any) => r.intros_made_count },
    { key: 'intros_received_count', header: 'Intros Received', render: (r: any) => r.intros_received_count },
    { key: 'peer_advice_sessions', header: 'Peer Sessions', render: (r: any) => r.peer_advice_sessions },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'top_strength_md', header: 'Strength', render: (r: any) => r.top_strength_md ?? '-' },
    { key: 'top_weakness_md', header: 'Weakness', render: (r: any) => r.top_weakness_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const weaknessCols: Column<any>[] = [
    { key: 'weakness', header: 'Weakness Focus', render: (r: any) => r.weakness },
    { key: 'pulse_count', header: 'Pulses', render: (r: any) => r.pulse_count },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'network_score', header: 'Score', render: (r: any) => r.network_score },
    { key: 'intros_made_count', header: 'Made', render: (r: any) => r.intros_made_count },
    { key: 'intros_received_count', header: 'Received', render: (r: any) => r.intros_received_count },
    { key: 'peer_advice_sessions', header: 'Peer Sessions', render: (r: any) => r.peer_advice_sessions },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'pulse_count', header: 'Pulses', render: (r: any) => r.pulse_count },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score ?? '-' },
  ];

  const actionKindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'action_count', header: 'Total', render: (r: any) => r.action_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight">Founder Monthly Network Effect Pulse</h1>
        <p className="text-sm text-gray-600">
          Month-over-month tracker of founder network growth & recovery actions when ties go stagnant.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Total Pulses</div>
          <div className="mt-1 text-2xl font-semibold">{summary.total_pulses ?? 0}</div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Avg Network Score</div>
          <div className="mt-1 text-2xl font-semibold">{summary.avg_network_score ?? 0}</div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Intros Made</div>
          <div className="mt-1 text-2xl font-semibold">{summary.total_intros_made ?? 0}</div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Intros Received</div>
          <div className="mt-1 text-2xl font-semibold">{summary.total_intros_received ?? 0}</div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Peer Sessions</div>
          <div className="mt-1 text-2xl font-semibold">{summary.total_peer_sessions ?? 0}</div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Growing Months</div>
          <div className="mt-1 text-2xl font-semibold">{summary.growing_count ?? 0}</div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Declining Months</div>
          <div className="mt-1 text-2xl font-semibold">{summary.declining_count ?? 0}</div>
        </div>
        <div className="rounded-lg border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Open Actions</div>
          <div className="mt-1 text-2xl font-semibold">{summary.open_actions ?? 0}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Monthly Pulses</h2>
        <DataTable
          rows={network}
          columns={networkCols}
          emptyMessage="No monthly pulses logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Recovery Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No recovery actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Monthly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Top Weakness Focus</h2>
          <DataTable
            rows={weakness}
            columns={weaknessCols}
            emptyMessage="No weakness data."
            rowKey={(r: any, i: number) => String(r.weakness ?? i)}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Status Funnel</h2>
          <DataTable
            rows={statusFunnel}
            columns={statusCols}
            emptyMessage="No status data."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Action Kind Distribution</h2>
        <DataTable
          rows={actionKinds}
          columns={actionKindCols}
          emptyMessage="No action kind data."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>
    </main>
  );
}
