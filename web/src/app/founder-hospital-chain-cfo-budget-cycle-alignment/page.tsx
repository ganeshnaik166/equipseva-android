import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cyclesRes, pipelineRes, upcomingRes, winRateRes, kindRes, priorityRes, trendRes] = await Promise.all([
    sb.rpc('list_budget_cycles_r2535'),
    sb.rpc('list_pitch_pipeline_r2535'),
    sb.rpc('upcoming_optimal_windows_r2535'),
    sb.rpc('win_rate_summary_r2535'),
    sb.rpc('budget_cycle_kind_breakdown_r2535'),
    sb.rpc('top_priority_pitches_r2535'),
    sb.rpc('monthly_pitch_trend_r2535'),
  ]);

  const cycles = (cyclesRes.data ?? []) as any[];
  const pipeline = (pipelineRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const winRate = (winRateRes.data ?? []) as any[];
  const kind = (kindRes.data ?? []) as any[];
  const priority = (priorityRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const fmtDate = (v: string | null) => (v ? new Date(v).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) : '-');
  const fmtMonth = (v: string | null) => (v ? new Date(v).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' }) : '-');

  const cyclesCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'cfo_name', header: 'CFO', render: (r: any) => r.cfo_name },
    { key: 'cfo_email', header: 'Email', render: (r: any) => r.cfo_email },
    { key: 'budget_cycle_kind', header: 'Cycle', render: (r: any) => r.budget_cycle_kind },
    { key: 'cycle_start_month', header: 'Start Mo', render: (r: any) => String(r.cycle_start_month) },
    { key: 'planning_window_weeks', header: 'Plan Wks', render: (r: any) => String(r.planning_window_weeks) },
    { key: 'our_pitch_timing_optimal_at', header: 'Optimal Pitch', render: (r: any) => fmtDate(r.our_pitch_timing_optimal_at) },
    { key: 'last_pitch_at', header: 'Last Pitch', render: (r: any) => fmtDate(r.last_pitch_at) },
    { key: 'last_pitch_outcome', header: 'Outcome', render: (r: any) => r.last_pitch_outcome ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'cfo_name', header: 'CFO', render: (r: any) => r.cfo_name },
    { key: 'scheduled_pitch_at', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_pitch_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'cfo_name', header: 'CFO', render: (r: any) => r.cfo_name },
    { key: 'our_pitch_timing_optimal_at', header: 'Optimal At', render: (r: any) => fmtDate(r.our_pitch_timing_optimal_at) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until) },
    { key: 'budget_cycle_kind', header: 'Cycle', render: (r: any) => r.budget_cycle_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const winRateCols: Column<any>[] = [
    { key: 'total_cycles', header: 'Total', render: (r: any) => String(r.total_cycles) },
    { key: 'won_count', header: 'Won', render: (r: any) => String(r.won_count) },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count) },
    { key: 'postponed_count', header: 'Postponed', render: (r: any) => String(r.postponed_count) },
    { key: 'in_review_count', header: 'In Review', render: (r: any) => String(r.in_review_count) },
    { key: 'win_rate_pct', header: 'Win Rate %', render: (r: any) => `${r.win_rate_pct}%` },
  ];

  const kindCols: Column<any>[] = [
    { key: 'budget_cycle_kind', header: 'Cycle Kind', render: (r: any) => r.budget_cycle_kind },
    { key: 'chain_count', header: 'Chains', render: (r: any) => String(r.chain_count) },
    { key: 'avg_planning_weeks', header: 'Avg Plan Wks', render: (r: any) => String(r.avg_planning_weeks) },
  ];

  const priorityCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'cfo_name', header: 'CFO', render: (r: any) => r.cfo_name },
    { key: 'our_pitch_timing_optimal_at', header: 'Optimal At', render: (r: any) => fmtDate(r.our_pitch_timing_optimal_at) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until) },
    { key: 'last_pitch_outcome', header: 'Last Outcome', render: (r: any) => r.last_pitch_outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'scheduled_count', header: 'Scheduled', render: (r: any) => String(r.scheduled_count) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Chain CFO Budget Cycle Alignment
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track each chain's CFO budget calendar & pitch in the optimal window => higher win rate.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Win Rate Summary</h2>
        <DataTable
          rows={winRate}
          columns={winRateCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Priority Pitches</h2>
        <DataTable
          rows={priority}
          columns={priorityCols}
          emptyMessage="No priority pitches"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming Optimal Windows (next 90 days)</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming windows"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Budget Cycle Kind Breakdown</h2>
        <DataTable
          rows={kind}
          columns={kindCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.budget_cycle_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Pitch Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Budget Cycles</h2>
        <DataTable
          rows={cycles}
          columns={cyclesCols}
          emptyMessage="No cycles"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pitch Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          emptyMessage="No pitches"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
