import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LogRow = {
  id: string;
  log_week: string;
  stress_score: number;
  sleep_avg_hours: number;
  workout_count: number;
  journal_md: string | null;
  recorded_at: string;
  action_count: number;
  action_done_count: number;
};

type ActionRow = {
  id: string;
  log_id: string;
  log_week: string;
  action_text: string;
  planned_for: string;
  status: string;
  done_at: string | null;
  created_at: string;
};

type Summary = {
  weeks_logged: number | null;
  avg_stress_4w: number | null;
  avg_sleep_4w: number | null;
  total_workouts_4w: number | null;
  open_actions: number | null;
  overdue_actions: number | null;
  done_actions_4w: number | null;
  latest_week: string | null;
  latest_stress: number | null;
};

type TrendRow = {
  log_week: string;
  stress_score: number;
  sleep_avg_hours: number;
  workout_count: number;
};

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return String(s);
  }
}

function stressBadge(score: number) {
  let bg = '#dcfce7';
  let fg = '#166534';
  let label = 'low';
  if (score >= 8) {
    bg = '#fee2e2';
    fg = '#991b1b';
    label = 'high';
  } else if (score >= 5) {
    bg = '#fef3c7';
    fg = '#854d0e';
    label = 'med';
  }
  return (
    <span style={{ background: bg, color: fg, padding: '2px 8px', borderRadius: 6, fontSize: 12, fontWeight: 600 }}>
      {score}/10 {label}
    </span>
  );
}

function statusBadge(status: string) {
  const m: Record<string, { bg: string; fg: string }> = {
    planned: { bg: '#dbeafe', fg: '#1e3a8a' },
    done: { bg: '#dcfce7', fg: '#166534' },
    skipped: { bg: '#f3f4f6', fg: '#4b5563' },
  };
  const c = m[status] ?? { bg: '#f3f4f6', fg: '#374151' };
  return (
    <span style={{ background: c.bg, color: c.fg, padding: '2px 8px', borderRadius: 6, fontSize: 12, fontWeight: 600 }}>
      {status}
    </span>
  );
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [logsRes, actionsRes, summaryRes, trendRes] = await Promise.all([
    sb.rpc('r1686_list_logs', { p_limit: 26 }),
    sb.rpc('r1686_list_actions', { p_status: null, p_limit: 100 }),
    sb.rpc('r1686_recent_summary'),
    sb.rpc('r1686_stress_trend_12w'),
  ]);

  const logs: LogRow[] = (logsRes.data as LogRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const summaryArr = (summaryRes.data as Summary[]) ?? [];
  const summary: Summary = summaryArr[0] ?? {
    weeks_logged: 0,
    avg_stress_4w: null,
    avg_sleep_4w: null,
    total_workouts_4w: 0,
    open_actions: 0,
    overdue_actions: 0,
    done_actions_4w: 0,
    latest_week: null,
    latest_stress: null,
  };
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];

  const logCols: Column<LogRow>[] = [
    { key: 'log_week', header: 'Week', render: (r: any) => <span style={{ fontFamily: 'monospace' }}>{fmtDate(r.log_week)}</span> },
    { key: 'stress_score', header: 'Stress', render: (r: any) => stressBadge(r.stress_score) },
    { key: 'sleep_avg_hours', header: 'Sleep avg (h)', render: (r: any) => <span>{Number(r.sleep_avg_hours).toFixed(1)}</span> },
    { key: 'workout_count', header: 'Workouts', render: (r: any) => <span>{r.workout_count}</span> },
    {
      key: 'actions',
      header: 'Actions',
      render: (r: any) => (
        <span style={{ fontSize: 12, color: '#4b5563' }}>
          {r.action_done_count}/{r.action_count} done
        </span>
      ),
    },
    {
      key: 'journal_md',
      header: 'Journal',
      render: (r: any) => (
        <span style={{ fontSize: 12, color: '#374151', maxWidth: 320, display: 'inline-block', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {r.journal_md ?? '—'}
        </span>
      ),
    },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{fmtDate(r.recorded_at)}</span> },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'planned_for', header: 'Planned for', render: (r: any) => <span style={{ fontFamily: 'monospace' }}>{fmtDate(r.planned_for)}</span> },
    { key: 'action_text', header: 'Action', render: (r: any) => <span>{r.action_text}</span> },
    { key: 'log_week', header: 'From week', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: 12, color: '#6b7280' }}>{fmtDate(r.log_week)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
    { key: 'done_at', header: 'Done at', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: 12 }}>{fmtDate(r.done_at)}</span> },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'log_week', header: 'Week', render: (r: any) => <span style={{ fontFamily: 'monospace' }}>{fmtDate(r.log_week)}</span> },
    { key: 'stress_score', header: 'Stress', render: (r: any) => stressBadge(r.stress_score) },
    { key: 'sleep_avg_hours', header: 'Sleep (h)', render: (r: any) => <span>{Number(r.sleep_avg_hours).toFixed(1)}</span> },
    { key: 'workout_count', header: 'Workouts', render: (r: any) => <span>{r.workout_count}</span> },
  ];

  const kpis = [
    { label: 'Weeks logged (4w)', value: summary.weeks_logged ?? 0 },
    { label: 'Avg stress (4w)', value: summary.avg_stress_4w != null ? `${Number(summary.avg_stress_4w).toFixed(1)}/10` : '—' },
    { label: 'Avg sleep (4w)', value: summary.avg_sleep_4w != null ? `${Number(summary.avg_sleep_4w).toFixed(1)} h` : '—' },
    { label: 'Workouts (4w)', value: summary.total_workouts_4w ?? 0 },
    { label: 'Open actions', value: summary.open_actions ?? 0 },
    { label: 'Overdue actions', value: summary.overdue_actions ?? 0 },
    { label: 'Done (4w)', value: summary.done_actions_4w ?? 0 },
    { label: 'Latest stress', value: summary.latest_stress != null ? `${summary.latest_stress}/10` : '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Founder Personal Stress Log</h1>
        <p style={{ color: '#6b7280', marginTop: 4, fontSize: 14 }}>
          Weekly stress + sleep + workout log. Track patterns and queue recovery actions when stress trends high (&gt;7).
        </p>
        {summary.latest_week ? (
          <p style={{ color: '#374151', marginTop: 6, fontSize: 13 }}>
            Latest entry: <strong>{fmtDate(summary.latest_week)}</strong>
          </p>
        ) : null}
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#111827' }}>KPIs (last 4 weeks)</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          {kpis.map((k) => (
            <div key={k.label} style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 14 }}>
              <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
              <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4, color: '#111827' }}>{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#111827' }}>Weekly log (last 26 weeks)</h2>
        <div style={{ overflowX: 'auto', background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <DataTable<LogRow> rows={logs} columns={logCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#111827' }}>Action queue</h2>
        <p style={{ fontSize: 12, color: '#6b7280', marginTop: 0, marginBottom: 8 }}>
          Recovery + reset actions linked to each week. Overdue planned actions need triage.
        </p>
        <div style={{ overflowX: 'auto', background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <DataTable<ActionRow> rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#111827' }}>12-week trend</h2>
        <div style={{ overflowX: 'auto', background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <DataTable<TrendRow> rows={trend} columns={trendCols} rowKey={(r: any, i: number) => String(r.log_week ?? i)} />
        </div>
      </section>
    </main>
  );
}
