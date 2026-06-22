import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHiringPipelineBoardPage() {
  const sb = await getSupabaseServerClient();

  const [candidatesRes, rolesRes, activitiesRes] = await Promise.all([
    sb.rpc('fhp_r1930_list_candidates', { p_limit: 100 }),
    sb.rpc('fhp_r1930_top_roles'),
    sb.rpc('fhp_r1930_recent_activities', { p_limit: 30 }),
  ]);

  const candidates: any[] = Array.isArray(candidatesRes.data) ? candidatesRes.data : [];
  const roles: any[] = Array.isArray(rolesRes.data) ? rolesRes.data : [];
  const activities: any[] = Array.isArray(activitiesRes.data) ? activitiesRes.data : [];

  const candidateColumns: Column<any>[] = [
    { key: 'candidate_name', header: 'Name', render: (r: any) => <span>{r.candidate_name ?? '-'}</span> },
    { key: 'role_label', header: 'Role', render: (r: any) => <span>{r.role_label ?? '-'}</span> },
    { key: 'candidate_email', header: 'Email', render: (r: any) => <span>{r.candidate_email ?? '-'}</span> },
    { key: 'stage', header: 'Stage', render: (r: any) => <span>{r.stage ?? '-'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '-'}</span> },
    { key: 'fit_score', header: 'Fit', render: (r: any) => <span>{r.fit_score ?? '-'}</span> },
    { key: 'sourced_at', header: 'Sourced', render: (r: any) => <span>{r.sourced_at ? new Date(r.sourced_at).toLocaleDateString() : '-'}</span> },
    { key: 'last_activity_at', header: 'Last Activity', render: (r: any) => <span>{r.last_activity_at ? new Date(r.last_activity_at).toLocaleDateString() : '-'}</span> },
  ];

  const roleColumns: Column<any>[] = [
    { key: 'role_label', header: 'Role', render: (r: any) => <span>{r.role_label ?? '-'}</span> },
    { key: 'active_count', header: 'Active', render: (r: any) => <span>{r.active_count ?? 0}</span> },
    { key: 'joined_count', header: 'Joined', render: (r: any) => <span>{r.joined_count ?? 0}</span> },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => <span>{r.dropped_count ?? 0}</span> },
    { key: 'avg_fit', header: 'Avg Fit', render: (r: any) => <span>{r.avg_fit ?? '-'}</span> },
  ];

  const activityColumns: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => <span>{r.candidate_name ?? '-'}</span> },
    { key: 'role_label', header: 'Role', render: (r: any) => <span>{r.role_label ?? '-'}</span> },
    { key: 'activity_type', header: 'Type', render: (r: any) => <span>{r.activity_type ?? '-'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '-'}</span> },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : '-'}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span>{(r.notes_md ?? '').slice(0, 80)}</span> },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Hiring Pipeline Board</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track candidates across stages (sourced and screen and interview and onsite and reference and offer and joined and dropped) per role.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Role Funnel Summary</h2>
        <DataTable rows={roles} columns={roleColumns} rowKey={(r: any, i: number) => String(r.role_label ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Candidates</h2>
        <DataTable rows={candidates} columns={candidateColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Activities</h2>
        <DataTable rows={activities} columns={activityColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
