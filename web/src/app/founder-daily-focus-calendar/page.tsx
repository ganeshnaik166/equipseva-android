import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [focusRes, statusRes, weeklyRes, actionsRes] = await Promise.all([
    sb.rpc('list_focus_r2209'),
    sb.rpc('top_focus_status_r2209'),
    sb.rpc('aggregate_or_search_r2209', { p_days: 60 }),
    sb.rpc('recent_actions_r2209'),
  ]);

  const focusRows: any[] = focusRes.data ?? [];
  const statusRows: any[] = statusRes.data ?? [];
  const weeklyRows: any[] = weeklyRes.data ?? [];
  const actionRows: any[] = actionsRes.data ?? [];

  const totalDays = focusRows.length;
  const completedDays = focusRows.filter((r) => r.status === 'completed').length;
  const blownDays = focusRows.filter((r) => r.status === 'blown').length;
  const completionRate = totalDays > 0 ? Math.round((completedDays / totalDays) * 100) : 0;
  const avgFocusHours =
    totalDays > 0
      ? (focusRows.reduce((s, r) => s + Number(r.focus_block_hours ?? 0), 0) / totalDays).toFixed(1)
      : '0.0';
  const peakDays = focusRows.filter((r) => r.energy_level === 'peak').length;

  const focusCols: Column<any>[] = [
    { key: 'focus_date', header: 'Date', render: (r: any) => r.focus_date },
    { key: 'theme', header: 'Theme', render: (r: any) => r.theme },
    { key: 'priority_1', header: 'P1', render: (r: any) => r.priority_1 },
    { key: 'priority_2', header: 'P2', render: (r: any) => r.priority_2 ?? '—' },
    { key: 'priority_3', header: 'P3', render: (r: any) => r.priority_3 ?? '—' },
    { key: 'energy_level', header: 'Energy', render: (r: any) => r.energy_level },
    { key: 'focus_block_hours', header: 'Hours', render: (r: any) => Number(r.focus_block_hours ?? 0).toFixed(1) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'completion_pct', header: 'Done %', render: (r: any) => (r.completion_pct ?? 0) + '%' },
    { key: 'evening_reflection', header: 'Reflection', render: (r: any) => r.evening_reflection ?? '—' },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'day_count', header: 'Days', render: (r: any) => r.day_count },
    { key: 'avg_completion', header: 'Avg Done %', render: (r: any) => r.avg_completion + '%' },
    { key: 'total_focus_hours', header: 'Total Hours', render: (r: any) => r.total_focus_hours },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'focus_week', header: 'Week', render: (r: any) => r.focus_week },
    { key: 'day_count', header: 'Days', render: (r: any) => r.day_count },
    { key: 'completed_count', header: 'Done', render: (r: any) => r.completed_count },
    { key: 'blown_count', header: 'Blown', render: (r: any) => r.blown_count },
    { key: 'avg_completion', header: 'Avg %', render: (r: any) => r.avg_completion + '%' },
    { key: 'avg_energy', header: 'Avg Energy', render: (r: any) => r.avg_energy },
    { key: 'total_hours', header: 'Hours', render: (r: any) => r.total_hours },
  ];

  const actionCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString() },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email },
    { key: 'op_name', header: 'Op', render: (r: any) => r.op_name },
    { key: 'after_value', header: 'Payload', render: (r: any) => JSON.stringify(r.after_value) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Founder Daily Focus Calendar
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Daily theme & top 3 priorities · evening reflection · pattern analysis · r2209
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Days Planned</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalDays}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Completion Rate</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{completionRate}%</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Blown Days</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#b91c1c' }}>{blownDays}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Avg Focus Hours</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{avgFocusHours}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Peak Energy Days</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#047857' }}>{peakDays}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Daily Focus Blocks</h2>
        <DataTable
          columns={focusCols}
          rows={focusRows}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Breakdown</h2>
        <DataTable
          columns={statusCols}
          rows={statusRows}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly Pattern (last 60 days)</h2>
        <DataTable
          columns={weeklyCols}
          rows={weeklyRows}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable
          columns={actionCols}
          rows={actionRows}
          rowKey={(_, i) => String(i)}
        />
      </section>
    </main>
  );
}
