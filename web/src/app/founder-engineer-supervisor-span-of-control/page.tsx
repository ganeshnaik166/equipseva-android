import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AssignmentRow = {
  id: string;
  supervisor_id: string;
  engineer_id: string;
  region: string;
  assigned_on: string;
  unassigned_on: string | null;
  status: string;
  days_assigned: number;
};

type SpanRow = {
  supervisor_id: string;
  active_reports: number;
  terminated_reports: number;
  reassigned_reports: number;
  regions_covered: number;
  oldest_assignment_days: number;
};

type OverloadRow = {
  supervisor_id: string;
  active_reports: number;
  threshold_used: number;
  overload_by: number;
};

type ThresholdRow = {
  id: string;
  tier: string;
  optimal_min: number;
  optimal_max: number;
  overload_threshold: number;
  notes: string;
};

type OrgStatsRow = {
  total_supervisors: number;
  total_active_assignments: number;
  avg_active_reports: number;
  max_active_reports: number;
  overloaded_count: number;
  understaffed_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [assignRes, spanRes, overloadRes, threshRes, statsRes] = await Promise.all([
    sb.rpc('list_supervisor_assignments_r2246'),
    sb.rpc('supervisor_span_summary_r2246'),
    sb.rpc('overloaded_supervisors_r2246', { p_threshold: 12 }),
    sb.rpc('list_ratio_thresholds_r2246'),
    sb.rpc('supervisor_org_stats_r2246'),
  ]);

  const assignments: AssignmentRow[] = (assignRes.data as AssignmentRow[] | null) ?? [];
  const span: SpanRow[] = (spanRes.data as SpanRow[] | null) ?? [];
  const overload: OverloadRow[] = (overloadRes.data as OverloadRow[] | null) ?? [];
  const thresholds: ThresholdRow[] = (threshRes.data as ThresholdRow[] | null) ?? [];
  const stats: OrgStatsRow | null = ((statsRes.data as OrgStatsRow[] | null) ?? [])[0] ?? null;

  const assignmentCols: Column<AssignmentRow>[] = [
    { key: 'supervisor_id', header: 'Supervisor', render: (r: any) => String(r.supervisor_id).slice(0, 8) },
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => String(r.engineer_id).slice(0, 8) },
    { key: 'region', header: 'Region', render: (r: any) => r.region },
    { key: 'assigned_on', header: 'Assigned', render: (r: any) => r.assigned_on },
    { key: 'unassigned_on', header: 'Unassigned', render: (r: any) => r.unassigned_on ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'days_assigned', header: 'Days', render: (r: any) => r.days_assigned },
  ];

  const spanCols: Column<SpanRow>[] = [
    { key: 'supervisor_id', header: 'Supervisor', render: (r: any) => String(r.supervisor_id).slice(0, 8) },
    { key: 'active_reports', header: 'Active reports', render: (r: any) => r.active_reports },
    { key: 'terminated_reports', header: 'Terminated', render: (r: any) => r.terminated_reports },
    { key: 'reassigned_reports', header: 'Reassigned', render: (r: any) => r.reassigned_reports },
    { key: 'regions_covered', header: 'Regions', render: (r: any) => r.regions_covered },
    { key: 'oldest_assignment_days', header: 'Oldest active (days)', render: (r: any) => r.oldest_assignment_days },
  ];

  const overloadCols: Column<OverloadRow>[] = [
    { key: 'supervisor_id', header: 'Supervisor', render: (r: any) => String(r.supervisor_id).slice(0, 8) },
    { key: 'active_reports', header: 'Active reports', render: (r: any) => r.active_reports },
    { key: 'threshold_used', header: 'Threshold', render: (r: any) => r.threshold_used },
    { key: 'overload_by', header: 'Overload by', render: (r: any) => r.overload_by },
  ];

  const threshCols: Column<ThresholdRow>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier },
    { key: 'optimal_min', header: 'Optimal min', render: (r: any) => r.optimal_min },
    { key: 'optimal_max', header: 'Optimal max', render: (r: any) => r.optimal_max },
    { key: 'overload_threshold', header: 'Overload at', render: (r: any) => r.overload_threshold },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Supervisor Span-of-Control Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track how many engineers each supervisor manages, optimal ratio bands by tier, and overload flags when active reports exceed safe thresholds.
      </p>

      {stats && (
        <section style={{ marginBottom: 32, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total supervisors</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{stats.total_supervisors}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active assignments</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{stats.total_active_assignments}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg active reports</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{stats.avg_active_reports}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Max active reports</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{stats.max_active_reports}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Overloaded (&gt;= 12)</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#b91c1c' }}>{stats.overloaded_count}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Understaffed (&lt; 3)</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#a16207' }}>{stats.understaffed_count}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Span of control per supervisor ({span.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Active reports per supervisor. Healthy span depends on tier: junior 3-6, senior 5-9, lead 8-14, principal 12-20.
        </p>
        <DataTable
          rows={span}
          columns={spanCols}
          rowKey={(r: any, i: number) => String(r.supervisor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overloaded supervisors ({overload.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Supervisors with active reports &gt;= 12 (default lead-tier overload threshold). Reassign engineers or split team.
        </p>
        <DataTable
          rows={overload}
          columns={overloadCols}
          rowKey={(r: any, i: number) => String(r.supervisor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Ratio thresholds by tier ({thresholds.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Optimal span bands per tier. Industry benchmark: junior &lt; senior &lt; lead &lt; principal.
        </p>
        <DataTable
          rows={thresholds}
          columns={threshCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All assignments ({assignments.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Full assignment history including reassigned and terminated rows.
        </p>
        <DataTable
          rows={assignments}
          columns={assignmentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
