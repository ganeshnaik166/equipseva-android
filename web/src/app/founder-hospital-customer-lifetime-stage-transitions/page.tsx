import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [transitionsRes, concerningRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_transitions_r2187'),
    sb.rpc('concerning_r2187'),
    sb.rpc('recent_actions_r2187'),
  ]);

  const transitions = (transitionsRes.data ?? []) as any[];
  const concerning = (concerningRes.data ?? []) as any[];
  const recentActions = (recentActionsRes.data ?? []) as any[];

  const transitionCols: Column<any>[] = [
    { key: 'transition_at', header: 'When', render: (r: any) => new Date(r.transition_at).toLocaleString() },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'from_stage', header: 'From', render: (r: any) => String(r.from_stage ?? '') },
    { key: 'to_stage', header: 'To', render: (r: any) => String(r.to_stage ?? '') },
    { key: 'days_in_prior_stage', header: 'Days prior', render: (r: any) => String(r.days_in_prior_stage ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const concerningCols: Column<any>[] = [
    { key: 'transition_at', header: 'When', render: (r: any) => new Date(r.transition_at).toLocaleString() },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'from_stage', header: 'From', render: (r: any) => String(r.from_stage ?? '') },
    { key: 'to_stage', header: 'To', render: (r: any) => String(r.to_stage ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'transition_id', header: 'Transition', render: (r: any) => String(r.transition_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>
        Hospital Customer Lifetime Stage Transitions
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track transitions between customer lifetime stages. Status flags include normal, concerning, positive,
        and escalation. Founders log observations & interventions per transition.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent transitions ({transitions.length})
        </h2>
        <DataTable rows={transitions} columns={transitionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Concerning & escalation ({concerning.length})
        </h2>
        <DataTable rows={concerning} columns={concerningCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent actions ({recentActions.length})
        </h2>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
