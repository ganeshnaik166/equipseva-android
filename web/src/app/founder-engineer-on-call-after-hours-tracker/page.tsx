import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Ping = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  ping_arrived_at: string;
  ping_kind: string;
  severity: string;
  hospital_user_id: string | null;
  hospital_email: string | null;
  equipment_label: string | null;
  status: string;
  answered_at: string | null;
  responder_email: string | null;
  resolve_at: string | null;
  response_minutes: number | null;
  extra_comp_rupees: number;
  notes: string | null;
};

type WeeklyRow = {
  week_start: string;
  total_pings: number;
  answered: number;
  missed: number;
  escalated: number;
  avg_response_minutes: number | null;
  total_extra_comp_rupees: number;
};

type Responder = {
  engineer_user_id: string;
  engineer_email: string | null;
  answered_count: number;
  avg_response_minutes: number | null;
  total_extra_comp_rupees: number;
};

type Offender = {
  engineer_user_id: string;
  engineer_email: string | null;
  total_pings: number;
  missed_count: number;
  miss_pct: number;
};

type CurrentSlot = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  slot_start_at: string;
  slot_end_at: string;
  is_primary: boolean;
  is_backup: boolean;
  hours_remaining: number;
  notes: string | null;
};

type LoadRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  slot_count: number;
  total_hours: number;
  primary_hours: number;
  backup_hours: number;
  swap_count: number;
};

type CompOwed = {
  engineer_user_id: string;
  engineer_email: string | null;
  pings_answered: number;
  total_extra_comp_rupees: number;
  avg_per_ping: number;
};

function fmtDateTime(iso: string | null): string {
  if (!iso) return '-';
  const d = new Date(iso);
  return d.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
}

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(v);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pingsRes, weeklyRes, respondersRes, offendersRes, currentRes, loadRes, compRes] = await Promise.all([
    sb.rpc('list_pings_r2410', { p_limit: 200 }),
    sb.rpc('weekly_response_summary_r2410', { p_weeks: 12 }),
    sb.rpc('top_responders_r2410', { p_limit: 20 }),
    sb.rpc('miss_offenders_r2410', { p_limit: 20 }),
    sb.rpc('current_oncall_slot_r2410'),
    sb.rpc('rotation_load_balance_r2410', { p_days: 90 }),
    sb.rpc('extra_comp_owed_r2410', { p_days: 30 }),
  ]);

  const pings: Ping[] = (pingsRes.data ?? []) as Ping[];
  const weekly: WeeklyRow[] = (weeklyRes.data ?? []) as WeeklyRow[];
  const responders: Responder[] = (respondersRes.data ?? []) as Responder[];
  const offenders: Offender[] = (offendersRes.data ?? []) as Offender[];
  const current: CurrentSlot[] = (currentRes.data ?? []) as CurrentSlot[];
  const load: LoadRow[] = (loadRes.data ?? []) as LoadRow[];
  const compOwed: CompOwed[] = (compRes.data ?? []) as CompOwed[];

  const openPings = pings.filter((p) => p.status === 'open' || p.status === 'escalated').length;
  const missedPings = pings.filter((p) => p.status === 'missed').length;
  const totalComp = compOwed.reduce((s, r) => s + Number(r.total_extra_comp_rupees ?? 0), 0);

  const pingCols: Column<Ping>[] = [
    {
      key: 'ping_arrived_at',
      header: 'Arrived',
      render: (r: Ping) => <span className="text-xs">{fmtDateTime(r.ping_arrived_at)}</span>,
    },
    {
      key: 'engineer_email',
      header: 'On-call engineer',
      render: (r: Ping) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span>,
    },
    {
      key: 'ping_kind',
      header: 'Kind',
      render: (r: Ping) => <span className="text-xs uppercase">{r.ping_kind}</span>,
    },
    {
      key: 'severity',
      header: 'Severity',
      render: (r: Ping) => {
        const color =
          r.severity === 'critical' ? 'text-red-700' :
          r.severity === 'high' ? 'text-orange-700' :
          r.severity === 'medium' ? 'text-yellow-700' : 'text-gray-700';
        return <span className={`text-xs font-semibold uppercase ${color}`}>{r.severity}</span>;
      },
    },
    {
      key: 'equipment_label',
      header: 'Equipment',
      render: (r: Ping) => <span className="text-xs">{r.equipment_label ?? '-'}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: Ping) => {
        const color =
          r.status === 'answered' ? 'bg-green-100 text-green-800' :
          r.status === 'missed' ? 'bg-red-100 text-red-800' :
          r.status === 'escalated' ? 'bg-orange-100 text-orange-800' :
          'bg-gray-100 text-gray-800';
        return <span className={`text-xs px-2 py-0.5 rounded ${color}`}>{r.status}</span>;
      },
    },
    {
      key: 'responder_email',
      header: 'Answered by',
      render: (r: Ping) => <span className="text-xs">{r.responder_email ?? '-'}</span>,
    },
    {
      key: 'response_minutes',
      header: 'Resp (min)',
      render: (r: Ping) => (
        <span className="text-xs tabular-nums">
          {r.response_minutes === null ? '-' : r.response_minutes}
        </span>
      ),
    },
    {
      key: 'extra_comp_rupees',
      header: 'Extra comp',
      render: (r: Ping) => (
        <span className="text-xs tabular-nums">
          {r.extra_comp_rupees > 0 ? `Rs ${fmtRupees(r.extra_comp_rupees)}` : '-'}
        </span>
      ),
    },
    {
      key: 'notes',
      header: 'Notes',
      render: (r: Ping) => <span className="text-xs text-gray-600">{r.notes ?? ''}</span>,
    },
  ];

  const weeklyCols: Column<WeeklyRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: WeeklyRow) => <span className="text-xs">{r.week_start}</span> },
    { key: 'total_pings', header: 'Pings', render: (r: WeeklyRow) => <span className="text-xs tabular-nums">{r.total_pings}</span> },
    { key: 'answered', header: 'Answered', render: (r: WeeklyRow) => <span className="text-xs tabular-nums text-green-700">{r.answered}</span> },
    { key: 'missed', header: 'Missed', render: (r: WeeklyRow) => <span className="text-xs tabular-nums text-red-700">{r.missed}</span> },
    { key: 'escalated', header: 'Escalated', render: (r: WeeklyRow) => <span className="text-xs tabular-nums text-orange-700">{r.escalated}</span> },
    {
      key: 'avg_response_minutes',
      header: 'Avg resp (min)',
      render: (r: WeeklyRow) => (
        <span className="text-xs tabular-nums">
          {r.avg_response_minutes === null ? '-' : Number(r.avg_response_minutes).toFixed(1)}
        </span>
      ),
    },
    {
      key: 'total_extra_comp_rupees',
      header: 'Comp Rs',
      render: (r: WeeklyRow) => <span className="text-xs tabular-nums">Rs {fmtRupees(r.total_extra_comp_rupees)}</span>,
    },
  ];

  const responderCols: Column<Responder>[] = [
    {
      key: 'engineer_email',
      header: 'Engineer',
      render: (r: Responder) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span>,
    },
    { key: 'answered_count', header: 'Answered', render: (r: Responder) => <span className="text-xs tabular-nums">{r.answered_count}</span> },
    {
      key: 'avg_response_minutes',
      header: 'Avg resp (min)',
      render: (r: Responder) => (
        <span className="text-xs tabular-nums">
          {r.avg_response_minutes === null ? '-' : Number(r.avg_response_minutes).toFixed(1)}
        </span>
      ),
    },
    {
      key: 'total_extra_comp_rupees',
      header: 'Total comp',
      render: (r: Responder) => <span className="text-xs tabular-nums">Rs {fmtRupees(r.total_extra_comp_rupees)}</span>,
    },
  ];

  const offenderCols: Column<Offender>[] = [
    {
      key: 'engineer_email',
      header: 'Engineer',
      render: (r: Offender) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span>,
    },
    { key: 'total_pings', header: 'Total pings', render: (r: Offender) => <span className="text-xs tabular-nums">{r.total_pings}</span> },
    {
      key: 'missed_count',
      header: 'Missed',
      render: (r: Offender) => <span className="text-xs tabular-nums text-red-700">{r.missed_count}</span>,
    },
    {
      key: 'miss_pct',
      header: 'Miss %',
      render: (r: Offender) => (
        <span className="text-xs tabular-nums font-semibold text-red-700">{Number(r.miss_pct).toFixed(1)}%</span>
      ),
    },
  ];

  const currentCols: Column<CurrentSlot>[] = [
    {
      key: 'engineer_email',
      header: 'Engineer',
      render: (r: CurrentSlot) => <span className="text-sm font-medium">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span>,
    },
    {
      key: 'role',
      header: 'Role',
      render: (r: CurrentSlot) => (
        <span className={`text-xs px-2 py-0.5 rounded font-semibold ${
          r.is_primary ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-700'
        }`}>
          {r.is_primary ? 'PRIMARY' : r.is_backup ? 'BACKUP' : '-'}
        </span>
      ),
    },
    { key: 'slot_start_at', header: 'Start', render: (r: CurrentSlot) => <span className="text-xs">{fmtDateTime(r.slot_start_at)}</span> },
    { key: 'slot_end_at', header: 'End', render: (r: CurrentSlot) => <span className="text-xs">{fmtDateTime(r.slot_end_at)}</span> },
    {
      key: 'hours_remaining',
      header: 'Hrs left',
      render: (r: CurrentSlot) => <span className="text-xs tabular-nums">{Number(r.hours_remaining).toFixed(1)}</span>,
    },
    { key: 'notes', header: 'Notes', render: (r: CurrentSlot) => <span className="text-xs text-gray-600">{r.notes ?? ''}</span> },
  ];

  const loadCols: Column<LoadRow>[] = [
    {
      key: 'engineer_email',
      header: 'Engineer',
      render: (r: LoadRow) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span>,
    },
    { key: 'slot_count', header: 'Slots', render: (r: LoadRow) => <span className="text-xs tabular-nums">{r.slot_count}</span> },
    {
      key: 'total_hours',
      header: 'Total hrs',
      render: (r: LoadRow) => <span className="text-xs tabular-nums font-semibold">{Number(r.total_hours).toFixed(1)}</span>,
    },
    {
      key: 'primary_hours',
      header: 'Primary hrs',
      render: (r: LoadRow) => <span className="text-xs tabular-nums">{Number(r.primary_hours).toFixed(1)}</span>,
    },
    {
      key: 'backup_hours',
      header: 'Backup hrs',
      render: (r: LoadRow) => <span className="text-xs tabular-nums">{Number(r.backup_hours).toFixed(1)}</span>,
    },
    { key: 'swap_count', header: 'Swaps', render: (r: LoadRow) => <span className="text-xs tabular-nums">{r.swap_count}</span> },
  ];

  const compCols: Column<CompOwed>[] = [
    {
      key: 'engineer_email',
      header: 'Engineer',
      render: (r: CompOwed) => <span className="text-sm">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span>,
    },
    { key: 'pings_answered', header: 'Pings answered', render: (r: CompOwed) => <span className="text-xs tabular-nums">{r.pings_answered}</span> },
    {
      key: 'total_extra_comp_rupees',
      header: 'Total owed',
      render: (r: CompOwed) => <span className="text-xs tabular-nums font-semibold">Rs {fmtRupees(r.total_extra_comp_rupees)}</span>,
    },
    {
      key: 'avg_per_ping',
      header: 'Avg per ping',
      render: (r: CompOwed) => <span className="text-xs tabular-nums">Rs {fmtRupees(r.avg_per_ping)}</span>,
    },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer on-call after-hours tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          After-hours pings, who answered, response minutes, extra comp earned, and engineer rotation load.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="bg-white border rounded p-3">
          <div className="text-xs text-gray-500">Open / escalated</div>
          <div className="text-2xl font-bold text-orange-700">{openPings}</div>
        </div>
        <div className="bg-white border rounded p-3">
          <div className="text-xs text-gray-500">Missed (recent)</div>
          <div className="text-2xl font-bold text-red-700">{missedPings}</div>
        </div>
        <div className="bg-white border rounded p-3">
          <div className="text-xs text-gray-500">Comp owed (30d)</div>
          <div className="text-2xl font-bold">Rs {fmtRupees(totalComp)}</div>
        </div>
        <div className="bg-white border rounded p-3">
          <div className="text-xs text-gray-500">On-call now</div>
          <div className="text-2xl font-bold text-blue-700">{current.length}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Who is on-call right now</h2>
        <DataTable
          rows={current}
          columns={currentCols}
          emptyMessage="No active on-call slot. Schedule rotation in rotation_slots_r2410."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent pings</h2>
        <p className="text-xs text-gray-500 mb-2">
          Last 200 after-hours pings. Response (min) = answered_at minus ping_arrived_at.
        </p>
        <DataTable
          rows={pings}
          columns={pingCols}
          emptyMessage="No on-call pings recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly response summary (last 12 weeks)</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top responders</h2>
        <p className="text-xs text-gray-500 mb-2">Engineers who answer most + fastest.</p>
        <DataTable
          rows={responders}
          columns={responderCols}
          emptyMessage="No answered pings yet."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Miss offenders</h2>
        <p className="text-xs text-gray-500 mb-2">
          Engineers with most missed pings — coach or rotate off after-hours.
        </p>
        <DataTable
          rows={offenders}
          columns={offenderCols}
          emptyMessage="No missed pings. Great coverage."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rotation load balance (last 90d)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Total on-call hours per engineer. Watch for &gt;= 2x mean = burnout risk.
        </p>
        <DataTable
          rows={load}
          columns={loadCols}
          emptyMessage="No rotation slots scheduled."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Extra comp owed (last 30d)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Dispatch to payroll — this is on top of base salary.
        </p>
        <DataTable
          rows={compOwed}
          columns={compCols}
          emptyMessage="No extra comp owed."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>
    </div>
  );
}
