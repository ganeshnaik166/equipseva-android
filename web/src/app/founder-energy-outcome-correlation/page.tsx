import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [periodsRes, actionsRes, lowRes, recentRes] = await Promise.all([
    sb.rpc('r2162_list_periods'),
    sb.rpc('r2162_list_actions'),
    sb.rpc('r2162_low_energy'),
    sb.rpc('r2162_recent_actions', { p_days: 14 }),
  ]);

  const periods: any[] = Array.isArray(periodsRes.data) ? periodsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const lows: any[] = Array.isArray(lowRes.data) ? lowRes.data : [];
  const recents: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const periodCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'energy_level', header: 'Energy', render: (r: any) => String(r.energy_level ?? '') },
    { key: 'decisions_made', header: 'Decisions', render: (r: any) => String(r.decisions_made ?? 0) },
    { key: 'escalations_handled', header: 'Escalations', render: (r: any) => String(r.escalations_handled ?? 0) },
    { key: 'deals_closed', header: 'Deals closed', render: (r: any) => String(r.deals_closed ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 16) },
  ];

  const lowCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'energy_level', header: 'Energy', render: (r: any) => String(r.energy_level ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 16) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => String(r.taken_at ?? '').slice(0, 16) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => String(r.taken_at ?? '').slice(0, 16) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Energy Outcome Correlation</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track how founder energy correlates with decisions, escalations, and deals closed across periods.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Periods</h2>
        <DataTable rows={periods} columns={periodCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Low Energy Periods (energy at or below 4)</h2>
        <DataTable rows={lows} columns={lowCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions (last 14 days)</h2>
        <DataTable rows={recents} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
