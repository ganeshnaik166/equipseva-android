import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyKeyHirePipelineQualityPage() {
  const supabase = await getSupabaseServerClient();

  const [pipelineRes, actionsRes, topProbRes, velocityRes, barRateRes, trendRes, actionBreakRes] = await Promise.all([
    supabase.rpc('list_pipeline_r2601'),
    supabase.rpc('list_pipeline_actions_r2601'),
    supabase.rpc('top_close_prob_roles_r2601'),
    supabase.rpc('velocity_distribution_r2601'),
    supabase.rpc('bar_pass_rate_summary_r2601'),
    supabase.rpc('monthly_pipeline_trend_r2601'),
    supabase.rpc('action_kind_breakdown_r2601'),
  ]);

  const pipeline = pipelineRes.data ?? [];
  const actions = actionsRes.data ?? [];
  const topProb = topProbRes.data ?? [];
  const velocity = velocityRes.data ?? [];
  const barRate = barRateRes.data ?? [];
  const trend = trendRes.data ?? [];
  const actionBreak = actionBreakRes.data ?? [];

  const pipelineCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'role_name', header: 'Role', render: (r: any) => r.role_name },
    { key: 'candidates_count', header: 'Candidates', render: (r: any) => r.candidates_count },
    { key: 'bar_passed_count', header: 'Bar Passed', render: (r: any) => r.bar_passed_count },
    { key: 'diversity_count', header: 'Diversity', render: (r: any) => r.diversity_count },
    { key: 'velocity_days', header: 'Velocity (days)', render: (r: any) => r.velocity_days },
    { key: 'close_probability_pct', header: 'Close Prob %', render: (r: any) => r.close_probability_pct },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topProbCols: Column<any>[] = [
    { key: 'role_name', header: 'Role', render: (r: any) => r.role_name },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'close_probability_pct', header: 'Close Prob %', render: (r: any) => r.close_probability_pct },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const velocityCols: Column<any>[] = [
    { key: 'bucket', header: 'Velocity Bucket', render: (r: any) => r.bucket },
    { key: 'role_count', header: 'Roles', render: (r: any) => r.role_count },
    { key: 'avg_close_prob', header: 'Avg Close Prob %', render: (r: any) => r.avg_close_prob },
  ];

  const barRateCols: Column<any>[] = [
    { key: 'role_name', header: 'Role', render: (r: any) => r.role_name },
    { key: 'candidates_count', header: 'Candidates', render: (r: any) => r.candidates_count },
    { key: 'bar_passed_count', header: 'Bar Passed', render: (r: any) => r.bar_passed_count },
    { key: 'bar_pass_rate_pct', header: 'Bar Pass Rate %', render: (r: any) => r.bar_pass_rate_pct },
    { key: 'diversity_count', header: 'Diversity', render: (r: any) => r.diversity_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'roles_open', header: 'Roles Open', render: (r: any) => r.roles_open },
    { key: 'total_candidates', header: 'Candidates', render: (r: any) => r.total_candidates },
    { key: 'total_bar_passed', header: 'Bar Passed', render: (r: any) => r.total_bar_passed },
    { key: 'avg_close_prob', header: 'Avg Close Prob %', render: (r: any) => r.avg_close_prob },
  ];

  const actionBreakCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'action_count', header: 'Count', render: (r: any) => r.action_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Founder > Monthly Key-Hire Pipeline Quality
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Role & month > candidates > bar passed > diversity > velocity > close probability.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Key-Hire Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          emptyMessage="No pipeline rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Close-Probability Roles</h2>
        <DataTable
          rows={topProb}
          columns={topProbCols}
          emptyMessage="No close-prob data."
          rowKey={(r: any, i: number) => String(r.role_name ?? i) + '-' + i}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Velocity Distribution</h2>
        <DataTable
          rows={velocity}
          columns={velocityCols}
          emptyMessage="No velocity data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Bar Pass Rate Summary</h2>
        <DataTable
          rows={barRate}
          columns={barRateCols}
          emptyMessage="No bar-rate data."
          rowKey={(r: any, i: number) => String(r.role_name ?? i) + '-' + i}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Pipeline Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Kind Breakdown</h2>
        <DataTable
          rows={actionBreak}
          columns={actionBreakCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pipeline Actions Log</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No actions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
