import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderGoNoGoLaunchTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    launchesRes,
    depsRes,
    blockedRes,
    riskRes,
    upcomingRes,
    ownerLoadRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_launches_r2437'),
    supabase.rpc('list_dependencies_r2437'),
    supabase.rpc('blocked_focus_r2437'),
    supabase.rpc('at_risk_summary_r2437'),
    supabase.rpc('upcoming_launches_r2437'),
    supabase.rpc('dependency_owner_load_r2437'),
    supabase.rpc('launch_status_funnel_r2437'),
  ]);

  const launches = (launchesRes.data ?? []) as any[];
  const deps = (depsRes.data ?? []) as any[];
  const blocked = (blockedRes.data ?? []) as any[];
  const risk = (riskRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');
  const fmtDateTime = (v: any) => (v ? new Date(v).toLocaleString() : '—');
  const fmtNum = (v: any) => (v === null || v === undefined ? '—' : String(v));

  const launchCols: Column<any>[] = [
    { key: 'launch_name', header: 'Launch', render: (r: any) => r.launch_name },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'risk_level', header: 'Risk', render: (r: any) => r.risk_level },
    { key: 'planned_launch_at', header: 'Planned', render: (r: any) => fmtDate(r.planned_launch_at) },
    { key: 'actual_launch_at', header: 'Actual', render: (r: any) => fmtDate(r.actual_launch_at) },
    { key: 'open_deps', header: 'Open deps', render: (r: any) => fmtNum(r.open_deps) },
    { key: 'blocked_deps', header: 'Blocked deps', render: (r: any) => fmtNum(r.blocked_deps) },
    { key: 'total_deps', header: 'Total deps', render: (r: any) => fmtNum(r.total_deps) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const depCols: Column<any>[] = [
    { key: 'launch_name', header: 'Launch', render: (r: any) => r.launch_name },
    { key: 'dependency_name', header: 'Dependency', render: (r: any) => r.dependency_name },
    { key: 'dependency_kind', header: 'Kind', render: (r: any) => r.dependency_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'days_to_due', header: 'Days to due', render: (r: any) => fmtNum(r.days_to_due) },
    { key: 'last_update_at', header: 'Last update', render: (r: any) => fmtDateTime(r.last_update_at) },
    { key: 'blocker_notes', header: 'Blocker', render: (r: any) => r.blocker_notes ?? '—' },
  ];

  const blockedCols: Column<any>[] = [
    { key: 'launch_name', header: 'Launch', render: (r: any) => r.launch_name },
    { key: 'risk_level', header: 'Risk', render: (r: any) => r.risk_level },
    { key: 'planned_launch_at', header: 'Planned', render: (r: any) => fmtDate(r.planned_launch_at) },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => fmtNum(r.blocked_count) },
    { key: 'blockers', header: 'Blockers', render: (r: any) => r.blockers ?? '—' },
  ];

  const riskCols: Column<any>[] = [
    { key: 'risk_level', header: 'Risk', render: (r: any) => r.risk_level },
    { key: 'launches', header: 'Launches', render: (r: any) => fmtNum(r.launches) },
    { key: 'next_launch_in_days', header: 'Next launch (days)', render: (r: any) => fmtNum(r.next_launch_in_days) },
    { key: 'earliest_planned', header: 'Earliest planned', render: (r: any) => fmtDate(r.earliest_planned) },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'launch_name', header: 'Launch', render: (r: any) => r.launch_name },
    { key: 'planned_launch_at', header: 'Planned', render: (r: any) => fmtDate(r.planned_launch_at) },
    { key: 'days_to_launch', header: 'Days to launch', render: (r: any) => fmtNum(r.days_to_launch) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'risk_level', header: 'Risk', render: (r: any) => r.risk_level },
    { key: 'open_deps', header: 'Open deps', render: (r: any) => fmtNum(r.open_deps) },
    { key: 'blocked_deps', header: 'Blocked deps', render: (r: any) => fmtNum(r.blocked_deps) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'total_deps', header: 'Total', render: (r: any) => fmtNum(r.total_deps) },
    { key: 'open_or_progress', header: 'Open/in-progress', render: (r: any) => fmtNum(r.open_or_progress) },
    { key: 'blocked', header: 'Blocked', render: (r: any) => fmtNum(r.blocked) },
    { key: 'done', header: 'Done', render: (r: any) => fmtNum(r.done) },
    { key: 'next_due_at', header: 'Next due', render: (r: any) => fmtDate(r.next_due_at) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'launches', header: 'Launches', render: (r: any) => fmtNum(r.launches) },
    { key: 'pct', header: 'Share %', render: (r: any) => fmtNum(r.pct) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Go/No-Go Launch Tracker</h1>
        <p className="text-sm text-gray-600">
          Launches with scope, risk, dependencies, ready vs blocked, go/no-go criteria, and launch dates.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Launches</h2>
        <DataTable
          rows={launches}
          columns={launchCols}
          emptyMessage="No launches tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming launches</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming launches."
          rowKey={(r: any, i: number) => String(r.launch_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blocked focus</h2>
        <DataTable
          rows={blocked}
          columns={blockedCols}
          emptyMessage="No blocked dependencies."
          rowKey={(r: any, i: number) => String(r.launch_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Risk summary (active launches)</h2>
        <DataTable
          rows={risk}
          columns={riskCols}
          emptyMessage="No active launches."
          rowKey={(r: any, i: number) => String(r.risk_level ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No launches."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dependency owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No dependencies."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All dependencies</h2>
        <DataTable
          rows={deps}
          columns={depCols}
          emptyMessage="No dependencies tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
