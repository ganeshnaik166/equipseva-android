import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Daily = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  day: string;
  drive_hours: number;
  repair_hours: number;
  admin_hours: number;
  wait_hours: number;
  idle_hours: number;
  training_hours: number;
  billable_hours: number;
  non_billable_pct: number;
  notes: string;
  created_at: string;
};

type Insight = {
  id: string;
  insight_kind: string;
  observed_engineer_user_id: string;
  engineer_email: string | null;
  period_start: string;
  period_end: string;
  observed_pct: number;
  target_pct: number;
  action_md: string;
  owner_email: string;
  status: string;
  notes: string;
};

type NonBillable = {
  engineer_user_id: string;
  engineer_email: string | null;
  days_logged: number;
  avg_non_billable_pct: number;
  total_idle_hours: number;
  total_wait_hours: number;
};

type Trend = {
  week_start: string;
  total_drive_hours: number;
  total_repair_hours: number;
  drive_share_pct: number;
  days_logged: number;
};

type Summary = {
  days_logged: number;
  total_billable_hours: number;
  total_non_billable_hours: number;
  avg_non_billable_pct: number;
  worst_day: string | null;
  worst_day_pct: number;
};

type Heatmap = {
  engineer_user_id: string;
  engineer_email: string | null;
  drive_pct: number;
  repair_pct: number;
  admin_pct: number;
  wait_pct: number;
  idle_pct: number;
  training_pct: number;
};

type IdleFocus = {
  engineer_user_id: string;
  engineer_email: string | null;
  day: string;
  idle_hours: number;
  wait_hours: number;
  non_billable_pct: number;
  notes: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [dailyRes, insightsRes, nonBillRes, trendRes, summaryRes, heatmapRes, idleRes] = await Promise.all([
    sb.rpc('list_time_distribution_r2498'),
    sb.rpc('list_insights_r2498'),
    sb.rpc('top_non_billable_engineers_r2498'),
    sb.rpc('weekly_drive_trend_r2498'),
    sb.rpc('billable_vs_non_billable_summary_r2498'),
    sb.rpc('engineer_distribution_heatmap_r2498'),
    sb.rpc('top_idle_focus_r2498'),
  ]);

  const daily: Daily[] = (dailyRes.data ?? []) as Daily[];
  const insights: Insight[] = (insightsRes.data ?? []) as Insight[];
  const nonBill: NonBillable[] = (nonBillRes.data ?? []) as NonBillable[];
  const trend: Trend[] = (trendRes.data ?? []) as Trend[];
  const summary: Summary = ((summaryRes.data ?? [])[0] ?? {
    days_logged: 0,
    total_billable_hours: 0,
    total_non_billable_hours: 0,
    avg_non_billable_pct: 0,
    worst_day: null,
    worst_day_pct: 0,
  }) as Summary;
  const heatmap: Heatmap[] = (heatmapRes.data ?? []) as Heatmap[];
  const idle: IdleFocus[] = (idleRes.data ?? []) as IdleFocus[];

  const dailyCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r: any) => new Date(r.day).toLocaleDateString() },
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'drive', header: 'Drive h', render: (r: any) => String(r.drive_hours) },
    { key: 'repair', header: 'Repair h', render: (r: any) => String(r.repair_hours) },
    { key: 'admin', header: 'Admin h', render: (r: any) => String(r.admin_hours) },
    { key: 'wait', header: 'Wait h', render: (r: any) => String(r.wait_hours) },
    { key: 'idle', header: 'Idle h', render: (r: any) => String(r.idle_hours) },
    { key: 'training', header: 'Training h', render: (r: any) => String(r.training_hours) },
    { key: 'billable', header: 'Billable h', render: (r: any) => String(r.billable_hours) },
    { key: 'nbpct', header: 'Non-billable %', render: (r: any) => `${r.non_billable_pct}%` },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes || '—' },
  ];

  const insightCols: Column<any>[] = [
    { key: 'kind', header: 'Kind', render: (r: any) => r.insight_kind },
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.observed_engineer_user_id).slice(0, 8) },
    { key: 'period', header: 'Period', render: (r: any) => `${new Date(r.period_start).toLocaleDateString()} → ${new Date(r.period_end).toLocaleDateString()}` },
    { key: 'observed', header: 'Observed %', render: (r: any) => `${r.observed_pct}%` },
    { key: 'target', header: 'Target %', render: (r: any) => `${r.target_pct}%` },
    { key: 'action', header: 'Action', render: (r: any) => r.action_md || '—' },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email || '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const nonBillCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'days', header: 'Days', render: (r: any) => String(r.days_logged) },
    { key: 'avgnb', header: 'Avg non-billable %', render: (r: any) => `${r.avg_non_billable_pct}%` },
    { key: 'idle', header: 'Idle h total', render: (r: any) => String(r.total_idle_hours) },
    { key: 'wait', header: 'Wait h total', render: (r: any) => String(r.total_wait_hours) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week', header: 'Week start', render: (r: any) => new Date(r.week_start).toLocaleDateString() },
    { key: 'drive', header: 'Drive h', render: (r: any) => String(r.total_drive_hours) },
    { key: 'repair', header: 'Repair h', render: (r: any) => String(r.total_repair_hours) },
    { key: 'share', header: 'Drive share %', render: (r: any) => `${r.drive_share_pct}%` },
    { key: 'days', header: 'Days logged', render: (r: any) => String(r.days_logged) },
  ];

  const heatmapCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'drive', header: 'Drive %', render: (r: any) => `${r.drive_pct}%` },
    { key: 'repair', header: 'Repair %', render: (r: any) => `${r.repair_pct}%` },
    { key: 'admin', header: 'Admin %', render: (r: any) => `${r.admin_pct}%` },
    { key: 'wait', header: 'Wait %', render: (r: any) => `${r.wait_pct}%` },
    { key: 'idle', header: 'Idle %', render: (r: any) => `${r.idle_pct}%` },
    { key: 'training', header: 'Training %', render: (r: any) => `${r.training_pct}%` },
  ];

  const idleCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r: any) => new Date(r.day).toLocaleDateString() },
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'idle', header: 'Idle h', render: (r: any) => String(r.idle_hours) },
    { key: 'wait', header: 'Wait h', render: (r: any) => String(r.wait_hours) },
    { key: 'nbpct', header: 'Non-billable %', render: (r: any) => `${r.non_billable_pct}%` },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes || '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Time-on-Task Distribution</h1>
        <p className="text-sm text-gray-500">r2498 · per-day hours coded as drive / repair / admin / wait / idle / training & non-billable %</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Days logged</div>
          <div className="text-2xl font-semibold">{summary.days_logged}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Billable hours</div>
          <div className="text-2xl font-semibold text-green-600">{summary.total_billable_hours}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Non-billable hours</div>
          <div className="text-2xl font-semibold text-amber-600">{summary.total_non_billable_hours}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg non-billable %</div>
          <div className="text-2xl font-semibold">{summary.avg_non_billable_pct}%</div>
        </div>
        <div className="rounded-lg border p-4 md:col-span-2">
          <div className="text-xs uppercase text-gray-500">Worst day</div>
          <div className="text-lg font-semibold">
            {summary.worst_day ? `${new Date(summary.worst_day).toLocaleDateString()} — ${summary.worst_day_pct}% non-billable` : '—'}
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Daily time on task</h2>
        <DataTable
          rows={daily}
          columns={dailyCols}
          emptyMessage="No daily logs yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Insights & actions</h2>
        <DataTable
          rows={insights}
          columns={insightCols}
          emptyMessage="No insights yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top non-billable engineers</h2>
        <DataTable
          rows={nonBill}
          columns={nonBillCols}
          emptyMessage="No engineers logged"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly drive trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No weeks yet"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer distribution heatmap (% of total hours)</h2>
        <DataTable
          rows={heatmap}
          columns={heatmapCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top idle / wait focus</h2>
        <DataTable
          rows={idle}
          columns={idleCols}
          emptyMessage="No idle/wait days"
          rowKey={(r: any, i: number) => String((r.engineer_user_id ?? '') + (r.day ?? '') + i)}
        />
      </section>
    </main>
  );
}
