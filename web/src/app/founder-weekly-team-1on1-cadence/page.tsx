import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    listRes,
    overdueRes,
    gapRes,
    actionsRes,
    completionRes,
    cadenceRes,
    weekRes,
  ] = await Promise.all([
    sb.rpc('list_one_on_ones_r2417'),
    sb.rpc('overdue_one_on_ones_r2417'),
    sb.rpc('gap_distribution_r2417'),
    sb.rpc('top_open_actions_r2417'),
    sb.rpc('action_completion_rate_r2417'),
    sb.rpc('team_member_cadence_r2417'),
    sb.rpc('this_week_schedule_r2417'),
  ]);

  const list = (listRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const gap = (gapRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const completion = (completionRes.data ?? []) as any[];
  const cadence = (cadenceRes.data ?? []) as any[];
  const week = (weekRes.data ?? []) as any[];

  const completionRow = completion[0] ?? {};

  const listCols: Column<any>[] = [
    { key: 'team_member_email', header: 'Member', render: (r: any) => r.team_member_email },
    { key: 'team_member_role', header: 'Role', render: (r: any) => r.team_member_role },
    { key: 'scheduled_at', header: 'Scheduled', render: (r: any) => r.scheduled_at ? new Date(r.scheduled_at).toLocaleString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'duration_minutes', header: 'Duration (min)', render: (r: any) => r.duration_minutes ?? '-' },
    { key: 'gap_days_since_last', header: 'Gap days', render: (r: any) => r.gap_days_since_last ?? '-' },
    { key: 'open_actions', header: 'Open actions', render: (r: any) => `${r.open_actions} / ${r.total_actions}` },
    { key: 'key_topics', header: 'Topics', render: (r: any) => Array.isArray(r.key_topics) ? r.key_topics.join(', ') : '-' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'team_member_email', header: 'Member', render: (r: any) => r.team_member_email },
    { key: 'team_member_role', header: 'Role', render: (r: any) => r.team_member_role },
    { key: 'last_held_on', header: 'Last held', render: (r: any) => r.last_held_on ? new Date(r.last_held_on).toLocaleDateString() : 'never' },
    { key: 'days_since_last', header: 'Days since', render: (r: any) => r.days_since_last ?? '-' },
    { key: 'next_scheduled_at', header: 'Next scheduled', render: (r: any) => r.next_scheduled_at ? new Date(r.next_scheduled_at).toLocaleString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const gapCols: Column<any>[] = [
    { key: 'bucket', header: 'Gap bucket', render: (r: any) => r.bucket },
    { key: 'count', header: 'Count', render: (r: any) => r.count },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '-' },
    { key: 'days_until_due', header: 'Days until due', render: (r: any) => r.days_until_due ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'team_member_email', header: '1:1 with', render: (r: any) => r.team_member_email },
  ];

  const cadenceCols: Column<any>[] = [
    { key: 'team_member_email', header: 'Member', render: (r: any) => r.team_member_email },
    { key: 'team_member_role', header: 'Role', render: (r: any) => r.team_member_role },
    { key: 'total_one_on_ones', header: 'Total', render: (r: any) => r.total_one_on_ones },
    { key: 'held_count', header: 'Held', render: (r: any) => r.held_count },
    { key: 'cancelled_count', header: 'Cancelled', render: (r: any) => r.cancelled_count },
    { key: 'no_show_count', header: 'No-show', render: (r: any) => r.no_show_count },
    { key: 'avg_gap_days', header: 'Avg gap (d)', render: (r: any) => r.avg_gap_days ?? '-' },
    { key: 'last_held_on', header: 'Last held', render: (r: any) => r.last_held_on ? new Date(r.last_held_on).toLocaleDateString() : '-' },
  ];

  const weekCols: Column<any>[] = [
    { key: 'team_member_email', header: 'Member', render: (r: any) => r.team_member_email },
    { key: 'team_member_role', header: 'Role', render: (r: any) => r.team_member_role },
    { key: 'scheduled_at', header: 'Scheduled', render: (r: any) => new Date(r.scheduled_at).toLocaleString() },
    { key: 'days_from_now', header: 'Days from now', render: (r: any) => r.days_from_now },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'agenda_md', header: 'Agenda', render: (r: any) => r.agenda_md ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Weekly Team 1:1 Cadence
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track 1:1 meetings, gap days, topics covered, and pending action items across the team.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Action item completion</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px' }}>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#888' }}>Total</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{completionRow.total_actions ?? 0}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#888' }}>Done</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{completionRow.done_count ?? 0}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#888' }}>Open</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{completionRow.open_count ?? 0}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#888' }}>In progress</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{completionRow.in_progress_count ?? 0}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#888' }}>Completion %</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{completionRow.completion_pct ?? 0}%</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>This week schedule</h2>
        <DataTable
          rows={week}
          columns={weekCols}
          emptyMessage="No 1:1s scheduled in the next 7 days."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Overdue 1:1s (gap > 14 days)</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue 1:1s. Cadence on track."
          rowKey={(r: any, i: number) => String(r.team_member_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top open action items</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No open action items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Gap distribution (held 1:1s)</h2>
        <DataTable
          rows={gap}
          columns={gapCols}
          emptyMessage="No held 1:1s yet."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Per-member cadence summary</h2>
        <DataTable
          rows={cadence}
          columns={cadenceCols}
          emptyMessage="No team members tracked."
          rowKey={(r: any, i: number) => String(r.team_member_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All 1:1 sessions</h2>
        <DataTable
          rows={list}
          columns={listCols}
          emptyMessage="No 1:1 sessions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
