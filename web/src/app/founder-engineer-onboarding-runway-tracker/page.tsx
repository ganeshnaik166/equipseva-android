import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerOnboardingRunwayTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    onboardingRes,
    rampRes,
    overdueRes,
    belowCurveRes,
    topPerformersRes,
    distributionRes,
    mentorLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_onboarding_r2418'),
    supabase.rpc('list_ramp_metrics_r2418'),
    supabase.rpc('overdue_milestones_r2418'),
    supabase.rpc('below_curve_engineers_r2418'),
    supabase.rpc('top_ramp_performers_r2418'),
    supabase.rpc('ramp_distribution_r2418'),
    supabase.rpc('mentor_load_r2418'),
  ]);

  const onboarding = (onboardingRes.data ?? []) as any[];
  const ramp = (rampRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const belowCurve = (belowCurveRes.data ?? []) as any[];
  const topPerformers = (topPerformersRes.data ?? []) as any[];
  const distribution = (distributionRes.data ?? []) as any[];
  const mentorLoad = (mentorLoadRes.data ?? []) as any[];

  const fmtDate = (d: any) => (d ? new Date(d).toLocaleDateString() : '—');
  const fmtTs = (d: any) => (d ? new Date(d).toLocaleString() : '—');

  const onboardingCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'hire_date', header: 'Hire Date', render: (r: any) => fmtDate(r.hire_date) },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'target_day', header: 'Target Day', render: (r: any) => `D+${r.target_day}` },
    { key: 'achieved_at', header: 'Achieved', render: (r: any) => fmtTs(r.achieved_at) },
    { key: 'days_to_achieve', header: 'Days', render: (r: any) => r.days_to_achieve ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => r.mentor_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const rampCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'hire_date', header: 'Hire Date', render: (r: any) => fmtDate(r.hire_date) },
    { key: 'days_since_hire', header: 'Days Since Hire', render: (r: any) => r.days_since_hire },
    { key: 'shadowing_hours', header: 'Shadow Hrs', render: (r: any) => r.shadowing_hours },
    { key: 'solo_jobs', header: 'Solo Jobs', render: (r: any) => r.solo_jobs },
    { key: 'supervised_jobs', header: 'Supervised', render: (r: any) => r.supervised_jobs },
    { key: 'csat_avg', header: 'CSAT', render: (r: any) => r.csat_avg ?? '—' },
    { key: 'slo_breaches', header: 'SLO Breach', render: (r: any) => r.slo_breaches },
    { key: 'ramp_score_pct', header: 'Ramp Score', render: (r: any) => `${r.ramp_score_pct}%` },
    { key: 'status_label', header: 'Status', render: (r: any) => r.status_label },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'hire_date', header: 'Hire Date', render: (r: any) => fmtDate(r.hire_date) },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'target_day', header: 'Target Day', render: (r: any) => `D+${r.target_day}` },
    { key: 'days_past_target', header: 'Days Past', render: (r: any) => r.days_past_target },
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => r.mentor_email ?? '—' },
  ];

  const belowCurveCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'hire_date', header: 'Hire Date', render: (r: any) => fmtDate(r.hire_date) },
    { key: 'ramp_score_pct', header: 'Score', render: (r: any) => `${r.ramp_score_pct}%` },
    { key: 'solo_jobs', header: 'Solo Jobs', render: (r: any) => r.solo_jobs },
    { key: 'csat_avg', header: 'CSAT', render: (r: any) => r.csat_avg ?? '—' },
    { key: 'slo_breaches', header: 'SLO Breach', render: (r: any) => r.slo_breaches },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topPerformersCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'hire_date', header: 'Hire Date', render: (r: any) => fmtDate(r.hire_date) },
    { key: 'ramp_score_pct', header: 'Score', render: (r: any) => `${r.ramp_score_pct}%` },
    { key: 'solo_jobs', header: 'Solo Jobs', render: (r: any) => r.solo_jobs },
    { key: 'csat_avg', header: 'CSAT', render: (r: any) => r.csat_avg ?? '—' },
    { key: 'status_label', header: 'Status', render: (r: any) => r.status_label },
  ];

  const distributionCols: Column<any>[] = [
    { key: 'status_label', header: 'Status', render: (r: any) => r.status_label },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => `${r.avg_score}%` },
    { key: 'avg_solo_jobs', header: 'Avg Solo Jobs', render: (r: any) => r.avg_solo_jobs },
  ];

  const mentorCols: Column<any>[] = [
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => r.mentor_email },
    { key: 'mentee_count', header: 'Mentees', render: (r: any) => r.mentee_count },
    { key: 'pending_milestones', header: 'Pending', render: (r: any) => r.pending_milestones },
    { key: 'achieved_milestones', header: 'Achieved', render: (r: any) => r.achieved_milestones },
    { key: 'overdue_milestones', header: 'Overdue', render: (r: any) => r.overdue_milestones },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Engineer Onboarding Runway Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        New hire ramp-up: milestones, days since start, shadowing hours, first-solo-call timing & ramp score.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Ramp Distribution</h2>
        <DataTable
          rows={distribution}
          columns={distributionCols}
          emptyMessage="No ramp data yet."
          rowKey={(r: any, i: number) => String(r.id ?? r.status_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Overdue Milestones</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue milestones."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Below-Curve Engineers</h2>
        <DataTable
          rows={belowCurve}
          columns={belowCurveCols}
          emptyMessage="All engineers on or above curve."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Ramp Performers</h2>
        <DataTable
          rows={topPerformers}
          columns={topPerformersCols}
          emptyMessage="No top performers yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Ramp Metrics (All Engineers)</h2>
        <DataTable
          rows={ramp}
          columns={rampCols}
          emptyMessage="No ramp metrics yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Mentor Load</h2>
        <DataTable
          rows={mentorLoad}
          columns={mentorCols}
          emptyMessage="No mentor assignments."
          rowKey={(r: any, i: number) => String(r.id ?? r.mentor_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Onboarding Milestones (All)</h2>
        <DataTable
          rows={onboarding}
          columns={onboardingCols}
          emptyMessage="No milestones logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
