import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderStrategicHirePipelinePage() {
  const supabase = await getSupabaseServerClient();

  const [
    hiresRes,
    interviewsRes,
    topCloseRes,
    funnelRes,
    cultureBreakdownRes,
    ownerLoadRes,
    weeklyTrendRes,
  ] = await Promise.all([
    supabase.rpc('list_hires_r2473'),
    supabase.rpc('list_interview_log_r2473'),
    supabase.rpc('top_close_prob_r2473'),
    supabase.rpc('stage_funnel_r2473'),
    supabase.rpc('culture_fit_breakdown_r2473'),
    supabase.rpc('owner_load_r2473'),
    supabase.rpc('weekly_pipeline_trend_r2473'),
  ]);

  const hires = (hiresRes.data ?? []) as any[];
  const interviews = (interviewsRes.data ?? []) as any[];
  const topClose = (topCloseRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const cultureBreakdown = (cultureBreakdownRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];
  const weeklyTrend = (weeklyTrendRes.data ?? []) as any[];

  const fmtRupees = (n: any) => (n == null ? '—' : `₹${Number(n).toLocaleString('en-IN')}`);

  const hireCols: Column<any>[] = [
    { key: 'role_name', header: 'Role', render: (r: any) => r.role_name },
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => r.candidate_name },
    { key: 'candidate_email', header: 'Email', render: (r: any) => r.candidate_email ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'culture_fit_score', header: 'Culture', render: (r: any) => `${r.culture_fit_score}/100` },
    { key: 'velocity_fit_score', header: 'Velocity', render: (r: any) => `${r.velocity_fit_score}/100` },
    { key: 'references_completed', header: 'Refs', render: (r: any) => r.references_completed ? 'Done' : 'Pending' },
    { key: 'offer_amount_rupees', header: 'Offer', render: (r: any) => fmtRupees(r.offer_amount_rupees) },
    { key: 'close_probability_pct', header: 'Close %', render: (r: any) => `${r.close_probability_pct}%` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const interviewCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => r.candidate_name ?? '—' },
    { key: 'role_name', header: 'Role', render: (r: any) => r.role_name ?? '—' },
    { key: 'interview_at', header: 'When', render: (r: any) => r.interview_at ? new Date(r.interview_at).toLocaleString() : '—' },
    { key: 'panel_kind', header: 'Panel', render: (r: any) => r.panel_kind },
    { key: 'interviewer_email', header: 'Interviewer', render: (r: any) => r.interviewer_email ?? '—' },
    { key: 'score', header: 'Score', render: (r: any) => `${r.score}/10` },
    { key: 'recommendation', header: 'Reco', render: (r: any) => r.recommendation },
    { key: 'summary_md', header: 'Summary', render: (r: any) => r.summary_md ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topCloseCols: Column<any>[] = [
    { key: 'role_name', header: 'Role', render: (r: any) => r.role_name },
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => r.candidate_name },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'close_probability_pct', header: 'Close %', render: (r: any) => `${r.close_probability_pct}%` },
    { key: 'culture_fit_score', header: 'Culture', render: (r: any) => `${r.culture_fit_score}/100` },
    { key: 'velocity_fit_score', header: 'Velocity', render: (r: any) => `${r.velocity_fit_score}/100` },
    { key: 'offer_amount_rupees', header: 'Offer', render: (r: any) => fmtRupees(r.offer_amount_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage },
    { key: 'hire_count', header: 'Count', render: (r: any) => r.hire_count },
    { key: 'pct', header: 'Percent', render: (r: any) => `${r.pct ?? 0}%` },
    { key: 'avg_close_prob', header: 'Avg Close %', render: (r: any) => r.avg_close_prob ?? '—' },
  ];

  const cultureCols: Column<any>[] = [
    { key: 'band', header: 'Culture Band', render: (r: any) => r.band },
    { key: 'hire_count', header: 'Count', render: (r: any) => r.hire_count },
    { key: 'avg_culture_fit', header: 'Avg Culture', render: (r: any) => r.avg_culture_fit ?? '—' },
    { key: 'avg_velocity_fit', header: 'Avg Velocity', render: (r: any) => r.avg_velocity_fit ?? '—' },
    { key: 'avg_close_prob', header: 'Avg Close %', render: (r: any) => r.avg_close_prob ?? '—' },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'active_hires', header: 'Active', render: (r: any) => r.active_hires },
    { key: 'closed_won', header: 'Won', render: (r: any) => r.closed_won },
    { key: 'closed_lost', header: 'Lost', render: (r: any) => r.closed_lost },
    { key: 'avg_close_prob', header: 'Avg Close %', render: (r: any) => r.avg_close_prob ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ? new Date(r.week_start).toLocaleDateString() : '—' },
    { key: 'new_hires', header: 'New', render: (r: any) => r.new_hires },
    { key: 'closed_won', header: 'Won', render: (r: any) => r.closed_won },
    { key: 'closed_lost', header: 'Lost', render: (r: any) => r.closed_lost },
    { key: 'avg_close_prob', header: 'Avg Close %', render: (r: any) => r.avg_close_prob ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Strategic Hire Pipeline</h1>
        <p className="text-sm text-gray-600">
          Role > candidate > stage > culture-fit > velocity-fit > references > offer-status > close prob.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stage Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No hires tracked."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Close Probability</h2>
        <DataTable
          rows={topClose}
          columns={topCloseCols}
          emptyMessage="No active candidates."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Culture-Fit Breakdown</h2>
        <DataTable
          rows={cultureBreakdown}
          columns={cultureCols}
          emptyMessage="No culture-fit data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Pipeline Trend</h2>
        <DataTable
          rows={weeklyTrend}
          columns={trendCols}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Strategic Hires</h2>
        <DataTable
          rows={hires}
          columns={hireCols}
          emptyMessage="No hires in pipeline yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Interview Log</h2>
        <DataTable
          rows={interviews}
          columns={interviewCols}
          emptyMessage="No interviews logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
