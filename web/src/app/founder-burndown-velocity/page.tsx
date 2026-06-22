import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderBurndownVelocityPage() {
  const sb = await getSupabaseServerClient();

  const [velocitiesRes, currentRes, recentRes] = await Promise.all([
    sb.rpc('list_velocities_r2034'),
    sb.rpc('current_velocity_r2034'),
    sb.rpc('recent_actions_r2034', { p_limit: 25 }),
  ]);

  const velocities: any[] = Array.isArray(velocitiesRes.data) ? velocitiesRes.data : [];
  const current: any[] = Array.isArray(currentRes.data) ? currentRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const velocityCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'ships', header: 'Ships actual of target', render: (r: any) => `${r.ships_actual ?? 0} of ${r.ships_target ?? 0}` },
    { key: 'batches', header: 'Batches actual of target', render: (r: any) => `${r.batches_actual ?? 0} of ${r.batches_target ?? 0}` },
    { key: 'velocity_score', header: 'Velocity score', render: (r: any) => String(r.velocity_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured at', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const currentCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'velocity_score', header: 'Velocity score', render: (r: any) => String(r.velocity_score ?? 0) },
    { key: 'ships_actual', header: 'Ships actual', render: (r: any) => String(r.ships_actual ?? 0) },
    { key: 'ships_target', header: 'Ships target', render: (r: any) => String(r.ships_target ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action type', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700 }}>Founder Burndown Velocity</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Track quarterly velocity. Compare ships and batches against target. Status flags on track, ahead, behind, or concerning.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Current quarter snapshot</h2>
        <DataTable rows={current} columns={currentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All velocity captures</h2>
        <DataTable rows={velocities} columns={velocityCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent velocity actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
