import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [sessionsRes, actionsRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_hospital_qbr_sessions_r2215', { p_limit: 100 }),
    sb.rpc('recent_actions_hospital_qbr_r2215', { p_limit: 50 }),
    sb.rpc('top_hospital_qbr_completion_r2215', { p_limit: 10 }),
    sb.rpc('aggregate_hospital_qbr_r2215'),
  ]);

  const sessions = (sessionsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const agg = (aggRes.data?.[0] ?? {}) as any;

  const sessionCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'scheduled_at', header: 'Scheduled', render: (r: any) => r.scheduled_at ? new Date(r.scheduled_at).toLocaleString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'agenda', header: 'Agenda', render: (r: any) => `${r.agenda_completed ?? 0}/${r.agenda_total ?? 0}` },
    { key: 'actions', header: 'Action items', render: (r: any) => `${r.action_items_closed ?? 0}/${r.action_items_total ?? 0}` },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => r.completion_pct != null ? `${Number(r.completion_pct).toFixed(1)}%` : '—' },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => r.csat_score != null ? Number(r.csat_score).toFixed(1) : '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'agenda_item', header: 'Agenda item', render: (r: any) => r.agenda_item },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ?? '—' },
    { key: 'closed_at', header: 'Closed', render: (r: any) => r.closed_at ? new Date(r.closed_at).toLocaleString() : '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'sessions_total', header: 'Sessions', render: (r: any) => r.sessions_total },
    { key: 'avg_completion_pct', header: 'Avg completion %', render: (r: any) => r.avg_completion_pct != null ? `${Number(r.avg_completion_pct).toFixed(1)}%` : '—' },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat != null ? Number(r.avg_csat).toFixed(1) : '—' },
    { key: 'last_scheduled', header: 'Last scheduled', render: (r: any) => r.last_scheduled ? new Date(r.last_scheduled).toLocaleString() : '—' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>Hospital QBR tracker</h1>
      <p style={{ color: '#555', marginTop: 4 }}>
        Quarterly business reviews — schedule, agenda, action items & completion %.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginTop: 16 }}>
        <Stat label="Sessions total" value={agg.sessions_total ?? 0} />
        <Stat label="Scheduled" value={agg.sessions_scheduled ?? 0} />
        <Stat label="Completed" value={agg.sessions_completed ?? 0} />
        <Stat label="Overdue" value={agg.sessions_overdue ?? 0} />
        <Stat label="Avg completion %" value={agg.avg_completion_pct != null ? `${Number(agg.avg_completion_pct).toFixed(1)}%` : '—'} />
        <Stat label="Avg CSAT" value={agg.avg_csat != null ? Number(agg.avg_csat).toFixed(1) : '—'} />
        <Stat label="Action items open" value={agg.action_items_open ?? 0} />
        <Stat label="Action items closed" value={agg.action_items_closed ?? 0} />
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>QBR sessions</h2>
      <DataTable columns={sessionCols} rows={sessions} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>Top hospitals by completion %</h2>
      <DataTable columns={topCols} rows={top} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24 }}>Recent action items</h2>
      <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
    </main>
  );
}

function Stat({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
