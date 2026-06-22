import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHireManageCoachCyclePage() {
  const sb = await getSupabaseServerClient();

  const [reportsRes, atRiskRes, recentRes] = await Promise.all([
    sb.rpc('list_reports_r2118'),
    sb.rpc('at_risk_r2118'),
    sb.rpc('recent_sessions_r2118'),
  ]);

  const reports = (reportsRes.data ?? []) as any[];
  const atRisk = (atRiskRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const reportCols: Column<any>[] = [
    { key: 'direct_report_name', header: 'Report', render: (r: any) => String(r.direct_report_name ?? '') },
    { key: 'role_label', header: 'Role', render: (r: any) => String(r.role_label ?? '') },
    { key: 'current_cycle_phase', header: 'Phase', render: (r: any) => String(r.current_cycle_phase ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'hired_at', header: 'Hired', render: (r: any) => r.hired_at ? new Date(r.hired_at).toLocaleDateString() : '' },
    { key: 'last_review_at', header: 'Last Review', render: (r: any) => r.last_review_at ? new Date(r.last_review_at).toLocaleDateString() : 'none' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'direct_report_name', header: 'Report', render: (r: any) => String(r.direct_report_name ?? '') },
    { key: 'role_label', header: 'Role', render: (r: any) => String(r.role_label ?? '') },
    { key: 'current_cycle_phase', header: 'Phase', render: (r: any) => String(r.current_cycle_phase ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_review_at', header: 'Last Review', render: (r: any) => r.last_review_at ? new Date(r.last_review_at).toLocaleDateString() : 'none' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'direct_report_name', header: 'Report', render: (r: any) => String(r.direct_report_name ?? '') },
    { key: 'session_type', header: 'Type', render: (r: any) => String(r.session_type ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder Hire-Manage-Coach Cycle
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track each direct report through hire, manage, and coach phases. Log 1on1 sessions, mark
        status, and surface anyone at risk or in exit planning.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Direct Reports ({reports.length})
        </h2>
        <DataTable
          rows={reports}
          columns={reportCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          At Risk and Exit Planning ({atRisk.length})
        </h2>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Coaching Sessions (last 30 days) — {recent.length}
        </h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
