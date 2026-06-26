import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_entries: number;
  critical_stake: number;
  avg_candor: number;
  recurring_patterns: number;
  themes_count: number;
};

type FeedbackEntry = {
  id: string;
  quarter_label: string;
  feedback_giver: string;
  giver_role: string;
  feedback_theme: string;
  raw_quote: string;
  stake_for_founder: string;
  candor_score: number;
  pattern_recurrence: number;
  received_at: string;
};

type Adjustment = {
  id: string;
  quarter_label: string;
  adjustment_title: string;
  commit_action: string;
  commit_owner: string;
  commit_due: string;
  outcome_observed: string | null;
  measurable_delta: string | null;
  verdict: string;
  difficulty: number;
  reviewed_at: string | null;
};

type ThemeRow = {
  feedback_theme: string;
  entry_count: number;
  avg_candor: number;
  max_recurrence: number;
  critical_count: number;
};

type VerdictRow = {
  verdict: string;
  count: number;
  avg_difficulty: number;
};

type GiverRow = {
  giver_role: string;
  entry_count: number;
  avg_candor: number;
  high_stake_count: number;
};

type AdoptionRow = {
  quarter_label: string;
  total_adjustments: number;
  adopted_count: number;
  partial_count: number;
  rejected_count: number;
  pending_count: number;
  adoption_rate_pct: number;
};

type CriticalRow = {
  id: string;
  feedback_giver: string;
  feedback_theme: string;
  raw_quote: string;
  candor_score: number;
  pattern_recurrence: number;
  received_at: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, listRes, adjRes, themeRes, verdictRes, giverRes, adoptionRes, critRes] = await Promise.all([
    supabase.rpc('founder_leadership_feedback_summary_r2849'),
    supabase.rpc('founder_leadership_feedback_list_r2849'),
    supabase.rpc('founder_leadership_adjustments_list_r2849'),
    supabase.rpc('founder_leadership_theme_rollup_r2849'),
    supabase.rpc('founder_leadership_verdict_rollup_r2849'),
    supabase.rpc('founder_leadership_giver_rollup_r2849'),
    supabase.rpc('founder_leadership_adoption_rate_r2849'),
    supabase.rpc('founder_leadership_critical_open_r2849'),
  ]);

  const summary: Summary = (summaryRes.data?.[0] ?? {
    total_entries: 0,
    critical_stake: 0,
    avg_candor: 0,
    recurring_patterns: 0,
    themes_count: 0,
  }) as Summary;

  const entries: FeedbackEntry[] = (listRes.data ?? []) as FeedbackEntry[];
  const adjustments: Adjustment[] = (adjRes.data ?? []) as Adjustment[];
  const themes: ThemeRow[] = (themeRes.data ?? []) as ThemeRow[];
  const verdicts: VerdictRow[] = (verdictRes.data ?? []) as VerdictRow[];
  const givers: GiverRow[] = (giverRes.data ?? []) as GiverRow[];
  const adoption: AdoptionRow[] = (adoptionRes.data ?? []) as AdoptionRow[];
  const criticals: CriticalRow[] = (critRes.data ?? []) as CriticalRow[];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder Quarterly Personal Leadership Feedback</h1>
        <p className="text-sm text-gray-600">
          Round r2849 · Giver × theme × stake × adjustment × commit × outcome × verdict.
          Tracks raw, candid feedback from investors, advisors, engineers and customers; commits founder to concrete behavior change
          and measures whether the adjustment held over the quarter.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Total entries</div>
          <div className="text-2xl font-semibold">{summary.total_entries}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Critical stake</div>
          <div className="text-2xl font-semibold">{summary.critical_stake}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Avg candor (1-10)</div>
          <div className="text-2xl font-semibold">{summary.avg_candor}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Recurring patterns</div>
          <div className="text-2xl font-semibold">{summary.recurring_patterns}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Themes covered</div>
          <div className="text-2xl font-semibold">{summary.themes_count}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Critical & high-stake open feedback</h2>
        <DataTable
          rows={criticals}
          columns={[
            { key: 'feedback_giver', header: 'Giver', render: (r: CriticalRow) => <span>{r.feedback_giver}</span> },
            { key: 'feedback_theme', header: 'Theme', render: (r: CriticalRow) => <span>{r.feedback_theme}</span> },
            { key: 'raw_quote', header: 'Raw quote', render: (r: CriticalRow) => <span className="text-sm italic">{r.raw_quote}</span> },
            { key: 'candor_score', header: 'Candor', render: (r: CriticalRow) => <span>{r.candor_score}</span> },
            { key: 'pattern_recurrence', header: 'Recurrence', render: (r: CriticalRow) => <span>{r.pattern_recurrence}</span> },
            { key: 'received_at', header: 'Received', render: (r: CriticalRow) => <span>{r.received_at}</span> },
          ]}
          emptyMessage="No critical open feedback"
          rowKey={(r: CriticalRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All feedback entries</h2>
        <DataTable
          rows={entries}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: FeedbackEntry) => <span>{r.quarter_label}</span> },
            { key: 'feedback_giver', header: 'Giver', render: (r: FeedbackEntry) => <span>{r.feedback_giver}</span> },
            { key: 'giver_role', header: 'Role', render: (r: FeedbackEntry) => <span>{r.giver_role}</span> },
            { key: 'feedback_theme', header: 'Theme', render: (r: FeedbackEntry) => <span>{r.feedback_theme}</span> },
            { key: 'raw_quote', header: 'Quote', render: (r: FeedbackEntry) => <span className="text-sm">{r.raw_quote}</span> },
            { key: 'stake_for_founder', header: 'Stake', render: (r: FeedbackEntry) => <span>{r.stake_for_founder}</span> },
            { key: 'candor_score', header: 'Candor', render: (r: FeedbackEntry) => <span>{r.candor_score}</span> },
            { key: 'pattern_recurrence', header: 'Recur', render: (r: FeedbackEntry) => <span>{r.pattern_recurrence}</span> },
            { key: 'received_at', header: 'Received', render: (r: FeedbackEntry) => <span>{r.received_at}</span> },
          ]}
          emptyMessage="No feedback entries"
          rowKey={(r: FeedbackEntry, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Adjustments & commitments</h2>
        <DataTable
          rows={adjustments}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: Adjustment) => <span>{r.quarter_label}</span> },
            { key: 'adjustment_title', header: 'Adjustment', render: (r: Adjustment) => <span>{r.adjustment_title}</span> },
            { key: 'commit_action', header: 'Commit action', render: (r: Adjustment) => <span className="text-sm">{r.commit_action}</span> },
            { key: 'commit_owner', header: 'Owner', render: (r: Adjustment) => <span>{r.commit_owner}</span> },
            { key: 'commit_due', header: 'Due', render: (r: Adjustment) => <span>{r.commit_due}</span> },
            { key: 'outcome_observed', header: 'Outcome', render: (r: Adjustment) => <span className="text-sm">{r.outcome_observed ?? '-'}</span> },
            { key: 'measurable_delta', header: 'Delta', render: (r: Adjustment) => <span>{r.measurable_delta ?? '-'}</span> },
            { key: 'verdict', header: 'Verdict', render: (r: Adjustment) => <span>{r.verdict}</span> },
            { key: 'difficulty', header: 'Difficulty (1-5)', render: (r: Adjustment) => <span>{r.difficulty}</span> },
            { key: 'reviewed_at', header: 'Reviewed', render: (r: Adjustment) => <span>{r.reviewed_at ?? '-'}</span> },
          ]}
          emptyMessage="No adjustments tracked"
          rowKey={(r: Adjustment, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Theme rollup</h2>
          <DataTable
            rows={themes}
            columns={[
              { key: 'feedback_theme', header: 'Theme', render: (r: ThemeRow) => <span>{r.feedback_theme}</span> },
              { key: 'entry_count', header: 'Entries', render: (r: ThemeRow) => <span>{r.entry_count}</span> },
              { key: 'avg_candor', header: 'Avg candor', render: (r: ThemeRow) => <span>{r.avg_candor}</span> },
              { key: 'max_recurrence', header: 'Max recur', render: (r: ThemeRow) => <span>{r.max_recurrence}</span> },
              { key: 'critical_count', header: 'Critical', render: (r: ThemeRow) => <span>{r.critical_count}</span> },
            ]}
            emptyMessage="No theme data"
            rowKey={(r: ThemeRow, i: number) => String(r.feedback_theme ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Verdict rollup</h2>
          <DataTable
            rows={verdicts}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => <span>{r.verdict}</span> },
              { key: 'count', header: 'Count', render: (r: VerdictRow) => <span>{r.count}</span> },
              { key: 'avg_difficulty', header: 'Avg difficulty', render: (r: VerdictRow) => <span>{r.avg_difficulty}</span> },
            ]}
            emptyMessage="No verdict data"
            rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
          />
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Giver-role rollup</h2>
          <DataTable
            rows={givers}
            columns={[
              { key: 'giver_role', header: 'Role', render: (r: GiverRow) => <span>{r.giver_role}</span> },
              { key: 'entry_count', header: 'Entries', render: (r: GiverRow) => <span>{r.entry_count}</span> },
              { key: 'avg_candor', header: 'Avg candor', render: (r: GiverRow) => <span>{r.avg_candor}</span> },
              { key: 'high_stake_count', header: 'High+ stake', render: (r: GiverRow) => <span>{r.high_stake_count}</span> },
            ]}
            emptyMessage="No giver data"
            rowKey={(r: GiverRow, i: number) => String(r.giver_role ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Quarterly adoption rate</h2>
          <DataTable
            rows={adoption}
            columns={[
              { key: 'quarter_label', header: 'Quarter', render: (r: AdoptionRow) => <span>{r.quarter_label}</span> },
              { key: 'total_adjustments', header: 'Total', render: (r: AdoptionRow) => <span>{r.total_adjustments}</span> },
              { key: 'adopted_count', header: 'Adopted', render: (r: AdoptionRow) => <span>{r.adopted_count}</span> },
              { key: 'partial_count', header: 'Partial', render: (r: AdoptionRow) => <span>{r.partial_count}</span> },
              { key: 'rejected_count', header: 'Rejected', render: (r: AdoptionRow) => <span>{r.rejected_count}</span> },
              { key: 'pending_count', header: 'Pending', render: (r: AdoptionRow) => <span>{r.pending_count}</span> },
              { key: 'adoption_rate_pct', header: 'Rate %', render: (r: AdoptionRow) => <span>{r.adoption_rate_pct}</span> },
            ]}
            emptyMessage="No adoption data"
            rowKey={(r: AdoptionRow, i: number) => String(r.quarter_label ?? i)}
          />
        </div>
      </section>
    </div>
  );
}
