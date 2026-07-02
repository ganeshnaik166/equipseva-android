import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    leadersRes,
    touchpointsRes,
    weakFocusRes,
    topInfluenceRes,
    roleBreakdownRes,
    recentCalRes,
    monthlyTrendRes,
  ] = await Promise.all([
    supabase.rpc('list_leaders_r2519'),
    supabase.rpc('list_touchpoints_r2519'),
    supabase.rpc('weak_relationship_focus_r2519'),
    supabase.rpc('top_influence_leaders_r2519'),
    supabase.rpc('role_breakdown_r2519'),
    supabase.rpc('recent_touch_calendar_r2519'),
    supabase.rpc('monthly_outcome_trend_r2519'),
  ]);

  const leaders = leadersRes.data ?? [];
  const touchpoints = touchpointsRes.data ?? [];
  const weakFocus = weakFocusRes.data ?? [];
  const topInfluence = topInfluenceRes.data ?? [];
  const roleBreakdown = roleBreakdownRes.data ?? [];
  const recentCal = recentCalRes.data ?? [];
  const monthlyTrend = monthlyTrendRes.data ?? [];

  const fmtDate = (v: any) =>
    v ? new Date(v).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
  const fmtDateTime = (v: any) =>
    v ? new Date(v).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—';

  const leaderCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'leader_name', header: 'Leader', render: (r: any) => r.leader_name },
    { key: 'leader_role', header: 'Role', render: (r: any) => r.leader_role },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'cycle_preference', header: 'Cadence', render: (r: any) => r.cycle_preference },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'leader_email', header: 'Email', render: (r: any) => r.leader_email ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const touchpointCols: Column<any>[] = [
    { key: 'touch_at', header: 'When', render: (r: any) => fmtDateTime(r.touch_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'leader_name', header: 'Leader', render: (r: any) => r.leader_name },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'agenda', header: 'Agenda', render: (r: any) => r.agenda ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const weakCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'leader_name', header: 'Leader', render: (r: any) => r.leader_name },
    { key: 'leader_role', header: 'Role', render: (r: any) => r.leader_role },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'days_since_touch', header: 'Days since touch', render: (r: any) => r.days_since_touch ?? '—' },
    { key: 'deal_blockers_md', header: 'Blockers', render: (r: any) => r.deal_blockers_md ?? '—' },
  ];

  const topInflCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'leader_name', header: 'Leader', render: (r: any) => r.leader_name },
    { key: 'leader_role', header: 'Role', render: (r: any) => r.leader_role },
    { key: 'influence_score', header: 'Influence', render: (r: any) => `${r.influence_score}/100` },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'cycle_preference', header: 'Cadence', render: (r: any) => r.cycle_preference },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const roleCols: Column<any>[] = [
    { key: 'leader_role', header: 'Role', render: (r: any) => r.leader_role },
    { key: 'leader_count', header: 'Leaders', render: (r: any) => r.leader_count },
    { key: 'avg_influence', header: 'Avg influence', render: (r: any) => r.avg_influence },
    { key: 'champion_count', header: 'Champions', render: (r: any) => r.champion_count },
    { key: 'weak_count', header: 'Weak', render: (r: any) => r.weak_count },
  ];

  const calCols: Column<any>[] = [
    { key: 'touch_at', header: 'When', render: (r: any) => fmtDateTime(r.touch_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'leader_name', header: 'Leader', render: (r: any) => r.leader_name },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'touch_count', header: 'Touches', render: (r: any) => r.touch_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => r.neutral_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold">Hospital chain procurement leadership</h1>
        <p className="text-sm text-gray-600">
          Track procurement heads, CFOs, CMOs & admin directors at chain accounts. Influence
          scores, relationship strength, deal blockers & touchpoint cadence drive next-best-action.
        </p>
      </header>

      <section className="space-y-2">
        <h2 className="text-xl font-semibold">Leaders</h2>
        <DataTable
          rows={leaders}
          columns={leaderCols}
          emptyMessage="No leaders yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-xl font-semibold">Weak / developing — focus list</h2>
        <p className="text-sm text-gray-600">
          High-influence leaders we haven't yet won over. Sorted by influence score.
        </p>
        <DataTable
          rows={weakFocus}
          columns={weakCols}
          emptyMessage="No weak relationships"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-xl font-semibold">Top influence leaders</h2>
        <DataTable
          rows={topInfluence}
          columns={topInflCols}
          emptyMessage="No leaders"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-xl font-semibold">Role breakdown</h2>
        <DataTable
          rows={roleBreakdown}
          columns={roleCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.leader_role ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-xl font-semibold">All touchpoints</h2>
        <DataTable
          rows={touchpoints}
          columns={touchpointCols}
          emptyMessage="No touchpoints yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-xl font-semibold">Recent touch calendar (last 60 days)</h2>
        <DataTable
          rows={recentCal}
          columns={calCols}
          emptyMessage="No recent touches"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-xl font-semibold">Monthly outcome trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </main>
  );
}
