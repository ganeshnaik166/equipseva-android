import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

export default async function FounderTeamRetroLogPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, listRes, overdueRes, openRes, scorecardRes, staleRes] = await Promise.all([
    supabase.rpc('founder_team_retro_summary'),
    supabase.rpc('founder_team_retro_list'),
    supabase.rpc('founder_team_retro_actions_overdue'),
    supabase.rpc('founder_team_retro_actions_open'),
    supabase.rpc('founder_team_retro_owner_scorecard'),
    supabase.rpc('founder_team_retro_stale'),
  ]);

  const s: any = summaryRes.data?.[0] ?? {};
  const retros: any[] = listRes.data ?? [];
  const overdue: any[] = overdueRes.data ?? [];
  const openActions: any[] = openRes.data ?? [];
  const scorecard: any[] = scorecardRes.data ?? [];
  const stale: any[] = staleRes.data ?? [];

  const fmt = (v: any) => (v === null || v === undefined ? '—' : String(v));
  const fmtPct = (v: any) => (v === null || v === undefined ? '—' : `${v}%`);
  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');

  const kpis: Kpi[] = [
    { label: 'Total Retros', value: fmt(s.total_retros) },
    { label: 'Retros Last 30d', value: fmt(s.retros_last_30d) },
    { label: 'Active Teams', value: fmt(s.active_teams) },
    { label: 'Stale Teams', value: fmt(s.stale_teams) },
    { label: 'Total Actions', value: fmt(s.total_actions) },
    { label: 'Open Actions', value: fmt(s.open_actions) },
    { label: 'Completed', value: fmt(s.completed_actions) },
    { label: 'Overdue', value: fmt(s.overdue_actions) },
    { label: 'In Progress', value: fmt(s.in_progress_actions) },
    { label: 'Completion %', value: fmtPct(s.completion_pct) },
    { label: 'Overdue %', value: fmtPct(s.overdue_pct) },
    { label: 'Avg Morale', value: fmt(s.avg_morale) },
    { label: 'Avg Attendees', value: fmt(s.avg_attendees) },
    { label: 'High Priority Open', value: fmt(s.high_priority_open) },
    { label: 'Critical Open', value: fmt(s.critical_priority_open) },
    { label: 'Unique Owners', value: fmt(s.unique_owners) },
  ];

  const retroCols: Column<any>[] = [
    { key: 'team_name', header: 'Team', render: (r: any) => fmt(r.team_name) },
    { key: 'retro_month', header: 'Month', render: (r: any) => fmtDate(r.retro_month) },
    { key: 'facilitator_email', header: 'Facilitator', render: (r: any) => fmt(r.facilitator_email) },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => fmt(r.attendee_count) },
    { key: 'morale_score', header: 'Morale', render: (r: any) => fmt(r.morale_score) },
    { key: 'total_actions', header: 'Actions', render: (r: any) => fmt(r.total_actions) },
    { key: 'completed_actions', header: 'Done', render: (r: any) => fmt(r.completed_actions) },
    { key: 'overdue_actions', header: 'Overdue', render: (r: any) => fmt(r.overdue_actions) },
    { key: 'completion_pct', header: 'Completion', render: (r: any) => fmtPct(r.completion_pct) },
    { key: 'days_since_retro', header: 'Age (d)', render: (r: any) => fmt(r.days_since_retro) },
    { key: 'is_stale', header: 'Stale', render: (r: any) => (r.is_stale ? 'Yes' : 'No') },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'team_name', header: 'Team', render: (r: any) => fmt(r.team_name) },
    { key: 'action_text', header: 'Action', render: (r: any) => fmt(r.action_text) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => fmt(r.owner_email) },
    { key: 'due_date', header: 'Due', render: (r: any) => fmtDate(r.due_date) },
    { key: 'priority', header: 'Priority', render: (r: any) => fmt(r.priority) },
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => fmt(r.days_overdue) },
  ];

  const openCols: Column<any>[] = [
    { key: 'team_name', header: 'Team', render: (r: any) => fmt(r.team_name) },
    { key: 'action_text', header: 'Action', render: (r: any) => fmt(r.action_text) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => fmt(r.owner_email) },
    { key: 'due_date', header: 'Due', render: (r: any) => fmtDate(r.due_date) },
    { key: 'priority', header: 'Priority', render: (r: any) => fmt(r.priority) },
    { key: 'status', header: 'Status', render: (r: any) => fmt(r.status) },
    { key: 'days_until_due', header: 'Days Until Due', render: (r: any) => fmt(r.days_until_due) },
  ];

  const scorecardCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => fmt(r.owner_email) },
    { key: 'total_actions', header: 'Total', render: (r: any) => fmt(r.total_actions) },
    { key: 'completed_actions', header: 'Done', render: (r: any) => fmt(r.completed_actions) },
    { key: 'in_progress_actions', header: 'WIP', render: (r: any) => fmt(r.in_progress_actions) },
    { key: 'overdue_actions', header: 'Overdue', render: (r: any) => fmt(r.overdue_actions) },
    { key: 'completion_pct', header: 'Completion', render: (r: any) => fmtPct(r.completion_pct) },
    { key: 'avg_days_to_close', header: 'Avg Days to Close', render: (r: any) => fmt(r.avg_days_to_close) },
  ];

  const staleCols: Column<any>[] = [
    { key: 'team_name', header: 'Team', render: (r: any) => fmt(r.team_name) },
    { key: 'last_retro_month', header: 'Last Retro Month', render: (r: any) => fmtDate(r.last_retro_month) },
    { key: 'last_retro_at', header: 'Last Retro At', render: (r: any) => fmtDate(r.last_retro_at) },
    { key: 'days_since_last', header: 'Days Since', render: (r: any) => fmt(r.days_since_last) },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => fmt(r.open_actions) },
    { key: 'overdue_actions', header: 'Overdue', render: (r: any) => fmt(r.overdue_actions) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Team Retro Log</h1>
        <p className="text-sm text-gray-500 mt-1">
          Monthly team retrospectives: start/stop/continue, action items, owners, due dates.
          Track completion rate, surface stale retros and overdue items.
        </p>
      </header>

      <section>
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
          {kpis.map((k) => (
            <div key={k.label} className="rounded-lg border border-gray-200 bg-white p-3">
              <div className="text-xs text-gray-500">{k.label}</div>
              <div className="text-lg font-semibold mt-1">{k.value ?? "—"}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale Teams (45+ days since last retro)</h2>
        <DataTable columns={staleCols} rows={stale} rowKey={(r: any) => r.team_name} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Action Items</h2>
        <DataTable columns={overdueCols} rows={overdue} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Action Items</h2>
        <DataTable columns={openCols} rows={openActions} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Scorecard</h2>
        <DataTable columns={scorecardCols} rows={scorecard} rowKey={(r: any) => r.owner_email} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Retro Log</h2>
        <DataTable columns={retroCols} rows={retros} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
