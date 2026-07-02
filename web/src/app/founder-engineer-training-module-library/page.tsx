import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [modulesRes, completionsRes, expiringRes, summaryRes, overdueRes] = await Promise.all([
    sb.rpc('list_modules_r1796'),
    sb.rpc('list_completions_r1796', { p_module_id: null, p_engineer_user_id: null }),
    sb.rpc('expiring_completions_r1796', { p_days_ahead: 30 }),
    sb.rpc('module_completion_summary_r1796'),
    sb.rpc('overdue_engineers_r1796'),
  ]);

  const modules: any[] = Array.isArray(modulesRes.data) ? modulesRes.data : [];
  const completions: any[] = Array.isArray(completionsRes.data) ? completionsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const overdue: any[] = Array.isArray(overdueRes.data) ? overdueRes.data : [];

  const activeModules = modules.filter((m: any) => m.status === 'active').length;
  const mandatoryModules = modules.filter((m: any) => m.mandatory === true).length;
  const totalCompletions = completions.filter((c: any) => c.status === 'completed').length;
  const inProgress = completions.filter((c: any) => c.status === 'in_progress').length;

  const modulesCols: Column<any>[] = [
    { key: 'module_name', header: 'Module', render: (r: any) => String(r.module_name ?? '-') },
    { key: 'module_category', header: 'Category', render: (r: any) => String(r.module_category ?? '-') },
    { key: 'duration_minutes', header: 'Duration (min)', render: (r: any) => Number(r.duration_minutes ?? 0).toLocaleString('en-IN') },
    { key: 'mandatory', header: 'Mandatory', render: (r: any) => (r.mandatory ? 'Yes' : 'No') },
    { key: 'refresh_interval_months', header: 'Refresh (mo)', render: (r: any) => r.refresh_interval_months ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  const completionsCols: Column<any>[] = [
    { key: 'module_name', header: 'Module', render: (r: any) => r.module_name ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleString() : '-' },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleString() : '-' },
    { key: 'score', header: 'Score', render: (r: any) => r.score ?? '-' },
    { key: 'next_due_at', header: 'Next Due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'module_name', header: 'Module', render: (r: any) => r.module_name ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleString() : '-' },
    { key: 'next_due_at', header: 'Next Due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleString() : '-' },
    { key: 'days_until_due', header: 'Days Left', render: (r: any) => Number(r.days_until_due ?? 0).toLocaleString('en-IN') },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'module_name', header: 'Module', render: (r: any) => r.module_name ?? '-' },
    { key: 'module_category', header: 'Category', render: (r: any) => String(r.module_category ?? '-') },
    { key: 'mandatory', header: 'Mandatory', render: (r: any) => (r.mandatory ? 'Yes' : 'No') },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => Number(r.in_progress_count ?? 0).toLocaleString('en-IN') },
    { key: 'completed_count', header: 'Completed', render: (r: any) => Number(r.completed_count ?? 0).toLocaleString('en-IN') },
    { key: 'expired_count', header: 'Expired', render: (r: any) => Number(r.expired_count ?? 0).toLocaleString('en-IN') },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score != null ? Number(r.avg_score).toFixed(2) : '-' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'overdue_count', header: 'Overdue Count', render: (r: any) => Number(r.overdue_count ?? 0).toLocaleString('en-IN') },
    { key: 'oldest_overdue_at', header: 'Oldest Overdue', render: (r: any) => r.oldest_overdue_at ? new Date(r.oldest_overdue_at).toLocaleString() : '-' },
    { key: 'module_names', header: 'Modules', render: (r: any) => r.module_names ?? '-' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Training Module Library</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Curate training modules & track per-engineer completion, refresh cycles, and overdue training (r1796).
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Snapshot</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active Modules</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{activeModules.toLocaleString('en-IN')}</div>
            <div style={{ fontSize: 12, color: '#666' }}>{mandatoryModules} mandatory</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Completions</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{totalCompletions.toLocaleString('en-IN')}</div>
            <div style={{ fontSize: 12, color: '#666' }}>{inProgress} in progress</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Expiring (30d)</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{expiring.length.toLocaleString('en-IN')}</div>
            <div style={{ fontSize: 12, color: '#666' }}>refresh required soon</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Overdue Engineers</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{overdue.length.toLocaleString('en-IN')}</div>
            <div style={{ fontSize: 12, color: '#666' }}>past due refresh</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Training Modules</h2>
        <DataTable rows={modules} columns={modulesCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Module Completion Summary</h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.module_id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiring Within 30 Days</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Overdue Engineers</h2>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Completions</h2>
        <DataTable rows={completions} columns={completionsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
