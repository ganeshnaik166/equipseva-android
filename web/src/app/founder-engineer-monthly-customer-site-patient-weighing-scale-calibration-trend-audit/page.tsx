import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = { visit_month: string; total_visits: number; completed: number; missed: number; failed: number; completion_pct: number };
type DriftingScale = { scale_asset_tag: string; site_name: string; scale_model: string; avg_pre_drift: number; max_pre_drift: number; trend_flag: string; visits: number };
type EngineerRow = { engineer_name: string; visits: number; completed: number; fails: number; avg_post_drift: number; on_time_pct: number };
type SeverityRow = { severity: string; incident_count: number; avg_delta_grams: number; adverse_events: number; open_count: number };
type SiteRisk = { site_name: string; city: string; visits: number; fails: number; incidents: number; critical_incidents: number; risk_score: number };
type UpcomingDue = { next_due_on: string; site_name: string; scale_asset_tag: string; scale_model: string; trend_flag: string; days_until: number };
type RootCause = { root_cause: string; count_n: number; avg_abs_delta: number; escalated: number; parts_replaced: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, drifting, engineers, severity, sites, due, rootCause] = await Promise.all([
    supabase.rpc('rpc_r3006_monthly_visit_summary'),
    supabase.rpc('rpc_r3006_top_drifting_scales'),
    supabase.rpc('rpc_r3006_engineer_leaderboard'),
    supabase.rpc('rpc_r3006_incident_severity_rollup'),
    supabase.rpc('rpc_r3006_site_risk_score'),
    supabase.rpc('rpc_r3006_upcoming_due'),
    supabase.rpc('rpc_r3006_root_cause_distribution'),
  ]);

  const monthlyRows: MonthlySummary[] = monthly.data ?? [];
  const driftingRows: DriftingScale[] = drifting.data ?? [];
  const engineerRows: EngineerRow[] = engineers.data ?? [];
  const severityRows: SeverityRow[] = severity.data ?? [];
  const siteRows: SiteRisk[] = sites.data ?? [];
  const dueRows: UpcomingDue[] = due.data ?? [];
  const rootCauseRows: RootCause[] = rootCause.data ?? [];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', cell: (r) => r.visit_month },
    { header: 'Total', cell: (r) => r.total_visits },
    { header: 'Completed', cell: (r) => r.completed },
    { header: 'Missed', cell: (r) => r.missed },
    { header: 'Failed', cell: (r) => r.failed },
    { header: 'Completion %', cell: (r) => `${r.completion_pct}%` },
  ];

  const driftingCols: Column<DriftingScale>[] = [
    { header: 'Asset', cell: (r) => r.scale_asset_tag },
    { header: 'Site', cell: (r) => r.site_name },
    { header: 'Model', cell: (r) => r.scale_model },
    { header: 'Avg Pre-Drift (g)', cell: (r) => r.avg_pre_drift },
    { header: 'Max Pre-Drift (g)', cell: (r) => r.max_pre_drift },
    { header: 'Trend', cell: (r) => r.trend_flag },
    { header: 'Visits', cell: (r) => r.visits },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', cell: (r) => r.engineer_name },
    { header: 'Visits', cell: (r) => r.visits },
    { header: 'Completed', cell: (r) => r.completed },
    { header: 'Fails', cell: (r) => r.fails },
    { header: 'Avg Post-Drift (g)', cell: (r) => r.avg_post_drift },
    { header: 'On-Time %', cell: (r) => `${r.on_time_pct}%` },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Incidents', cell: (r) => r.incident_count },
    { header: 'Avg |Delta| (g)', cell: (r) => r.avg_delta_grams },
    { header: 'Adverse Events', cell: (r) => r.adverse_events },
    { header: 'Open', cell: (r) => r.open_count },
  ];

  const siteCols: Column<SiteRisk>[] = [
    { header: 'Site', cell: (r) => r.site_name },
    { header: 'City', cell: (r) => r.city },
    { header: 'Visits', cell: (r) => r.visits },
    { header: 'Fails', cell: (r) => r.fails },
    { header: 'Incidents', cell: (r) => r.incidents },
    { header: 'Critical', cell: (r) => r.critical_incidents },
    { header: 'Risk Score', cell: (r) => r.risk_score },
  ];

  const dueCols: Column<UpcomingDue>[] = [
    { header: 'Due', cell: (r) => r.next_due_on },
    { header: 'Site', cell: (r) => r.site_name },
    { header: 'Asset', cell: (r) => r.scale_asset_tag },
    { header: 'Model', cell: (r) => r.scale_model },
    { header: 'Trend', cell: (r) => r.trend_flag },
    { header: 'Days Until', cell: (r) => r.days_until },
  ];

  const rootCauseCols: Column<RootCause>[] = [
    { header: 'Root Cause', cell: (r) => r.root_cause },
    { header: 'Count', cell: (r) => r.count_n },
    { header: 'Avg |Delta| (g)', cell: (r) => r.avg_abs_delta },
    { header: 'Escalated', cell: (r) => r.escalated },
    { header: 'Parts Replaced', cell: (r) => r.parts_replaced },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer-Site Patient Weighing-Scale Calibration & Trend Audit</h1>
        <p className="text-sm text-gray-600 mt-1">Round r3006 — monthly cal visits, drift trends, patient incidents & site risk</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Visit Summary</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No visits yet" rowKey={(r, i) => String((r as { visit_month?: string }).visit_month ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Drifting Scales (Pre-Cal Drift &gt;= threshold)</h2>
        <DataTable rows={driftingRows} columns={driftingCols} emptyMessage="No drifting scales" rowKey={(r, i) => String((r as { scale_asset_tag?: string }).scale_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Patient Incident Severity Rollup</h2>
        <DataTable rows={severityRows} columns={severityCols} emptyMessage="No incidents" rowKey={(r, i) => String((r as { severity?: string }).severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Site Risk Score</h2>
        <DataTable rows={siteRows} columns={siteCols} emptyMessage="No sites" rowKey={(r, i) => String((r as { site_name?: string }).site_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Due Calibrations</h2>
        <DataTable rows={dueRows} columns={dueCols} emptyMessage="Nothing due" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Incident Root-Cause Distribution</h2>
        <DataTable rows={rootCauseRows} columns={rootCauseCols} emptyMessage="No root causes" rowKey={(r, i) => String((r as { root_cause?: string }).root_cause ?? i)} />
      </section>
    </div>
  );
}
