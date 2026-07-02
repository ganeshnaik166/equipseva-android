import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderAnnualGoalsTrackerPage() {
  const sb = await getSupabaseServerClient();
  const currentYear = new Date().getFullYear();

  const [goalsRes, summaryRes, atRiskRes, progressRes] = await Promise.all([
    sb.rpc('list_annual_goals_r1794', { p_year: currentYear }),
    sb.rpc('annual_goals_year_summary_r1794', { p_year: currentYear }),
    sb.rpc('top_at_risk_annual_goals_r1794', { p_year: currentYear }),
    sb.rpc('list_annual_goal_progress_r1794', { p_goal_id: null, p_year: currentYear }),
  ]);

  const goals: any[] = Array.isArray(goalsRes.data) ? goalsRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const atRisk: any[] = Array.isArray(atRiskRes.data) ? atRiskRes.data : [];
  const progress: any[] = Array.isArray(progressRes.data) ? progressRes.data : [];

  const goalsCols: Column<any>[] = [
    { key: 'goal_title', header: 'Goal', render: (r: any) => String(r.goal_title ?? '') },
    { key: 'goal_category', header: 'Category', render: (r: any) => String(r.goal_category ?? '') },
    { key: 'target', header: 'Target', render: (r: any) => `${Number(r.target_value ?? 0)} ${String(r.target_unit ?? '')}` },
    { key: 'current_value', header: 'Current', render: (r: any) => String(Number(r.current_value ?? 0)) },
    { key: 'pct_progress', header: 'Progress %', render: (r: any) => `${Number(r.pct_progress ?? 0)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'weight', header: 'Weight', render: (r: any) => String(r.weight ?? 0) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'total_goals', header: 'Total', render: (r: any) => String(r.total_goals ?? 0) },
    { key: 'on_track_count', header: 'On Track', render: (r: any) => String(r.on_track_count ?? 0) },
    { key: 'at_risk_count', header: 'At Risk', render: (r: any) => String(r.at_risk_count ?? 0) },
    { key: 'missed_count', header: 'Missed', render: (r: any) => String(r.missed_count ?? 0) },
    { key: 'exceeded_count', header: 'Exceeded', render: (r: any) => String(r.exceeded_count ?? 0) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => String(r.dropped_count ?? 0) },
    { key: 'avg_progress_pct', header: 'Avg Progress %', render: (r: any) => `${Number(r.avg_progress_pct ?? 0)}%` },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'goal_title', header: 'Goal', render: (r: any) => String(r.goal_title ?? '') },
    { key: 'goal_category', header: 'Category', render: (r: any) => String(r.goal_category ?? '') },
    { key: 'weight', header: 'Weight', render: (r: any) => String(r.weight ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'pct_progress', header: 'Progress %', render: (r: any) => `${Number(r.pct_progress ?? 0)}%` },
    { key: 'current_value', header: 'Current', render: (r: any) => String(Number(r.current_value ?? 0)) },
    { key: 'target_value', header: 'Target', render: (r: any) => `${Number(r.target_value ?? 0)} ${String(r.target_unit ?? '')}` },
  ];

  const progressCols: Column<any>[] = [
    { key: 'goal_title', header: 'Goal', render: (r: any) => String(r.goal_title ?? '') },
    { key: 'quarter', header: 'Quarter', render: (r: any) => String(r.quarter ?? '') },
    { key: 'progress_value', header: 'Progress', render: (r: any) => String(Number(r.progress_value ?? 0)) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'note', header: 'Note', render: (r: any) => String(r.note ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Founder Annual Goals Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Year {currentYear} — track founder annual goals & per-quarter progress.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Year Summary by Category</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top At-Risk Goals</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          Goals where status is at_risk or missed — sorted by weight (high importance first).
        </p>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Annual Goals</h2>
        <DataTable
          rows={goals}
          columns={goalsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Quarterly Progress</h2>
        <DataTable
          rows={progress}
          columns={progressCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
