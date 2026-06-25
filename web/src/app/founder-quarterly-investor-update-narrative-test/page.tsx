import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_narratives: number;
  sent_count: number;
  approved_count: number;
  killed_count: number;
  avg_reaction_score: number | null;
  refine_send_pct: number | null;
};

type AudienceRow = {
  audience_segment: string;
  narrative_count: number;
  avg_word_count: number | null;
  sent_count: number;
};

type AngleRow = {
  narrative_angle: string;
  avg_score: number | null;
  strong_yes_count: number;
  strong_no_count: number;
};

type LeaderRow = {
  headline: string;
  pull_quote: string;
  audience_segment: string;
  avg_score: number | null;
};

type DecisionRow = {
  send_decision: string;
  decision_count: number;
  share_pct: number | null;
};

type RefineRow = {
  headline: string;
  reviewer_name: string;
  refinement_suggestion: string | null;
  send_decision: string;
  reviewed_at: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, audRes, angleRes, leaderRes, decisionRes, refineRes] = await Promise.all([
    supabase.rpc('narrative_test_kpi_r2769'),
    supabase.rpc('narratives_by_audience_r2769'),
    supabase.rpc('reactions_by_angle_r2769'),
    supabase.rpc('pull_quote_leaderboard_r2769'),
    supabase.rpc('send_decision_distribution_r2769'),
    supabase.rpc('refinements_pending_r2769'),
  ]);

  const kpi: KpiRow = (kpiRes.data?.[0] ?? {
    total_narratives: 0,
    sent_count: 0,
    approved_count: 0,
    killed_count: 0,
    avg_reaction_score: null,
    refine_send_pct: null,
  }) as KpiRow;
  const audiences: AudienceRow[] = (audRes.data ?? []) as AudienceRow[];
  const angles: AngleRow[] = (angleRes.data ?? []) as AngleRow[];
  const leaders: LeaderRow[] = (leaderRes.data ?? []) as LeaderRow[];
  const decisions: DecisionRow[] = (decisionRes.data ?? []) as DecisionRow[];
  const refines: RefineRow[] = (refineRes.data ?? []) as RefineRow[];

  const cards = [
    { label: 'Total narratives', value: kpi.total_narratives ?? 0 },
    { label: 'Sent', value: kpi.sent_count ?? 0 },
    { label: 'Approved (queue)', value: kpi.approved_count ?? 0 },
    { label: 'Killed', value: kpi.killed_count ?? 0 },
    { label: 'Avg reaction score', value: kpi.avg_reaction_score ?? 0 },
    { label: 'Refine-and-send %', value: kpi.refine_send_pct ?? 0 },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Quarterly Investor Update — Narrative Test</h1>
        <p className="text-sm text-muted-foreground">
          Audience × Narrative × Pull Quote × Reaction × Refine × Send Decision. Score &gt;=7
          flags a candidate; score &lt;=4 kills it. Round r2769.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-xl border p-4 bg-white">
            <div className="text-xs uppercase tracking-wide text-muted-foreground">{c.label}</div>
            <div className="text-2xl font-semibold mt-1">{String(c.value)}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Narratives by audience segment</h2>
        <DataTable
          rows={audiences}
          columns={[
            { key: 'audience_segment', header: 'Audience', render: (r: AudienceRow) => r.audience_segment },
            { key: 'narrative_count', header: 'Narratives', render: (r: AudienceRow) => String(r.narrative_count) },
            { key: 'avg_word_count', header: 'Avg words', render: (r: AudienceRow) => String(r.avg_word_count ?? '-') },
            { key: 'sent_count', header: 'Sent', render: (r: AudienceRow) => String(r.sent_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as AudienceRow).audience_segment ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Reactions by narrative angle</h2>
        <p className="text-xs text-muted-foreground">Higher avg score =&gt; angle resonates. Strong-no count =&gt; kill candidate.</p>
        <DataTable
          rows={angles}
          columns={[
            { key: 'narrative_angle', header: 'Angle', render: (r: AngleRow) => r.narrative_angle },
            { key: 'avg_score', header: 'Avg score', render: (r: AngleRow) => String(r.avg_score ?? '-') },
            { key: 'strong_yes_count', header: 'Strong yes', render: (r: AngleRow) => String(r.strong_yes_count) },
            { key: 'strong_no_count', header: 'Strong no', render: (r: AngleRow) => String(r.strong_no_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as AngleRow).narrative_angle ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pull-quote leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={[
            { key: 'headline', header: 'Headline', render: (r: LeaderRow) => r.headline },
            { key: 'pull_quote', header: 'Pull quote', render: (r: LeaderRow) => r.pull_quote },
            { key: 'audience_segment', header: 'Audience', render: (r: LeaderRow) => r.audience_segment },
            { key: 'avg_score', header: 'Avg score', render: (r: LeaderRow) => String(r.avg_score ?? '-') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as LeaderRow).headline ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Send-decision distribution</h2>
        <DataTable
          rows={decisions}
          columns={[
            { key: 'send_decision', header: 'Decision', render: (r: DecisionRow) => r.send_decision },
            { key: 'decision_count', header: 'Count', render: (r: DecisionRow) => String(r.decision_count) },
            { key: 'share_pct', header: 'Share %', render: (r: DecisionRow) => String(r.share_pct ?? '-') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as DecisionRow).send_decision ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pending refinements</h2>
        <p className="text-xs text-muted-foreground">Suggestions not yet applied — review & mark done.</p>
        <DataTable
          rows={refines}
          columns={[
            { key: 'headline', header: 'Headline', render: (r: RefineRow) => r.headline },
            { key: 'reviewer_name', header: 'Reviewer', render: (r: RefineRow) => r.reviewer_name },
            { key: 'refinement_suggestion', header: 'Suggestion', render: (r: RefineRow) => r.refinement_suggestion ?? '-' },
            { key: 'send_decision', header: 'Decision', render: (r: RefineRow) => r.send_decision },
            {
              key: 'reviewed_at',
              header: 'Reviewed',
              render: (r: RefineRow) => new Date(r.reviewed_at).toLocaleString('en-IN'),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as RefineRow).headline ?? i)}
        />
      </section>
    </div>
  );
}
