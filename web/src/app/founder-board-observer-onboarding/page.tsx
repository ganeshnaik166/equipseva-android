import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import type { ReactNode } from 'react';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function fmtDate(v: string | null | undefined): string {
  if (!v) return '—';
  try { return new Date(v).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: '2-digit' }); }
  catch { return '—'; }
}

function StatusPill({ status }: { status: string }) {
  const cls =
    status === 'completed' ? 'bg-emerald-100 text-emerald-800' :
    status === 'blocked' ? 'bg-rose-100 text-rose-800' :
    status === 'cancelled' ? 'bg-neutral-200 text-neutral-700' :
    'bg-amber-100 text-amber-800';
  return <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>{status}</span>;
}

export default async function BoardObserverOnboardingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, listRes, funnelRes, blockedRes, activityRes, cadenceRes] = await Promise.all([
    supabase.rpc('board_observer_kpis'),
    supabase.rpc('board_observer_onboarding_list'),
    supabase.rpc('board_observer_funnel_summary'),
    supabase.rpc('board_observer_blocked_list'),
    supabase.rpc('board_observer_recent_activity', { p_limit: 50 }),
    supabase.rpc('board_observer_cadence_calendar'),
  ]);

  const k: any = Array.isArray(kpisRes.data) ? kpisRes.data[0] ?? {} : kpisRes.data ?? {};
  const list: any[] = listRes.data ?? [];
  const funnel: any[] = funnelRes.data ?? [];
  const blocked: any[] = blockedRes.data ?? [];
  const activity: any[] = activityRes.data ?? [];
  const cadence: any[] = cadenceRes.data ?? [];

  const pipelineCols: Column<any>[] = [
    { key: 'observer_name', header: 'Observer', render: (r: any) => (
        <div>
          <div className="font-medium text-neutral-900">{r.observer_name ?? '—'}</div>
          <div className="text-xs text-neutral-500">{r.observer_email ?? '—'}</div>
        </div>
      ) },
    { key: 'investor_org', header: 'Investor / Org', render: (r: any) => r.investor_org ?? r.observer_org ?? '—' },
    { key: 'role_type', header: 'Role', render: (r: any) => r.role_type ?? '—' },
    { key: 'current_step', header: 'Step', render: (r: any) => (
        <span className="font-mono text-sm">{r.current_step ?? 0}/7</span>
      ) },
    { key: 'next_action', header: 'Next action', render: (r: any) => r.next_action ?? '—' },
    { key: 'step_status', header: 'Status', render: (r: any) => <StatusPill status={String(r.step_status ?? 'in_progress')} /> },
    { key: 'days_in_pipeline', header: 'Days', render: (r: any) => <span className="font-mono">{r.days_in_pipeline ?? 0}</span> },
    { key: 'added_at', header: 'Added', render: (r: any) => fmtDate(r.added_at) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'step_num', header: '#', render: (r: any) => <span className="font-mono">{r.step_num}</span> },
    { key: 'step_label', header: 'Step', render: (r: any) => r.step_label ?? '—' },
    { key: 'observers_at_or_past', header: 'Reached', render: (r: any) => <span className="font-mono">{r.observers_at_or_past ?? 0}</span> },
    { key: 'observers_currently_at', header: 'Currently at', render: (r: any) => <span className="font-mono">{r.observers_currently_at ?? 0}</span> },
  ];

  const blockedCols: Column<any>[] = [
    { key: 'observer_name', header: 'Observer', render: (r: any) => r.observer_name ?? '—' },
    { key: 'investor_org', header: 'Investor', render: (r: any) => r.investor_org ?? '—' },
    { key: 'current_step', header: 'Stuck at step', render: (r: any) => <span className="font-mono">{r.current_step ?? 0}/7</span> },
    { key: 'days_blocked', header: 'Days blocked', render: (r: any) => <span className="font-mono text-rose-700">{r.days_blocked ?? 0}</span> },
    { key: 'note', header: 'Reason', render: (r: any) => <span className="text-sm text-neutral-700">{r.note ?? '—'}</span> },
  ];

  const cadenceCols: Column<any>[] = [
    { key: 'observer_name', header: 'Observer', render: (r: any) => r.observer_name ?? '—' },
    { key: 'investor_org', header: 'Investor', render: (r: any) => r.investor_org ?? '—' },
    { key: 'cadence_day_of_month', header: 'Day of month', render: (r: any) => <span className="font-mono">{r.cadence_day_of_month ?? '—'}</span> },
    { key: 'next_send_date', header: 'Next send', render: (r: any) => fmtDate(r.next_send_date) },
    { key: 'last_board_pack_at', header: 'Last pack', render: (r: any) => fmtDate(r.last_board_pack_at) },
  ];

  const activityCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => fmtDate(r.created_at) },
    { key: 'observer_name', header: 'Observer', render: (r: any) => r.observer_name ?? '—' },
    { key: 'step_num', header: 'Step', render: (r: any) => <span className="font-mono">{r.step_num ?? 0}</span> },
    { key: 'step_label', header: 'Label', render: (r: any) => r.step_label ?? '—' },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? '—' },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-sm text-neutral-700">{r.note ?? '—'}</span> },
    { key: 'actor_email', header: 'Actor', render: (r: any) => <span className="text-xs text-neutral-500">{r.actor_email ?? '—'}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-6">
      <header className="mb-6">
        <div className="text-xs uppercase tracking-wide text-neutral-500">Capital · r1475</div>
        <h1 className="text-2xl font-semibold text-neutral-900">Board observer onboarding tracker</h1>
        <p className="mt-1 text-sm text-neutral-600">
          7-step playbook for new board observers and members: NDA, data room access, intro calls, monthly cadence setup, first board pack.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Total observers" value={k.total_observers ?? 0} />
        <Kpi label="Active" value={k.active_observers ?? 0} />
        <Kpi label="Completed" value={k.completed_observers ?? 0} />
        <Kpi label="Blocked" value={k.blocked_observers ?? 0} />
        <Kpi label="Cancelled" value={k.cancelled_observers ?? 0} />
        <Kpi label="NDAs signed" value={k.ndas_signed ?? 0} />
        <Kpi label="Data room granted" value={k.data_room_granted ?? 0} />
        <Kpi label="Intro calls done" value={k.intro_calls_completed ?? 0} />
        <Kpi label="Cadence set" value={k.cadence_setup ?? 0} />
        <Kpi label="Board packs sent" value={k.board_packs_sent ?? 0} />
        <Kpi label="Avg days to complete" value={k.avg_days_to_complete ?? 0} />
        <Kpi label="Median days" value={k.median_days_to_complete ?? 0} />
        <Kpi label="Stuck over 14d" value={k.stuck_over_14d ?? 0} />
        <Kpi label="Added last 30d" value={k.added_last_30d ?? 0} />
        <Kpi label="Completed last 30d" value={k.completed_last_30d ?? 0} />
        <Kpi label="Pending first pack" value={k.pending_first_pack ?? 0} />
      </section>

      <section className="mt-8">
        <h2 className="text-lg font-semibold text-neutral-900 mb-3">Active pipeline</h2>
        <DataTable
          columns={pipelineCols}
          rows={list}
          rowKey={(r: any) => r.id}
          emptyMessage="No observers in pipeline"
        />
      </section>

      <section className="mt-8">
        <h2 className="text-lg font-semibold text-neutral-900 mb-3">7-step funnel</h2>
        <DataTable
          columns={funnelCols}
          rows={funnel}
          rowKey={(r: any) => String(r.step_num)}
          emptyMessage="No funnel data"
        />
      </section>

      <section className="mt-8">
        <h2 className="text-lg font-semibold text-neutral-900 mb-3">Blocked observers</h2>
        <DataTable
          columns={blockedCols}
          rows={blocked}
          rowKey={(r: any) => r.id}
          emptyMessage="None blocked"
        />
      </section>

      <section className="mt-8">
        <h2 className="text-lg font-semibold text-neutral-900 mb-3">Monthly cadence calendar</h2>
        <DataTable
          columns={cadenceCols}
          rows={cadence}
          rowKey={(r: any) => r.id}
          emptyMessage="No cadence configured"
        />
      </section>

      <section className="mt-8">
        <h2 className="text-lg font-semibold text-neutral-900 mb-3">Recent activity</h2>
        <DataTable
          columns={activityCols}
          rows={activity}
          rowKey={(r: any) => r.id}
          emptyMessage="No recent activity"
        />
      </section>
    </main>
  );
}
