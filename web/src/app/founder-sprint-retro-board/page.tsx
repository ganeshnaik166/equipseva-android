import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Retro = {
  id: string;
  sprint_label: string;
  sprint_start: string;
  sprint_end: string;
  founder_score: number | null;
  status: string;
  closed_at: string | null;
  action_count: number;
  open_action_count: number;
  created_at: string;
};

type Action = {
  id: string;
  retro_id: string;
  sprint_label: string;
  action_text: string;
  owner_email: string | null;
  due_date: string | null;
  status: string;
  completed_at: string | null;
  created_at: string;
};

type Theme = {
  sprint_label: string;
  sprint_end: string;
  founder_score: number | null;
  status: string;
  what_worked_excerpt: string | null;
  what_didnt_excerpt: string | null;
  next_focus_excerpt: string | null;
  open_action_count: number;
};

type Stats = {
  total_retros: number;
  closed_retros: number;
  active_retros: number;
  avg_score: number | null;
  last_score: number | null;
  best_score: number | null;
  worst_score: number | null;
  total_actions: number;
  open_actions: number;
  done_actions: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [retrosRes, actionsRes, themesRes, statsRes] = await Promise.all([
    sb.rpc('list_retros_r1806'),
    sb.rpc('list_actions_r1806', { p_retro_id: null }),
    sb.rpc('recent_themes_r1806'),
    sb.rpc('average_sprint_score_r1806'),
  ]);

  const retros: Retro[] = (retrosRes.data as Retro[]) ?? [];
  const actions: Action[] = (actionsRes.data as Action[]) ?? [];
  const themes: Theme[] = (themesRes.data as Theme[]) ?? [];
  const statsRow: Stats | null = Array.isArray(statsRes.data)
    ? ((statsRes.data[0] as Stats) ?? null)
    : ((statsRes.data as Stats) ?? null);

  const retroCols: Column<Retro>[] = [
    { key: 'sprint_label', header: 'Sprint', render: (r: any) => r.sprint_label },
    { key: 'sprint_start', header: 'Start', render: (r: any) => r.sprint_start },
    { key: 'sprint_end', header: 'End', render: (r: any) => r.sprint_end },
    { key: 'founder_score', header: 'Score', render: (r: any) => (r.founder_score == null ? '—' : `${r.founder_score} / 10`) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'action_count', header: 'Actions', render: (r: any) => String(r.action_count ?? 0) },
    { key: 'open_action_count', header: 'Open', render: (r: any) => String(r.open_action_count ?? 0) },
    { key: 'closed_at', header: 'Closed at', render: (r: any) => (r.closed_at ? new Date(r.closed_at).toLocaleString() : '—') },
  ];

  const actionCols: Column<Action>[] = [
    { key: 'sprint_label', header: 'Sprint', render: (r: any) => r.sprint_label },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'completed_at', header: 'Completed', render: (r: any) => (r.completed_at ? new Date(r.completed_at).toLocaleString() : '—') },
    { key: 'created_at', header: 'Logged', render: (r: any) => new Date(r.created_at).toLocaleString() },
  ];

  const themeCols: Column<Theme>[] = [
    { key: 'sprint_label', header: 'Sprint', render: (r: any) => r.sprint_label },
    { key: 'sprint_end', header: 'End', render: (r: any) => r.sprint_end },
    { key: 'founder_score', header: 'Score', render: (r: any) => (r.founder_score == null ? '—' : `${r.founder_score} / 10`) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'what_worked_excerpt', header: 'What worked', render: (r: any) => r.what_worked_excerpt || '—' },
    { key: 'what_didnt_excerpt', header: 'What did not', render: (r: any) => r.what_didnt_excerpt || '—' },
    { key: 'next_focus_excerpt', header: 'Next focus', render: (r: any) => r.next_focus_excerpt || '—' },
    { key: 'open_action_count', header: 'Open actions', render: (r: any) => String(r.open_action_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Sprint Retro Board</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Sprint retros: what worked, what did not, what comes next. Score every sprint 1–10 and track follow-up actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Sprint score summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <Stat label="Total retros" value={statsRow?.total_retros ?? 0} />
          <Stat label="Active" value={statsRow?.active_retros ?? 0} />
          <Stat label="Closed" value={statsRow?.closed_retros ?? 0} />
          <Stat label="Avg score" value={statsRow?.avg_score == null ? '—' : Number(statsRow.avg_score).toFixed(2)} />
          <Stat label="Last score" value={statsRow?.last_score == null ? '—' : `${statsRow.last_score} / 10`} />
          <Stat label="Best score" value={statsRow?.best_score == null ? '—' : `${statsRow.best_score} / 10`} />
          <Stat label="Worst score" value={statsRow?.worst_score == null ? '—' : `${statsRow.worst_score} / 10`} />
          <Stat label="Open actions" value={statsRow?.open_actions ?? 0} />
          <Stat label="Done actions" value={statsRow?.done_actions ?? 0} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent themes (last 6 sprints)</h2>
        <DataTable rows={themes} columns={themeCols} rowKey={(r: any, i: number) => String(r.sprint_label ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All retros</h2>
        <DataTable rows={retros} columns={retroCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Follow-up actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
