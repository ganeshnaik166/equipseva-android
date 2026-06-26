import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SlotRow = {
  id: string;
  month_label: string;
  engineer_name: string;
  engineer_tier: string;
  time_of_day_slot: string;
  slot_window_label: string;
  handovers_count: number;
  avg_handover_minutes: number;
  avg_customer_impression: number;
  engagement_minutes_avg: number;
  outcome_label: string;
  amc_attach_rate_pct: number;
  notes: string;
};

type SignalRow = {
  id: string;
  month_label: string;
  time_of_day_slot: string;
  pattern_signal: string;
  customer_mood: string;
  engagement_band: string;
  outcome_trend: string;
  total_handovers: number;
  median_impression: number;
  recommended_action: string;
  observed_on: string;
};

type KpiRow = {
  total_handovers: number;
  avg_impression: number;
  avg_engagement_minutes: number;
  best_slot: string;
  worst_slot: string;
  excellent_slot_count: number;
  escalated_slot_count: number;
};

type RollupRow = {
  time_of_day_slot: string;
  handovers: number;
  avg_impression: number;
  avg_engagement_minutes: number;
  avg_attach_rate: number;
};

type LeaderRow = {
  engineer_name: string;
  engineer_tier: string;
  total_handovers: number;
  avg_impression: number;
  best_slot: string;
  amc_attach_rate: number;
};

type OutcomeRow = {
  outcome_label: string;
  slot_count: number;
  total_handovers: number;
  avg_impression: number;
};

type MoodRow = {
  customer_mood: string;
  engagement_band: string;
  slot_count: number;
  total_handovers: number;
};

type ActionRow = {
  time_of_day_slot: string;
  pattern_signal: string;
  outcome_trend: string;
  recommended_action: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const month = '2026-06';

  const [
    slotsRes,
    signalsRes,
    kpiRes,
    rollupRes,
    leaderRes,
    outcomeRes,
    moodRes,
    actionsRes,
  ] = await Promise.all([
    supabase.rpc('list_engineer_handover_time_slots_r2866', { p_month: month }),
    supabase.rpc('list_handover_time_pattern_signals_r2866', { p_month: month }),
    supabase.rpc('kpi_handover_time_pattern_r2866', { p_month: month }),
    supabase.rpc('rollup_time_of_day_r2866', { p_month: month }),
    supabase.rpc('engineer_leaderboard_handover_r2866', { p_month: month }),
    supabase.rpc('outcome_distribution_handover_r2866', { p_month: month }),
    supabase.rpc('pattern_mood_band_r2866', { p_month: month }),
    supabase.rpc('recommended_actions_handover_r2866', { p_month: month }),
  ]);

  const slots: SlotRow[] = (slotsRes.data as SlotRow[]) ?? [];
  const signals: SignalRow[] = (signalsRes.data as SignalRow[]) ?? [];
  const kpi: KpiRow | null = ((kpiRes.data as KpiRow[]) ?? [])[0] ?? null;
  const rollup: RollupRow[] = (rollupRes.data as RollupRow[]) ?? [];
  const leader: LeaderRow[] = (leaderRes.data as LeaderRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const moods: MoodRow[] = (moodRes.data as MoodRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Engineer Monthly Customer Handover {'—'} Time-of-Day Pattern
        </h1>
        <p className="text-sm text-gray-600">
          Round r2866 {'·'} engineer x handover x time-of-day x customer impression x engagement x outcome.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total handovers</div>
          <div className="text-2xl font-semibold">{kpi?.total_handovers ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg impression</div>
          <div className="text-2xl font-semibold">{kpi?.avg_impression ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg engagement (min)</div>
          <div className="text-2xl font-semibold">{kpi?.avg_engagement_minutes ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Best slot</div>
          <div className="text-2xl font-semibold">{kpi?.best_slot ?? 'n/a'}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Worst slot</div>
          <div className="text-2xl font-semibold">{kpi?.worst_slot ?? 'n/a'}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Excellent slot count</div>
          <div className="text-2xl font-semibold">{kpi?.excellent_slot_count ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Escalated slot count</div>
          <div className="text-2xl font-semibold">{kpi?.escalated_slot_count ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Month</div>
          <div className="text-2xl font-semibold">{month}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Time-of-day rollup</h2>
        <DataTable
          rows={rollup}
          columns={[
            { key: 'time_of_day_slot', header: 'Slot', render: (r: RollupRow) => r.time_of_day_slot },
            { key: 'handovers', header: 'Handovers', render: (r: RollupRow) => r.handovers },
            { key: 'avg_impression', header: 'Avg impression', render: (r: RollupRow) => r.avg_impression },
            { key: 'avg_engagement_minutes', header: 'Avg engagement (min)', render: (r: RollupRow) => r.avg_engagement_minutes },
            { key: 'avg_attach_rate', header: 'AMC attach %', render: (r: RollupRow) => r.avg_attach_rate },
          ]}
          emptyMessage="No data"
          rowKey={(r: RollupRow, i: number) => String(r.time_of_day_slot ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Engineer leaderboard</h2>
        <DataTable
          rows={leader}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: LeaderRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: LeaderRow) => r.engineer_tier },
            { key: 'total_handovers', header: 'Handovers', render: (r: LeaderRow) => r.total_handovers },
            { key: 'avg_impression', header: 'Avg impression', render: (r: LeaderRow) => r.avg_impression },
            { key: 'best_slot', header: 'Best slot', render: (r: LeaderRow) => r.best_slot },
            { key: 'amc_attach_rate', header: 'AMC attach %', render: (r: LeaderRow) => r.amc_attach_rate },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeaderRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Engineer slot detail</h2>
        <DataTable
          rows={slots}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: SlotRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: SlotRow) => r.engineer_tier },
            { key: 'time_of_day_slot', header: 'Slot', render: (r: SlotRow) => r.time_of_day_slot },
            { key: 'slot_window_label', header: 'Window', render: (r: SlotRow) => r.slot_window_label },
            { key: 'handovers_count', header: 'Handovers', render: (r: SlotRow) => r.handovers_count },
            { key: 'avg_handover_minutes', header: 'Avg minutes', render: (r: SlotRow) => r.avg_handover_minutes },
            { key: 'avg_customer_impression', header: 'Impression', render: (r: SlotRow) => r.avg_customer_impression },
            { key: 'engagement_minutes_avg', header: 'Engagement', render: (r: SlotRow) => r.engagement_minutes_avg },
            { key: 'outcome_label', header: 'Outcome', render: (r: SlotRow) => r.outcome_label },
            { key: 'amc_attach_rate_pct', header: 'AMC %', render: (r: SlotRow) => r.amc_attach_rate_pct },
            { key: 'notes', header: 'Notes', render: (r: SlotRow) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: SlotRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Outcome distribution</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome_label', header: 'Outcome', render: (r: OutcomeRow) => r.outcome_label },
            { key: 'slot_count', header: 'Slots', render: (r: OutcomeRow) => r.slot_count },
            { key: 'total_handovers', header: 'Handovers', render: (r: OutcomeRow) => r.total_handovers },
            { key: 'avg_impression', header: 'Avg impression', render: (r: OutcomeRow) => r.avg_impression },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome_label ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Mood and engagement bands</h2>
        <DataTable
          rows={moods}
          columns={[
            { key: 'customer_mood', header: 'Mood', render: (r: MoodRow) => r.customer_mood },
            { key: 'engagement_band', header: 'Engagement', render: (r: MoodRow) => r.engagement_band },
            { key: 'slot_count', header: 'Slots', render: (r: MoodRow) => r.slot_count },
            { key: 'total_handovers', header: 'Handovers', render: (r: MoodRow) => r.total_handovers },
          ]}
          emptyMessage="No data"
          rowKey={(r: MoodRow, i: number) => `${r.customer_mood}-${r.engagement_band}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Pattern signals</h2>
        <DataTable
          rows={signals}
          columns={[
            { key: 'time_of_day_slot', header: 'Slot', render: (r: SignalRow) => r.time_of_day_slot },
            { key: 'pattern_signal', header: 'Pattern', render: (r: SignalRow) => r.pattern_signal },
            { key: 'customer_mood', header: 'Mood', render: (r: SignalRow) => r.customer_mood },
            { key: 'engagement_band', header: 'Engagement', render: (r: SignalRow) => r.engagement_band },
            { key: 'outcome_trend', header: 'Trend', render: (r: SignalRow) => r.outcome_trend },
            { key: 'total_handovers', header: 'Handovers', render: (r: SignalRow) => r.total_handovers },
            { key: 'median_impression', header: 'Median impression', render: (r: SignalRow) => r.median_impression },
            { key: 'observed_on', header: 'Observed', render: (r: SignalRow) => r.observed_on },
          ]}
          emptyMessage="No data"
          rowKey={(r: SignalRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recommended actions</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'time_of_day_slot', header: 'Slot', render: (r: ActionRow) => r.time_of_day_slot },
            { key: 'pattern_signal', header: 'Pattern', render: (r: ActionRow) => r.pattern_signal },
            { key: 'outcome_trend', header: 'Trend', render: (r: ActionRow) => r.outcome_trend },
            { key: 'recommended_action', header: 'Action', render: (r: ActionRow) => r.recommended_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => `${r.time_of_day_slot}-${i}`}
        />
      </section>
    </div>
  );
}
