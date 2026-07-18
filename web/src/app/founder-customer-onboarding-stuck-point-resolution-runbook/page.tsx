import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [stuckRes, outcomesRes, focusRes, stageRes, kindRes, trendRes, lessonsRes] = await Promise.all([
    supabase.rpc('list_stuck_points_r2544'),
    supabase.rpc('list_resolution_outcomes_r2544'),
    supabase.rpc('top_stuck_focus_r2544'),
    supabase.rpc('stage_breakdown_r2544'),
    supabase.rpc('kind_distribution_r2544'),
    supabase.rpc('monthly_resolution_trend_r2544'),
    supabase.rpc('lessons_summary_r2544'),
  ]);

  const stuck = stuckRes.data ?? [];
  const outcomes = outcomesRes.data ?? [];
  const focus = focusRes.data ?? [];
  const stage = stageRes.data ?? [];
  const kind = kindRes.data ?? [];
  const trend = trendRes.data ?? [];
  const lessons = lessonsRes.data ?? [];

  const stuckCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'stuck_at_stage', header: 'Stage', render: (r: any) => r.stuck_at_stage },
    { key: 'stuck_kind', header: 'Kind', render: (r: any) => r.stuck_kind },
    { key: 'stuck_days', header: 'Days', render: (r: any) => r.stuck_days },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'detected_at', header: 'Detected', render: (r: any) => new Date(r.detected_at).toLocaleDateString() },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => r.resolved_at ? new Date(r.resolved_at).toLocaleDateString() : '-' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'stuck_stage', header: 'Stage', render: (r: any) => r.stuck_stage ?? '-' },
    { key: 'resolution_kind', header: 'Resolution', render: (r: any) => r.resolution_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'resolution_at', header: 'When', render: (r: any) => new Date(r.resolution_at).toLocaleDateString() },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'stuck_at_stage', header: 'Stage', render: (r: any) => r.stuck_at_stage },
    { key: 'stuck_kind', header: 'Kind', render: (r: any) => r.stuck_kind },
    { key: 'stuck_days', header: 'Days', render: (r: any) => r.stuck_days },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stuck_at_stage', header: 'Stage', render: (r: any) => r.stuck_at_stage },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => r.resolved_count },
    { key: 'avg_stuck_days', header: 'Avg Days', render: (r: any) => r.avg_stuck_days },
  ];

  const kindCols: Column<any>[] = [
    { key: 'stuck_kind', header: 'Kind', render: (r: any) => r.stuck_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'avg_stuck_days', header: 'Avg Days', render: (r: any) => r.avg_stuck_days },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString() },
    { key: 'resolutions', header: 'Resolutions', render: (r: any) => r.resolutions },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  const lessonsCols: Column<any>[] = [
    { key: 'resolution_kind', header: 'Resolution', render: (r: any) => r.resolution_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'total_count', header: 'Count', render: (r: any) => r.total_count },
    { key: 'sample_lessons_md', header: 'Recent Lesson', render: (r: any) => r.sample_lessons_md ?? '-' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 600 }}>Customer Onboarding Stuck-Point Resolution Runbook</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Hospital &gt; stage &gt; kind &gt; playbook &gt; outcome. Where onboarding gets stuck & how we unblocked it.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Stuck Focus (open / in-progress)</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No active stuck points."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Stage Breakdown</h2>
        <DataTable
          rows={stage}
          columns={stageCols}
          emptyMessage="No stage data."
          rowKey={(r: any, i: number) => String(r.stuck_at_stage ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Kind Distribution</h2>
        <DataTable
          rows={kind}
          columns={kindCols}
          emptyMessage="No kind data."
          rowKey={(r: any, i: number) => String(r.stuck_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Resolution Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No resolutions logged."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Lessons Summary</h2>
        <DataTable
          rows={lessons}
          columns={lessonsCols}
          emptyMessage="No lessons captured."
          rowKey={(r: any, i: number) => String(`${r.resolution_kind}-${r.outcome}` ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Stuck Points</h2>
        <DataTable
          rows={stuck}
          columns={stuckCols}
          emptyMessage="No stuck points logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Resolution Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
