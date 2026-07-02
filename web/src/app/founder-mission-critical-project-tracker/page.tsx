import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Project = {
  id: string;
  project_label: string;
  criticality: string;
  owner_email: string | null;
  target_date: string | null;
  status: string;
  captured_at: string;
};

type Tier1 = {
  id: string;
  project_label: string;
  owner_email: string | null;
  status: string;
  target_date: string | null;
  captured_at: string;
};

type Action = {
  id: string;
  project_id: string;
  project_label: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [projectsRes, tier1Res, actionsRes] = await Promise.all([
    sb.rpc('r2166_list_projects'),
    sb.rpc('r2166_tier_1_critical'),
    sb.rpc('r2166_recent_actions', { p_limit: 50 }),
  ]);

  const projects: Project[] = (projectsRes.data as Project[] | null) ?? [];
  const tier1: Tier1[] = (tier1Res.data as Tier1[] | null) ?? [];
  const actions: Action[] = (actionsRes.data as Action[] | null) ?? [];

  const projectCols: Column<Project>[] = [
    { key: 'project_label', header: 'Project', render: (r: any) => String(r.project_label ?? '') },
    { key: 'criticality', header: 'Tier', render: (r: any) => String(r.criticality ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'target_date', header: 'Target', render: (r: any) => (r.target_date ? String(r.target_date) : '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '') },
  ];

  const tier1Cols: Column<Tier1>[] = [
    { key: 'project_label', header: 'Project', render: (r: any) => String(r.project_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'target_date', header: 'Target', render: (r: any) => (r.target_date ? String(r.target_date) : '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '') },
  ];

  const actionCols: Column<Action>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '') },
    { key: 'project_label', header: 'Project', render: (r: any) => String(r.project_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  const tier1Count = tier1.length;
  const activeCount = projects.filter((p) => p.status === 'active' || p.status === 'at_risk' || p.status === 'critical').length;
  const completedCount = projects.filter((p) => p.status === 'completed').length;

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Mission-Critical Project Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track the projects that matter most. Tier 1 items are top priority; Tier 2 is high; Tier 3 is meaningful.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8, minWidth: 200 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Tier 1 in flight</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{tier1Count}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8, minWidth: 200 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active projects</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{activeCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8, minWidth: 200 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Completed</div>
            <div style={{ fontSize: 28, fontWeight: 700 }}>{completedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tier 1 critical, in flight</h2>
        <DataTable
          rows={tier1}
          columns={tier1Cols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All projects</h2>
        <DataTable
          rows={projects}
          columns={projectCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent action log</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
