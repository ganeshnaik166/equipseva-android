import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TaskRow = {
  id: string;
  chain_name: string;
  ramp_stage: string;
  task_name: string;
  owner_email: string | null;
  due_at: string | null;
  status: string;
  blocker_kind: string;
  blocker_notes: string | null;
  notes: string | null;
  created_at: string;
};

type ArrRow = {
  id: string;
  chain_name: string;
  snapshot_date: string;
  current_ramp_stage: string;
  days_in_ramp: number;
  expected_arr_rupees: number;
  blocked_tasks_count: number;
  on_track: boolean;
  top_blocker_notes: string | null;
  owner_email: string | null;
  notes: string | null;
};

type StageRow = {
  ramp_stage: string;
  task_count: number;
  blocked_count: number;
  done_count: number;
};

type StuckRow = {
  chain_name: string;
  current_ramp_stage: string;
  days_in_ramp: number;
  expected_arr_rupees: number;
  blocked_tasks_count: number;
  on_track: boolean;
  top_blocker_notes: string | null;
};

type BlockerRow = {
  blocker_kind: string;
  task_count: number;
  blocked_arr_rupees: number;
};

type OwnerRow = {
  owner_email: string;
  open_count: number;
  in_progress_count: number;
  blocked_count: number;
  done_count: number;
};

type WeeklyRow = {
  week_start: string;
  created_count: number;
  done_count: number;
  blocked_count: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (!n) return '0';
  if (n >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [tasksRes, arrRes, stageRes, stuckRes, blockerRes, ownerRes, weeklyRes] = await Promise.all([
    sb.rpc('list_tasks_r2443'),
    sb.rpc('list_arr_at_stake_r2443'),
    sb.rpc('stage_distribution_r2443'),
    sb.rpc('top_stuck_chains_r2443'),
    sb.rpc('blocker_breakdown_r2443'),
    sb.rpc('owner_load_r2443'),
    sb.rpc('weekly_progress_r2443'),
  ]);

  const tasks: TaskRow[] = (tasksRes.data as TaskRow[] | null) ?? [];
  const arrRows: ArrRow[] = (arrRes.data as ArrRow[] | null) ?? [];
  const stages: StageRow[] = (stageRes.data as StageRow[] | null) ?? [];
  const stuck: StuckRow[] = (stuckRes.data as StuckRow[] | null) ?? [];
  const blockers: BlockerRow[] = (blockerRes.data as BlockerRow[] | null) ?? [];
  const owners: OwnerRow[] = (ownerRes.data as OwnerRow[] | null) ?? [];
  const weekly: WeeklyRow[] = (weeklyRes.data as WeeklyRow[] | null) ?? [];

  const totalArrAtRisk = arrRows
    .filter((r) => !r.on_track)
    .reduce((acc, r) => acc + (r.expected_arr_rupees ?? 0), 0);
  const totalArrTracked = arrRows.reduce((acc, r) => acc + (r.expected_arr_rupees ?? 0), 0);
  const blockedTasksTotal = tasks.filter((t) => t.status === 'blocked').length;

  const taskCols: Column<TaskRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'ramp_stage', header: 'Stage', render: (r: any) => r.ramp_stage },
    { key: 'task_name', header: 'Task', render: (r: any) => r.task_name },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    {
      key: 'due_at',
      header: 'Due',
      render: (r: any) => (r.due_at ? new Date(r.due_at).toLocaleDateString('en-IN') : '—'),
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'blocker_kind', header: 'Blocker', render: (r: any) => r.blocker_kind },
    { key: 'blocker_notes', header: 'Blocker notes', render: (r: any) => r.blocker_notes ?? '—' },
  ];

  const arrCols: Column<ArrRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'snapshot_date', header: 'As of', render: (r: any) => r.snapshot_date },
    { key: 'current_ramp_stage', header: 'Stage', render: (r: any) => r.current_ramp_stage },
    { key: 'days_in_ramp', header: 'Days in ramp', render: (r: any) => r.days_in_ramp },
    {
      key: 'expected_arr_rupees',
      header: 'Expected ARR',
      render: (r: any) => fmtRupees(r.expected_arr_rupees),
    },
    { key: 'blocked_tasks_count', header: 'Blocked tasks', render: (r: any) => r.blocked_tasks_count },
    {
      key: 'on_track',
      header: 'On track',
      render: (r: any) => (r.on_track ? 'yes' : 'NO'),
    },
    {
      key: 'top_blocker_notes',
      header: 'Top blocker',
      render: (r: any) => r.top_blocker_notes ?? '—',
    },
  ];

  const stageCols: Column<StageRow>[] = [
    { key: 'ramp_stage', header: 'Stage', render: (r: any) => r.ramp_stage },
    { key: 'task_count', header: 'Tasks', render: (r: any) => r.task_count },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => r.blocked_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
  ];

  const stuckCols: Column<StuckRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'current_ramp_stage', header: 'Stage', render: (r: any) => r.current_ramp_stage },
    { key: 'days_in_ramp', header: 'Days stuck', render: (r: any) => r.days_in_ramp },
    {
      key: 'expected_arr_rupees',
      header: 'ARR at risk',
      render: (r: any) => fmtRupees(r.expected_arr_rupees),
    },
    { key: 'blocked_tasks_count', header: 'Blocked tasks', render: (r: any) => r.blocked_tasks_count },
    {
      key: 'top_blocker_notes',
      header: 'Top blocker',
      render: (r: any) => r.top_blocker_notes ?? '—',
    },
  ];

  const blockerCols: Column<BlockerRow>[] = [
    { key: 'blocker_kind', header: 'Blocker kind', render: (r: any) => r.blocker_kind },
    { key: 'task_count', header: 'Tasks', render: (r: any) => r.task_count },
    {
      key: 'blocked_arr_rupees',
      header: 'ARR exposure',
      render: (r: any) => fmtRupees(r.blocked_arr_rupees),
    },
  ];

  const ownerCols: Column<OwnerRow>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'in_progress_count', header: 'In progress', render: (r: any) => r.in_progress_count },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => r.blocked_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
  ];

  const weeklyCols: Column<WeeklyRow>[] = [
    { key: 'week_start', header: 'Week starting', render: (r: any) => r.week_start },
    { key: 'created_count', header: 'Created', render: (r: any) => r.created_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => r.blocked_count },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Chain Onboarding Runway Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Multi-site chain ramp tasks across legal &rarr; training &rarr; equipment audit &rarr; integration &rarr; go-live,
        with the ARR at stake from chains stuck mid-ramp.
      </p>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '12px',
          marginBottom: '24px',
        }}
      >
        <div style={{ padding: '14px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>ARR at risk</div>
          <div style={{ fontSize: '22px', fontWeight: 700, color: '#b91c1c' }}>{fmtRupees(totalArrAtRisk)}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total ARR tracked</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{fmtRupees(totalArrTracked)}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Chains tracked</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{arrRows.length}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Blocked tasks</div>
          <div style={{ fontSize: '22px', fontWeight: 700, color: '#b45309' }}>{blockedTasksTotal}</div>
        </div>
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>Top stuck chains (ARR at risk)</h2>
        <DataTable
          rows={stuck}
          columns={stuckCols}
          emptyMessage="No stuck chains — all on track"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>ARR-at-stake snapshots</h2>
        <DataTable
          rows={arrRows}
          columns={arrCols}
          emptyMessage="No snapshots recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>Stage distribution</h2>
        <DataTable
          rows={stages}
          columns={stageCols}
          emptyMessage="No ramp tasks yet"
          rowKey={(r: any, i: number) => String(r.ramp_stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>Blocker breakdown</h2>
        <DataTable
          rows={blockers}
          columns={blockerCols}
          emptyMessage="No blockers — ramp is clean"
          rowKey={(r: any, i: number) => String(r.blocker_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>Owner load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owners assigned"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>Weekly progress (last 12 weeks)</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No task activity yet"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>All ramp tasks</h2>
        <DataTable
          rows={tasks}
          columns={taskCols}
          emptyMessage="No tasks recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
