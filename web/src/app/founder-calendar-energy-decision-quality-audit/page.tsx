import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MeetingTypeRow = {
  meeting_type: string;
  meeting_count: number;
  avg_duration_minutes: number;
  avg_prep_minutes: number;
  avg_energy_drain: number;
  avg_energy_gain: number;
  total_revenue_impact_rupees: number;
};

type DecisionRow = {
  decision_quality_rating: string;
  meeting_count: number;
  total_minutes_invested: number;
  avg_prep_quality_rank: number;
  total_revenue_impact_rupees: number;
};

type CandidateRow = {
  meeting_code: string;
  meeting_title: string;
  meeting_type: string;
  duration_minutes: number;
  energy_drain_score: number;
  decision_quality_rating: string;
  recommendation: string;
  audit_notes: string | null;
};

type PrepVsOutcomeRow = {
  prep_quality: string;
  meeting_count: number;
  decided_or_closed: number;
  rambled_or_no_show: number;
  avg_follow_up_actions: number;
  avg_energy_gain: number;
};

type DeepWorkCategoryRow = {
  block_category: string;
  block_count: number;
  total_planned_minutes: number;
  total_actual_minutes: number;
  total_interruptions: number;
  total_context_switch_cost: number;
  avg_energy_delta: number;
};

type OutputQualityRow = {
  output_quality: string;
  block_count: number;
  total_actual_minutes: number;
  protected_blocks: number;
  avg_interruptions: number;
  pct_of_total: number;
};

type InterruptionRow = {
  block_code: string;
  block_label: string;
  block_category: string;
  interruptions_count: number;
  context_switch_cost_minutes: number;
  actual_minutes: number;
  output_quality: string;
  protected_block: boolean;
};

type SummaryRow = { metric: string; value: string };

type RevenueRow = {
  meeting_code: string;
  meeting_title: string;
  meeting_type: string;
  duration_minutes: number;
  prep_minutes: number;
  decision_quality_rating: string;
  estimated_revenue_impact_rupees: number;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (!Number.isFinite(v)) return '-';
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(v);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    meetingType,
    decisionQuality,
    candidates,
    prepOutcome,
    deepCategory,
    outputQuality,
    interruptions,
    summary,
    topRevenue,
  ] = await Promise.all([
    supabase.rpc('fn_r3113_meeting_type_rollup'),
    supabase.rpc('fn_r3113_decision_quality_distribution'),
    supabase.rpc('fn_r3113_delegate_defend_kill_candidates'),
    supabase.rpc('fn_r3113_prep_vs_outcome'),
    supabase.rpc('fn_r3113_deep_work_category_rollup'),
    supabase.rpc('fn_r3113_deep_work_output_quality'),
    supabase.rpc('fn_r3113_interruption_hotlist'),
    supabase.rpc('fn_r3113_quarterly_summary'),
    supabase.rpc('fn_r3113_top_revenue_meetings'),
  ]);

  const meetingTypeRows: MeetingTypeRow[] = (meetingType.data ?? []) as MeetingTypeRow[];
  const decisionRows: DecisionRow[] = (decisionQuality.data ?? []) as DecisionRow[];
  const candidateRows: CandidateRow[] = (candidates.data ?? []) as CandidateRow[];
  const prepRows: PrepVsOutcomeRow[] = (prepOutcome.data ?? []) as PrepVsOutcomeRow[];
  const deepCategoryRows: DeepWorkCategoryRow[] = (deepCategory.data ?? []) as DeepWorkCategoryRow[];
  const outputRows: OutputQualityRow[] = (outputQuality.data ?? []) as OutputQualityRow[];
  const interruptionRows: InterruptionRow[] = (interruptions.data ?? []) as InterruptionRow[];
  const summaryRows: SummaryRow[] = (summary.data ?? []) as SummaryRow[];
  const revenueRows: RevenueRow[] = (topRevenue.data ?? []) as RevenueRow[];

  const meetingTypeCols: Column<MeetingTypeRow>[] = [
    { key: 'meeting_type', header: 'Meeting Type' },
    { key: 'meeting_count', header: 'Count' },
    { key: 'avg_duration_minutes', header: 'Avg Duration (min)' },
    { key: 'avg_prep_minutes', header: 'Avg Prep (min)' },
    { key: 'avg_energy_drain', header: 'Avg Drain (1-10)' },
    { key: 'avg_energy_gain', header: 'Avg Gain (1-10)' },
    { key: 'total_revenue_impact_rupees', header: 'Revenue Impact', render: (r) => inr(r.total_revenue_impact_rupees) },
  ];

  const decisionCols: Column<DecisionRow>[] = [
    { key: 'decision_quality_rating', header: 'Decision Quality' },
    { key: 'meeting_count', header: 'Count' },
    { key: 'total_minutes_invested', header: 'Total Minutes' },
    { key: 'avg_prep_quality_rank', header: 'Avg Prep Rank (0-4)' },
    { key: 'total_revenue_impact_rupees', header: 'Revenue Impact', render: (r) => inr(r.total_revenue_impact_rupees) },
  ];

  const candidateCols: Column<CandidateRow>[] = [
    { key: 'recommendation', header: 'Action' },
    { key: 'meeting_code', header: 'Code' },
    { key: 'meeting_title', header: 'Meeting' },
    { key: 'meeting_type', header: 'Type' },
    { key: 'duration_minutes', header: 'Min' },
    { key: 'energy_drain_score', header: 'Drain' },
    { key: 'decision_quality_rating', header: 'Decision' },
    { key: 'audit_notes', header: 'Notes', render: (r) => r.audit_notes ?? '-' },
  ];

  const prepCols: Column<PrepVsOutcomeRow>[] = [
    { key: 'prep_quality', header: 'Prep Quality' },
    { key: 'meeting_count', header: 'Count' },
    { key: 'decided_or_closed', header: 'Decided/Closed' },
    { key: 'rambled_or_no_show', header: 'Rambled/No-show' },
    { key: 'avg_follow_up_actions', header: 'Avg Follow-ups' },
    { key: 'avg_energy_gain', header: 'Avg Gain' },
  ];

  const deepCategoryCols: Column<DeepWorkCategoryRow>[] = [
    { key: 'block_category', header: 'Block Category' },
    { key: 'block_count', header: 'Blocks' },
    { key: 'total_planned_minutes', header: 'Planned (min)' },
    { key: 'total_actual_minutes', header: 'Actual (min)' },
    { key: 'total_interruptions', header: 'Interrupts' },
    { key: 'total_context_switch_cost', header: 'Switch Cost (min)' },
    { key: 'avg_energy_delta', header: 'Avg Energy Delta' },
  ];

  const outputCols: Column<OutputQualityRow>[] = [
    { key: 'output_quality', header: 'Output Quality' },
    { key: 'block_count', header: 'Blocks' },
    { key: 'total_actual_minutes', header: 'Minutes' },
    { key: 'protected_blocks', header: 'Protected' },
    { key: 'avg_interruptions', header: 'Avg Interrupts' },
    { key: 'pct_of_total', header: 'Pct of Total' },
  ];

  const interruptionCols: Column<InterruptionRow>[] = [
    { key: 'block_code', header: 'Code' },
    { key: 'block_label', header: 'Block' },
    { key: 'block_category', header: 'Category' },
    { key: 'interruptions_count', header: 'Interrupts' },
    { key: 'context_switch_cost_minutes', header: 'Switch Cost' },
    { key: 'actual_minutes', header: 'Minutes' },
    { key: 'output_quality', header: 'Quality' },
    { key: 'protected_block', header: 'Protected', render: (r) => (r.protected_block ? 'yes' : 'no') },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'metric', header: 'Metric' },
    { key: 'value', header: 'Value', render: (r) => (r.metric.endsWith('rupees') ? inr(Number(r.value)) : r.value) },
  ];

  const revenueCols: Column<RevenueRow>[] = [
    { key: 'meeting_code', header: 'Code' },
    { key: 'meeting_title', header: 'Meeting' },
    { key: 'meeting_type', header: 'Type' },
    { key: 'duration_minutes', header: 'Min' },
    { key: 'prep_minutes', header: 'Prep' },
    { key: 'decision_quality_rating', header: 'Decision' },
    { key: 'estimated_revenue_impact_rupees', header: 'Impact', render: (r) => inr(r.estimated_revenue_impact_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight">
          r3113 — Founder Calendar Energy & Decision-Quality Audit
        </h1>
        <p className="text-sm text-neutral-600">
          Quarterly audit: meeting type, prep quality, outcome, decision quality, interruptions,
          deep-work blocks, and delegate-vs-defend candidates across the founder calendar.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Quarterly headline summary</h2>
        <DataTable
          rows={summaryRows}
          columns={summaryCols}
          emptyMessage="No summary data."
          rowKey={(r, i) => String(r.metric ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Meeting-type rollup</h2>
        <DataTable
          rows={meetingTypeRows}
          columns={meetingTypeCols}
          emptyMessage="No meetings audited."
          rowKey={(r, i) => String(r.meeting_type ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Decision-quality distribution</h2>
        <DataTable
          rows={decisionRows}
          columns={decisionCols}
          emptyMessage="No decision-quality data."
          rowKey={(r, i) => String(r.decision_quality_rating ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Delegate / Defend / Kill candidates</h2>
        <DataTable
          rows={candidateRows}
          columns={candidateCols}
          emptyMessage="No candidate meetings flagged."
          rowKey={(r, i) => String(r.meeting_code ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Prep quality vs outcome</h2>
        <DataTable
          rows={prepRows}
          columns={prepCols}
          emptyMessage="No prep data."
          rowKey={(r, i) => String(r.prep_quality ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Deep-work block category rollup</h2>
        <DataTable
          rows={deepCategoryRows}
          columns={deepCategoryCols}
          emptyMessage="No deep-work blocks."
          rowKey={(r, i) => String(r.block_category ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Deep-work output quality breakdown</h2>
        <DataTable
          rows={outputRows}
          columns={outputCols}
          emptyMessage="No output-quality data."
          rowKey={(r, i) => String(r.output_quality ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Interruption hot-list (interrupts &gt;= 2 or switch cost &gt;= 10 min)</h2>
        <DataTable
          rows={interruptionRows}
          columns={interruptionCols}
          emptyMessage="No interruption-heavy blocks."
          rowKey={(r, i) => String(r.block_code ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-medium">Top meetings by revenue impact</h2>
        <DataTable
          rows={revenueRows}
          columns={revenueCols}
          emptyMessage="No revenue-impacting meetings."
          rowKey={(r, i) => String(r.meeting_code ?? i)}
        />
      </section>
    </main>
  );
}
