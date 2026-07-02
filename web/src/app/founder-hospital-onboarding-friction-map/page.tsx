import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [frictionsRes, stagesRes, actionsRes] = await Promise.all([
    sb.rpc('list_frictions_r1935'),
    sb.rpc('top_friction_stages_r1935'),
    sb.rpc('recent_actions_r1935'),
  ]);

  const frictions: any[] = Array.isArray(frictionsRes.data) ? frictionsRes.data : [];
  const stages: any[] = Array.isArray(stagesRes.data) ? stagesRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const frictionCols: Column<any>[] = [
    { key: 'surfaced_at', header: 'Surfaced', render: (r: any) => r.surfaced_at ? new Date(r.surfaced_at).toLocaleString() : '' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_id ?? '' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '' },
    { key: 'friction_score', header: 'Score', render: (r: any) => String(r.friction_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'blocker_md', header: 'Blocker', render: (r: any) => (r.blocker_md ?? '').slice(0, 80) },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => r.resolved_at ? new Date(r.resolved_at).toLocaleString() : '' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '' },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => String(r.avg_score ?? '') },
    { key: 'max_score', header: 'Max score', render: (r: any) => String(r.max_score ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => (r.outcome_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Onboarding Friction Map</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Map onboarding friction per hospital and stage. Score range 1 to 10. Higher means more friction.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top friction stages</h2>
        <DataTable rows={stages} columns={stageCols} rowKey={(r: any, i: number) => String(r.stage ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Friction entries</h2>
        <DataTable rows={frictions} columns={frictionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
