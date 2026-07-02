import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderStrategicHireTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [hiresRes, pipelineRes, recentRes] = await Promise.all([
    sb.rpc('founder_strategic_hire_list_hires_r2122'),
    sb.rpc('founder_strategic_hire_active_pipeline_r2122'),
    sb.rpc('founder_strategic_hire_recent_actions_r2122'),
  ]);

  const hires = (hiresRes.data ?? []) as any[];
  const pipeline = (pipelineRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const hireColumns: Column<any>[] = [
    { key: 'role_label', header: 'Role', render: (r: any) => String(r.role_label ?? '') },
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'target_close_date', header: 'Target Close', render: (r: any) => r.target_close_date ? String(r.target_close_date) : 'unset' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const pipelineColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'hire_count', header: 'Count', render: (r: any) => String(r.hire_count ?? 0) },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'role_label', header: 'Role', render: (r: any) => String(r.role_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Strategic Hire Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track senior strategic hires across VP and C-level roles. Pipeline status, target close dates, and action log.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineColumns}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Tracked Hires</h2>
        <DataTable
          rows={hires}
          columns={hireColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.action_id ?? i)}
        />
      </section>
    </div>
  );
}
