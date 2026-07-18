import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyLeadershipSelfAssessmentPage() {
  const supabase = await getSupabaseServerClient();

  const [
    assessmentsRes,
    actionsRes,
    trendRes,
    growthAreasRes,
    distributionRes,
    funnelRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_assessments_r2589'),
    supabase.rpc('list_growth_actions_r2589'),
    supabase.rpc('monthly_score_trend_r2589'),
    supabase.rpc('top_growth_areas_r2589'),
    supabase.rpc('score_distribution_r2589'),
    supabase.rpc('action_status_funnel_r2589'),
    supabase.rpc('founder_pulse_summary_r2589'),
  ]);

  const assessments: any[] = assessmentsRes.data ?? [];
  const actions: any[] = actionsRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const growthAreas: any[] = growthAreasRes.data ?? [];
  const distribution: any[] = distributionRes.data ?? [];
  const funnel: any[] = funnelRes.data ?? [];
  const pulse: any[] = pulseRes.data ?? [];

  const assessmentCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '' },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => String(r.clarity_score ?? '') },
    { key: 'delegation_score', header: 'Delegation', render: (r: any) => String(r.delegation_score ?? '') },
    { key: 'velocity_score', header: 'Velocity', render: (r: any) => String(r.velocity_score ?? '') },
    { key: 'empathy_score', header: 'Empathy', render: (r: any) => String(r.empathy_score ?? '') },
    { key: 'focus_score', header: 'Focus', render: (r: any) => String(r.focus_score ?? '') },
    { key: 'decision_quality_score', header: 'Decision Q', render: (r: any) => String(r.decision_quality_score ?? '') },
    { key: 'overall_score', header: 'Overall', render: (r: any) => String(r.overall_score ?? '') },
    { key: 'top_strength_md', header: 'Top Strength', render: (r: any) => r.top_strength_md ?? '' },
    { key: 'top_growth_area_md', header: 'Top Growth Area', render: (r: any) => r.top_growth_area_md ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '' },
    { key: 'action_at', header: 'Action At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleDateString() : '' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind ?? '' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '' },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => String(r.clarity_score ?? '') },
    { key: 'delegation_score', header: 'Delegation', render: (r: any) => String(r.delegation_score ?? '') },
    { key: 'velocity_score', header: 'Velocity', render: (r: any) => String(r.velocity_score ?? '') },
    { key: 'empathy_score', header: 'Empathy', render: (r: any) => String(r.empathy_score ?? '') },
    { key: 'focus_score', header: 'Focus', render: (r: any) => String(r.focus_score ?? '') },
    { key: 'decision_quality_score', header: 'Decision Q', render: (r: any) => String(r.decision_quality_score ?? '') },
    { key: 'overall_score', header: 'Overall', render: (r: any) => String(r.overall_score ?? '') },
  ];

  const growthAreaCols: Column<any>[] = [
    { key: 'growth_area', header: 'Growth Area', render: (r: any) => r.growth_area ?? '' },
    { key: 'mentions', header: 'Mentions', render: (r: any) => String(r.mentions ?? '') },
  ];

  const distributionCols: Column<any>[] = [
    { key: 'dimension', header: 'Dimension', render: (r: any) => r.dimension ?? '' },
    { key: 'avg_score', header: 'Avg', render: (r: any) => String(r.avg_score ?? '') },
    { key: 'min_score', header: 'Min', render: (r: any) => String(r.min_score ?? '') },
    { key: 'max_score', header: 'Max', render: (r: any) => String(r.max_score ?? '') },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'count', header: 'Count', render: (r: any) => String(r.count ?? '') },
  ];

  const pulseCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric ?? '' },
    { key: 'value', header: 'Value', render: (r: any) => String(r.value ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Monthly Leadership Self-Assessment</h1>
        <p className="text-sm text-gray-600">Month &gt; clarity & delegation &gt; velocity & empathy &gt; focus & decision quality =&gt; overall.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Founder Pulse Summary</h2>
        <DataTable
          rows={pulse}
          columns={pulseCols}
          emptyMessage="No pulse data."
          rowKey={(r: any, i: number) => String(r.id ?? r.metric ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Assessments</h2>
        <DataTable
          rows={assessments}
          columns={assessmentCols}
          emptyMessage="No assessments yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Score Trend (ASC by month)</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.id ?? r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Score Distribution by Dimension</h2>
        <DataTable
          rows={distribution}
          columns={distributionCols}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.id ?? r.dimension ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Growth Areas</h2>
        <DataTable
          rows={growthAreas}
          columns={growthAreaCols}
          emptyMessage="No growth areas logged."
          rowKey={(r: any, i: number) => String(r.id ?? r.growth_area ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Growth Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No growth actions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No funnel data."
          rowKey={(r: any, i: number) => String(r.id ?? r.status ?? i)}
        />
      </section>
    </div>
  );
}
