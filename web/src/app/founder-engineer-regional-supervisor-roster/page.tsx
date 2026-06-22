import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overviewRes, listRes, kpiRes, escalRes, reviewRes, riskRes, tierRes] = await Promise.all([
    sb.rpc('r2262_roster_overview'),
    sb.rpc('r2262_roster_list'),
    sb.rpc('r2262_kpi_by_region'),
    sb.rpc('r2262_escalation_matrix'),
    sb.rpc('r2262_review_history'),
    sb.rpc('r2262_at_risk_supervisors'),
    sb.rpc('r2262_tier_distribution'),
  ]);

  const overview = overviewRes.data?.[0] ?? null;
  const rosterRows = listRes.data ?? [];
  const kpiRows = kpiRes.data ?? [];
  const escalRows = escalRes.data ?? [];
  const reviewRows = reviewRes.data ?? [];
  const riskRows = riskRes.data ?? [];
  const tierRows = tierRes.data ?? [];

  const fmtPct = (bps: number) => `${(bps / 100).toFixed(1)}%`;

  const rosterCols: Column<any>[] = [
    { key: 'supervisor_email', header: 'Supervisor', render: (r) => r.supervisor_email },
    { key: 'region_name', header: 'Region', render: (r) => `${r.region_name} (${r.city}, ${r.state_code})` },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'span_of_control', header: 'Span', render: (r) => r.span_of_control },
    { key: 'escalation_level', header: 'Esc L', render: (r) => `L${r.escalation_level}` },
    { key: 'jobs', header: 'Jobs (actual/target)', render: (r) => `${r.kpi_jobs_actual} / ${r.kpi_jobs_target}` },
    { key: 'csat', header: 'CSAT', render: (r) => fmtPct(r.kpi_csat_actual_bps) },
    { key: 'sla', header: 'SLA', render: (r) => fmtPct(r.kpi_sla_actual_bps) },
    { key: 'review_score', header: 'Review', render: (r) => r.monthly_review_score ?? '—' },
  ];

  const kpiCols: Column<any>[] = [
    { key: 'region_name', header: 'Region', render: (r) => r.region_name },
    { key: 'supervisor_count', header: 'Supervisors', render: (r) => r.supervisor_count },
    { key: 'total_span', header: 'Total Span', render: (r) => r.total_span },
    { key: 'jobs', header: 'Jobs (act/tgt)', render: (r) => `${r.jobs_actual} / ${r.jobs_target}` },
    { key: 'jobs_attainment_bps', header: 'Attainment', render: (r) => fmtPct(r.jobs_attainment_bps) },
    { key: 'avg_csat_bps', header: 'Avg CSAT', render: (r) => fmtPct(r.avg_csat_bps) },
    { key: 'avg_sla_bps', header: 'Avg SLA', render: (r) => fmtPct(r.avg_sla_bps) },
    { key: 'meets_jobs', header: 'Meets Jobs', render: (r) => (r.meets_jobs ? 'Yes' : 'No') },
    { key: 'meets_csat', header: 'Meets CSAT', render: (r) => (r.meets_csat ? 'Yes' : 'No') },
    { key: 'meets_sla', header: 'Meets SLA', render: (r) => (r.meets_sla ? 'Yes' : 'No') },
  ];

  const escalCols: Column<any>[] = [
    { key: 'escalation_level', header: 'Level', render: (r) => `L${r.escalation_level}` },
    { key: 'level_label', header: 'Label', render: (r) => r.level_label },
    { key: 'supervisor_count', header: 'Count', render: (r) => r.supervisor_count },
    { key: 'supervisor_emails', header: 'Supervisors', render: (r) => r.supervisor_emails },
    { key: 'regions_covered', header: 'Regions', render: (r) => r.regions_covered },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'review_month', header: 'Month', render: (r) => String(r.review_month).slice(0, 7) },
    { key: 'supervisor_email', header: 'Supervisor', render: (r) => r.supervisor_email },
    { key: 'region_name', header: 'Region', render: (r) => r.region_name },
    { key: 'jobs_completed', header: 'Jobs', render: (r) => r.jobs_completed },
    { key: 'csat_bps', header: 'CSAT', render: (r) => fmtPct(r.csat_bps) },
    { key: 'sla_bps', header: 'SLA', render: (r) => fmtPct(r.sla_bps) },
    { key: 'escalations_handled', header: 'Escal.', render: (r) => r.escalations_handled },
    { key: 'attrition_count', header: 'Attrition', render: (r) => r.attrition_count },
    { key: 'review_score', header: 'Score', render: (r) => r.review_score },
    { key: 'rating', header: 'Rating', render: (r) => r.rating },
    { key: 'reviewer_email', header: 'Reviewer', render: (r) => r.reviewer_email },
  ];

  const riskCols: Column<any>[] = [
    { key: 'supervisor_email', header: 'Supervisor', render: (r) => r.supervisor_email },
    { key: 'region_name', header: 'Region', render: (r) => r.region_name },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'monthly_review_score', header: 'Review', render: (r) => r.monthly_review_score ?? '—' },
    { key: 'jobs', header: 'Jobs (act/tgt)', render: (r) => `${r.kpi_jobs_actual} / ${r.kpi_jobs_target}` },
    { key: 'jobs_gap_pct', header: 'Gap %', render: (r) => `${r.jobs_gap_pct}%` },
    { key: 'last_rating', header: 'Last Rating', render: (r) => r.last_rating ?? '—' },
    { key: 'risk_reason', header: 'Risk', render: (r) => r.risk_reason },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'supervisor_count', header: 'Count', render: (r) => r.supervisor_count },
    { key: 'avg_span', header: 'Avg Span', render: (r) => r.avg_span },
    { key: 'avg_review_score', header: 'Avg Review', render: (r) => r.avg_review_score },
    { key: 'avg_csat_bps', header: 'Avg CSAT', render: (r) => fmtPct(r.avg_csat_bps) },
    { key: 'meets_target_count', header: 'Meets Jobs Target', render: (r) => r.meets_target_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Regional Supervisor Roster</h1>
        <p className="text-sm text-gray-600 mt-1">
          Supervisor per region, regional KPI accountability, escalation matrix, monthly review.
        </p>
      </header>

      {overview && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Total Supervisors</div>
            <div className="text-2xl font-bold">{overview.total_supervisors}</div>
            <div className="text-xs text-gray-500 mt-1">
              {overview.active_count} active / {overview.on_leave_count} on leave
            </div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Probation / Exiting</div>
            <div className="text-2xl font-bold">
              {overview.probation_count} / {overview.exiting_count}
            </div>
            <div className="text-xs text-gray-500 mt-1">at-risk supervisors</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Total Span of Control</div>
            <div className="text-2xl font-bold">{overview.total_span}</div>
            <div className="text-xs text-gray-500 mt-1">avg {overview.avg_span} per supervisor</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Regions Covered</div>
            <div className="text-2xl font-bold">{overview.regions_covered}</div>
            <div className="text-xs text-gray-500 mt-1">regional coverage</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Active Roster</h2>
        <DataTable columns={rosterCols} rows={rosterRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Regional KPI Accountability</h2>
        <p className="text-xs text-gray-500 mb-2">Meets thresholds: CSAT (&gt;= 85%), SLA (&gt;= 95%), Jobs attainment vs target.</p>
        <DataTable columns={kpiCols} rows={kpiRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Escalation Matrix</h2>
        <p className="text-xs text-gray-500 mb-2">L1 first response &gt; L2 regional lead &gt; L3 senior &gt; L4 principal director.</p>
        <DataTable columns={escalCols} rows={escalRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Distribution</h2>
        <DataTable columns={tierCols} rows={tierRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-Risk Supervisors</h2>
        <p className="text-xs text-gray-500 mb-2">Probation, exiting, review score (&lt; 60), or jobs gap (&lt; 75% of target).</p>
        <DataTable columns={riskCols} rows={riskRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Review History</h2>
        <DataTable columns={reviewCols} rows={reviewRows} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
