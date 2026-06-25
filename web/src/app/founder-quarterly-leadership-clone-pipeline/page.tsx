import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyLeadershipClonePipelinePage() {
  const sb = await getSupabaseServerClient();

  const [clonesRes, actionsRes, topRes, roleRes, statusRes, trendRes, ownerRes] = await Promise.all([
    sb.rpc('list_clones_r2617'),
    sb.rpc('list_pipeline_actions_r2617'),
    sb.rpc('top_ready_candidates_r2617'),
    sb.rpc('role_kind_distribution_r2617'),
    sb.rpc('status_funnel_r2617'),
    sb.rpc('quarterly_pipeline_trend_r2617'),
    sb.rpc('owner_load_r2617'),
  ]);

  const clones: any[] = Array.isArray(clonesRes.data) ? clonesRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const roles: any[] = Array.isArray(roleRes.data) ? roleRes.data : [];
  const statuses: any[] = Array.isArray(statusRes.data) ? statusRes.data : [];
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const owners: any[] = Array.isArray(ownerRes.data) ? ownerRes.data : [];

  const cloneCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'role_target_kind', header: 'Role target', render: (r: any) => String(r.role_target_kind ?? '') },
    { key: 'readiness_pct', header: 'Readiness %', render: (r: any) => String(r.readiness_pct ?? 0) },
    { key: 'succession_target_quarter', header: 'Target qtr', render: (r: any) => String(r.succession_target_quarter ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'role_target_kind', header: 'Role', render: (r: any) => String(r.role_target_kind ?? '') },
    { key: 'action_kind', header: 'Action', render: (r: any) => String(r.action_kind ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'action_at', header: 'At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'role_target_kind', header: 'Role', render: (r: any) => String(r.role_target_kind ?? '') },
    { key: 'readiness_pct', header: 'Readiness %', render: (r: any) => String(r.readiness_pct ?? 0) },
    { key: 'succession_target_quarter', header: 'Target qtr', render: (r: any) => String(r.succession_target_quarter ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const roleCols: Column<any>[] = [
    { key: 'role_target_kind', header: 'Role', render: (r: any) => String(r.role_target_kind ?? '') },
    { key: 'candidate_count', header: 'Candidates', render: (r: any) => String(r.candidate_count ?? 0) },
    { key: 'avg_readiness', header: 'Avg readiness', render: (r: any) => String(r.avg_readiness ?? 0) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'candidate_count', header: 'Count', render: (r: any) => String(r.candidate_count ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'candidate_count', header: 'Candidates', render: (r: any) => String(r.candidate_count ?? 0) },
    { key: 'ready_count', header: 'Ready', render: (r: any) => String(r.ready_count ?? 0) },
    { key: 'avg_readiness', header: 'Avg readiness', render: (r: any) => String(r.avg_readiness ?? 0) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'candidate_count', header: 'Candidates', render: (r: any) => String(r.candidate_count ?? 0) },
    { key: 'open_actions', header: 'Open actions', render: (r: any) => String(r.open_actions ?? 0) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder quarterly leadership clone pipeline</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track candidates being built into leadership clones for COO, CMO, CFO, CTO, CPO, VP eng & head sales roles.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top ready candidates</h2>
        <DataTable rows={top} columns={topCols} emptyMessage="No candidates yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status funnel</h2>
        <DataTable rows={statuses} columns={statusCols} emptyMessage="No status data" rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Role kind distribution</h2>
        <DataTable rows={roles} columns={roleCols} emptyMessage="No role data" rowKey={(r: any, i: number) => String(r.role_target_kind ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly pipeline trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend yet" rowKey={(r: any, i: number) => String(r.quarter_label ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner load</h2>
        <DataTable rows={owners} columns={ownerCols} emptyMessage="No owners yet" rowKey={(r: any, i: number) => String(r.owner_email ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All clone candidates</h2>
        <DataTable rows={clones} columns={cloneCols} emptyMessage="No candidates yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pipeline actions</h2>
        <DataTable rows={actions} columns={actionCols} emptyMessage="No actions yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
