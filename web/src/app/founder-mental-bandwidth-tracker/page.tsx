import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMentalBandwidthTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    weeklyRes,
    decisionsRes,
    distractionRes,
    energyRes,
    delegationRes,
    drainsRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_weekly_bandwidth_r2425'),
    supabase.rpc('list_delegated_decisions_r2425'),
    supabase.rpc('distraction_trend_r2425'),
    supabase.rpc('energy_vs_deep_work_r2425'),
    supabase.rpc('delegation_outcome_breakdown_r2425'),
    supabase.rpc('top_drains_r2425'),
    supabase.rpc('weekly_pulse_summary_r2425'),
  ]);

  const weekly = (weeklyRes.data ?? []) as any[];
  const decisions = (decisionsRes.data ?? []) as any[];
  const distraction = (distractionRes.data ?? []) as any[];
  const energy = (energyRes.data ?? []) as any[];
  const delegation = (delegationRes.data ?? []) as any[];
  const drains = (drainsRes.data ?? []) as any[];
  const pulse = ((pulseRes.data ?? []) as any[])[0] ?? null;

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => String(r.week_start ?? '') },
    { key: 'deep', header: 'Deep work (h)', render: (r) => String(r.hours_deep_work ?? 0) },
    { key: 'meet', header: 'Meetings', render: (r) => String(r.hours_meetings ?? 0) },
    { key: 'es', header: 'Email/Slack', render: (r) => String(r.hours_email_slack ?? 0) },
    { key: 'fire', header: 'Firefighting', render: (r) => String(r.hours_firefighting ?? 0) },
    { key: 'strat', header: 'Strategic', render: (r) => String(r.hours_strategic_thinking ?? 0) },
    { key: 'total', header: 'Total h', render: (r) => String(r.total_hours ?? 0) },
    { key: 'dist', header: 'Distraction (1-10)', render: (r) => String(r.distraction_score ?? '') },
    { key: 'energy', header: 'Energy (1-10)', render: (r) => String(r.energy_score ?? '') },
    { key: 'sleep', header: 'Sleep (h avg)', render: (r) => String(r.sleep_hours_avg ?? '') },
    { key: 'mood', header: 'Mood', render: (r) => String(r.mood ?? '') },
    { key: 'topd', header: 'Top distraction', render: (r) => String(r.top_distraction ?? '') },
  ];

  const decisionsCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => String(r.week_start ?? '') },
    { key: 'sum', header: 'Decision', render: (r) => String(r.decision_summary ?? '') },
    { key: 'to', header: 'Delegated to', render: (r) => String(r.delegated_to_email ?? '') },
    { key: 'out', header: 'Outcome', render: (r) => String(r.decision_outcome ?? '') },
    { key: 'back', header: 'Came back?', render: (r) => (r.came_back_to_founder ? 'yes' : 'no') },
    { key: 'saved', header: 'Time saved (h)', render: (r) => String(r.time_saved_hours ?? 0) },
    { key: 'regret', header: 'Regret (0-5)', render: (r) => String(r.founder_regret_score ?? 0) },
    { key: 'learn', header: 'Learnings', render: (r) => String(r.learnings_md ?? '') },
  ];

  const distractionCols: Column<any>[] = [
    { key: 'week', header: 'Week', render: (r) => String(r.week_start ?? '') },
    { key: 'd', header: 'Distraction', render: (r) => String(r.distraction_score ?? '') },
    { key: 'e', header: 'Energy', render: (r) => String(r.energy_score ?? '') },
    { key: 'delta', header: 'Delta vs prior', render: (r) => (r.delta_distraction === null || r.delta_distraction === undefined ? '-' : String(r.delta_distraction)) },
  ];

  const energyCols: Column<any>[] = [
    { key: 'week', header: 'Week', render: (r) => String(r.week_start ?? '') },
    { key: 'energy', header: 'Energy', render: (r) => String(r.energy_score ?? '') },
    { key: 'deep', header: 'Deep work (h)', render: (r) => String(r.hours_deep_work ?? 0) },
    { key: 'fire', header: 'Firefighting (h)', render: (r) => String(r.hours_firefighting ?? 0) },
    { key: 'ratio', header: 'Deep / fire ratio', render: (r) => String(r.ratio_deep_to_fire ?? 0) },
  ];

  const delegationCols: Column<any>[] = [
    { key: 'out', header: 'Outcome', render: (r) => String(r.decision_outcome ?? '') },
    { key: 'cnt', header: 'Decisions', render: (r) => String(r.decisions ?? 0) },
    { key: 'saved', header: 'Total time saved (h)', render: (r) => String(r.total_time_saved ?? 0) },
    { key: 'regret', header: 'Avg regret', render: (r) => String(r.avg_regret ?? 0) },
    { key: 'rev', header: 'Came-back %', render: (r) => String(r.reversed_share ?? 0) + '%' },
  ];

  const drainsCols: Column<any>[] = [
    { key: 'drain', header: 'Drain', render: (r) => String(r.drain ?? '') },
    { key: 'cnt', header: 'Occurrences', render: (r) => String(r.occurrences ?? 0) },
    { key: 'adist', header: 'Avg distraction', render: (r) => String(r.avg_distraction ?? 0) },
    { key: 'aenergy', header: 'Avg energy', render: (r) => String(r.avg_energy ?? 0) },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder mental bandwidth tracker</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Weekly self-check: hours of deep work, distraction & energy scores, and delegated decisions.
          Track what drains versus energizes & whether delegation actually saved founder time.
        </p>
      </header>

      {pulse ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Stat label="Weeks logged" value={String(pulse.weeks_logged ?? 0)} />
          <Stat label="Avg deep work (h)" value={String(pulse.avg_deep_work ?? 0)} />
          <Stat label="Avg firefighting (h)" value={String(pulse.avg_firefighting ?? 0)} />
          <Stat label="Avg distraction" value={String(pulse.avg_distraction ?? 0)} />
          <Stat label="Avg energy" value={String(pulse.avg_energy ?? 0)} />
          <Stat label="Avg sleep (h)" value={String(pulse.avg_sleep ?? 0)} />
          <Stat label="Delegated decisions" value={String(pulse.delegated_count ?? 0)} />
          <Stat label="Hours saved by delegation" value={String(pulse.delegated_time_saved ?? 0)} />
        </section>
      ) : null}

      <Section title="Weekly bandwidth log">
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly entries yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Distraction trend (week over week)">
        <DataTable
          rows={distraction}
          columns={distractionCols}
          emptyMessage="No distraction data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </Section>

      <Section title="Energy vs deep work">
        <DataTable
          rows={energy}
          columns={energyCols}
          emptyMessage="No energy data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </Section>

      <Section title="Top drains (recurring time sinks)">
        <DataTable
          rows={drains}
          columns={drainsCols}
          emptyMessage="No drains logged."
          rowKey={(r: any, i: number) => String(r.drain ?? i)}
        />
      </Section>

      <Section title="Delegated decisions">
        <DataTable
          rows={decisions}
          columns={decisionsCols}
          emptyMessage="No delegated decisions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Delegation outcome breakdown">
        <DataTable
          rows={delegation}
          columns={delegationCols}
          emptyMessage="No outcomes yet."
          rowKey={(r: any, i: number) => String(r.decision_outcome ?? i)}
        />
      </Section>
    </main>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-2">
      <h2 className="text-lg font-medium">{title}</h2>
      {children}
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded border border-[var(--color-border)] bg-white p-3">
      <div className="text-xs text-[var(--color-muted)]">{label}</div>
      <div className="text-lg font-semibold">{value}</div>
    </div>
  );
}
