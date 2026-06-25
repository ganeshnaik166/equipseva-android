import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [boards, actions, insights, attendance, kinds, trend, owners] = await Promise.all([
    supabase.rpc('list_boards_r2613'),
    supabase.rpc('list_action_log_r2613'),
    supabase.rpc('top_insight_focus_r2613'),
    supabase.rpc('attendance_rate_summary_r2613'),
    supabase.rpc('action_kind_distribution_r2613'),
    supabase.rpc('monthly_board_trend_r2613'),
    supabase.rpc('owner_load_r2613'),
  ]);

  const boardRows = (boards.data ?? []) as any[];
  const actionRows = (actions.data ?? []) as any[];
  const insightRows = (insights.data ?? []) as any[];
  const attendanceRows = (attendance.data ?? []) as any[];
  const kindRows = (kinds.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const ownerRows = (owners.data ?? []) as any[];

  const boardCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'member_count', header: 'Members', render: (r: any) => r.member_count },
    { key: 'meeting_held', header: 'Held', render: (r: any) => (r.meeting_held ? 'Yes' : 'No') },
    { key: 'attendance_count', header: 'Attended', render: (r: any) => r.attendance_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'description_md', header: 'Description', render: (r: any) => r.description_md },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'target_at', header: 'Target', render: (r: any) => (r.target_at ? String(r.target_at).slice(0, 10) : '-') },
  ];

  const insightCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'focus_summary', header: 'Top Insight', render: (r: any) => r.focus_summary },
  ];

  const attendanceCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'member_count', header: 'Members', render: (r: any) => r.member_count },
    { key: 'attendance_count', header: 'Attended', render: (r: any) => r.attendance_count },
    { key: 'attendance_rate_pct', header: 'Rate %', render: (r: any) => r.attendance_rate_pct },
  ];

  const kindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'member_count', header: 'Members', render: (r: any) => r.member_count },
    { key: 'attendance_count', header: 'Attended', render: (r: any) => r.attendance_count },
    { key: 'meeting_held', header: 'Held', render: (r: any) => (r.meeting_held ? 'Yes' : 'No') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_actions', header: 'Open', render: (r: any) => r.open_actions },
    { key: 'in_progress_actions', header: 'In Progress', render: (r: any) => r.in_progress_actions },
    { key: 'done_actions', header: 'Done', render: (r: any) => r.done_actions },
  ];

  return (
    <main className="mx-auto max-w-6xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Monthly Customer Advisory Board Progress</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track monthly advisory boards, attendance, top insights & founder follow-up actions.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Boards by month</h2>
        <DataTable
          rows={boardRows}
          columns={boardCols}
          emptyMessage="No advisory boards recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Action log</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top insight per month</h2>
        <DataTable
          rows={insightRows}
          columns={insightCols}
          emptyMessage="No insights captured."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Attendance rate</h2>
        <DataTable
          rows={attendanceRows}
          columns={attendanceCols}
          emptyMessage="No attendance data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Action kind distribution</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No actions yet."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Monthly board trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Owner load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
