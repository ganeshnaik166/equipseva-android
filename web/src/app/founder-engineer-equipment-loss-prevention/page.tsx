import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LossEvent = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  equipment_name: string | null;
  lost_at: string | null;
  location_lost: string | null;
  replacement_cost_rupees: number | null;
  status: string | null;
  recovered_at: string | null;
  recovered_location: string | null;
};

type SummaryRow = {
  engineer_user_id: string | null;
  engineer_email: string | null;
  total_events: number | null;
  reported_count: number | null;
  recovered_count: number | null;
  written_off_count: number | null;
  disputed_count: number | null;
  total_replacement_cost_rupees: number | null;
};

type RecoveryRow = {
  id: string;
  engineer_email: string | null;
  equipment_name: string | null;
  lost_at: string | null;
  recovered_at: string | null;
  recovered_location: string | null;
  replacement_cost_rupees: number | null;
};

type ActionRow = {
  id: string;
  event_id: string | null;
  equipment_name: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  expected_impact: string | null;
};

function fmtDate(s: string | null) {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return s; }
}

function fmtMoney(n: number | null) {
  if (n == null) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [eventsRes, summaryRes, recoveriesRes, actionsRes] = await Promise.all([
    sb.rpc('list_loss_events_r1828'),
    sb.rpc('loss_summary_per_engineer_r1828'),
    sb.rpc('recent_recoveries_r1828'),
    sb.rpc('list_loss_prevention_actions_r1828', { p_event_id: null }),
  ]);

  const events: LossEvent[] = (eventsRes.data as LossEvent[]) || [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[]) || [];
  const recoveries: RecoveryRow[] = (recoveriesRes.data as RecoveryRow[]) || [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) || [];

  const totalEvents = events.length;
  const totalCost = events.reduce((s, e) => s + (e.replacement_cost_rupees || 0), 0);
  const openCount = events.filter(e => e.status === 'reported' || e.status === 'disputed').length;
  const recoveredCount = events.filter(e => e.status === 'recovered').length;

  const eventCols: Column<LossEvent>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="text-xs">{r.engineer_email || '—'}</span> },
    { key: 'equipment', header: 'Equipment', render: (r: any) => <span>{r.equipment_name || '—'}</span> },
    { key: 'lost_at', header: 'Lost At', render: (r: any) => <span className="text-xs">{fmtDate(r.lost_at)}</span> },
    { key: 'location', header: 'Location', render: (r: any) => <span className="text-xs">{r.location_lost || '—'}</span> },
    { key: 'cost', header: 'Cost', render: (r: any) => <span>{fmtMoney(r.replacement_cost_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs uppercase">{r.status || '—'}</span> },
    { key: 'recovered', header: 'Recovered', render: (r: any) => <span className="text-xs">{r.recovered_at ? fmtDate(r.recovered_at) : '—'}</span> },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="text-xs">{r.engineer_email || '—'}</span> },
    { key: 'total', header: 'Total Events', render: (r: any) => <span>{r.total_events ?? 0}</span> },
    { key: 'reported', header: 'Reported', render: (r: any) => <span>{r.reported_count ?? 0}</span> },
    { key: 'recovered', header: 'Recovered', render: (r: any) => <span>{r.recovered_count ?? 0}</span> },
    { key: 'written_off', header: 'Written Off', render: (r: any) => <span>{r.written_off_count ?? 0}</span> },
    { key: 'disputed', header: 'Disputed', render: (r: any) => <span>{r.disputed_count ?? 0}</span> },
    { key: 'cost', header: 'Total Cost', render: (r: any) => <span>{fmtMoney(r.total_replacement_cost_rupees)}</span> },
  ];

  const recoveryCols: Column<RecoveryRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="text-xs">{r.engineer_email || '—'}</span> },
    { key: 'equipment', header: 'Equipment', render: (r: any) => <span>{r.equipment_name || '—'}</span> },
    { key: 'lost', header: 'Lost', render: (r: any) => <span className="text-xs">{fmtDate(r.lost_at)}</span> },
    { key: 'recovered', header: 'Recovered', render: (r: any) => <span className="text-xs">{fmtDate(r.recovered_at)}</span> },
    { key: 'rec_loc', header: 'Recovery Location', render: (r: any) => <span className="text-xs">{r.recovered_location || '—'}</span> },
    { key: 'cost', header: 'Saved', render: (r: any) => <span>{fmtMoney(r.replacement_cost_rupees)}</span> },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken', header: 'Taken At', render: (r: any) => <span className="text-xs">{fmtDate(r.taken_at)}</span> },
    { key: 'equipment', header: 'Equipment', render: (r: any) => <span>{r.equipment_name || '—'}</span> },
    { key: 'type', header: 'Action Type', render: (r: any) => <span className="text-xs uppercase">{r.action_type || '—'}</span> },
    { key: 'by', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email || '—'}</span> },
    { key: 'impact', header: 'Expected Impact', render: (r: any) => <span className="text-xs">{r.expected_impact || '—'}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Equipment Loss Prevention</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track equipment-loss events & preventive actions across the field force.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Total Events</div>
          <div className="mt-1 text-2xl font-semibold">{totalEvents}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Open (reported & disputed)</div>
          <div className="mt-1 text-2xl font-semibold">{openCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Recovered</div>
          <div className="mt-1 text-2xl font-semibold">{recoveredCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Total Replacement Cost</div>
          <div className="mt-1 text-2xl font-semibold">{fmtMoney(totalCost)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Loss Events</h2>
        <p className="text-xs text-[var(--color-muted)]">Latest 200 reported losses. Status flows reported → recovered / written_off / disputed.</p>
        <DataTable<LossEvent>
          rows={events}
          columns={eventCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No loss events recorded."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Summary per Engineer</h2>
        <p className="text-xs text-[var(--color-muted)]">Top engineers ranked by total loss-event count.</p>
        <DataTable<SummaryRow>
          rows={summary}
          columns={summaryCols}
          rowKey={(r, i) => String(r.engineer_user_id ?? i)}
          emptyMessage="No engineer summary yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent Recoveries</h2>
        <p className="text-xs text-[var(--color-muted)]">Equipment marked as recovered — cost avoided.</p>
        <DataTable<RecoveryRow>
          rows={recoveries}
          columns={recoveryCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No recoveries logged."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Prevention Actions</h2>
        <p className="text-xs text-[var(--color-muted)]">Policy updates, training, insurance, tagging & spot audits.</p>
        <DataTable<ActionRow>
          rows={actions}
          columns={actionCols}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No prevention actions logged."
        />
      </section>
    </div>
  );
}
