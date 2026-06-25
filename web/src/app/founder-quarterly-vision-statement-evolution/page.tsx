import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_statements: number;
  published_count: number;
  avg_clarity_score: number | null;
  total_reactions: number;
  adoption_rate_pct: number | null;
  recall_rate_pct: number | null;
  avg_refinement_rounds: number | null;
};

type Statement = {
  id: string;
  quarter: string;
  version_number: number;
  draft_text: string;
  refined_text: string | null;
  clarity_score: number;
  word_count: number;
  status: string;
  audience_segment: string;
  refinement_round: number;
  authored_by: string;
  created_at: string;
  published_at: string | null;
};

type ClarityRow = {
  quarter: string;
  versions_count: number;
  avg_clarity: number;
  max_clarity: number;
  best_version_text: string;
};

type ReactionBreakdown = {
  audience_role: string;
  total_reactions: number;
  positive_count: number;
  negative_count: number;
  avg_clarity_rating: number;
  avg_resonance_rating: number;
  adoption_pct: number | null;
};

type TimelineRow = {
  quarter: string;
  version_number: number;
  refinement_round: number;
  draft_word_count: number;
  refined_word_count: number;
  clarity_score: number;
  status: string;
};

type TopAdopted = {
  quarter: string;
  version_number: number;
  statement_text: string;
  total_reactions: number;
  adopted_count: number;
  recall_count: number;
  avg_resonance: number | null;
};

type ReactionRow = {
  reaction_id: string;
  quarter: string;
  version_number: number;
  audience_member: string;
  audience_role: string;
  reaction_sentiment: string;
  clarity_rating: number;
  resonance_rating: number;
  adopted: boolean;
  recall_after_week: boolean;
  feedback_text: string | null;
  reaction_at: string;
};

type StatusRow = {
  status: string;
  statement_count: number;
  avg_clarity: number;
  avg_refinement_rounds: number;
  latest_quarter: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, stmtRes, clarityRes, breakdownRes, timelineRes, topRes, reactionsRes, statusRes] = await Promise.all([
    supabase.rpc('founder_vision_kpis_r2721'),
    supabase.rpc('founder_list_vision_statements_r2721'),
    supabase.rpc('founder_vision_clarity_by_quarter_r2721'),
    supabase.rpc('founder_vision_reactions_breakdown_r2721'),
    supabase.rpc('founder_vision_refinement_timeline_r2721'),
    supabase.rpc('founder_vision_top_adopted_r2721'),
    supabase.rpc('founder_vision_reactions_list_r2721'),
    supabase.rpc('founder_vision_status_pipeline_r2721'),
  ]);

  const kpi: Kpi | null = (kpiRes.data as Kpi[] | null)?.[0] ?? null;
  const statements: Statement[] = (stmtRes.data as Statement[] | null) ?? [];
  const clarity: ClarityRow[] = (clarityRes.data as ClarityRow[] | null) ?? [];
  const breakdown: ReactionBreakdown[] = (breakdownRes.data as ReactionBreakdown[] | null) ?? [];
  const timeline: TimelineRow[] = (timelineRes.data as TimelineRow[] | null) ?? [];
  const top: TopAdopted[] = (topRes.data as TopAdopted[] | null) ?? [];
  const reactions: ReactionRow[] = (reactionsRes.data as ReactionRow[] | null) ?? [];
  const statuses: StatusRow[] = (statusRes.data as StatusRow[] | null) ?? [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Quarterly Vision Statement Evolution</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track vision draft versions, audience reactions, refinements, clarity scores & adoption across quarters.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <KpiCard label="Total Statements" value={kpi?.total_statements ?? 0} />
        <KpiCard label="Published" value={kpi?.published_count ?? 0} />
        <KpiCard label="Avg Clarity (0-10)" value={kpi?.avg_clarity_score ?? 0} />
        <KpiCard label="Total Reactions" value={kpi?.total_reactions ?? 0} />
        <KpiCard label="Adoption Rate %" value={kpi?.adoption_rate_pct ?? 0} />
        <KpiCard label="1-Week Recall %" value={kpi?.recall_rate_pct ?? 0} />
        <KpiCard label="Avg Refinement Rounds" value={kpi?.avg_refinement_rounds ?? 0} />
        <KpiCard label="Quarters Tracked" value={clarity.length} />
      </div>

      <Section title="Vision Statements (versions & drafts)">
        <DataTable<Statement>
          rows={statements}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
            { key: 'version_number', header: 'Ver', render: (r) => String(r.version_number) },
            { key: 'draft_text', header: 'Draft', render: (r) => r.draft_text },
            { key: 'refined_text', header: 'Refined', render: (r) => r.refined_text ?? '—' },
            { key: 'clarity_score', header: 'Clarity', render: (r) => Number(r.clarity_score).toFixed(2) },
            { key: 'word_count', header: 'Words', render: (r) => String(r.word_count) },
            { key: 'status', header: 'Status', render: (r) => r.status },
            { key: 'audience_segment', header: 'Audience', render: (r) => r.audience_segment },
            { key: 'refinement_round', header: 'Refine #', render: (r) => String(r.refinement_round) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Clarity by Quarter">
        <DataTable<ClarityRow>
          rows={clarity}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
            { key: 'versions_count', header: 'Versions', render: (r) => String(r.versions_count) },
            { key: 'avg_clarity', header: 'Avg Clarity', render: (r) => Number(r.avg_clarity).toFixed(2) },
            { key: 'max_clarity', header: 'Max Clarity', render: (r) => Number(r.max_clarity).toFixed(2) },
            { key: 'best_version_text', header: 'Best Version', render: (r) => r.best_version_text },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.quarter ?? i)}
        />
      </Section>

      <Section title="Audience Reaction Breakdown">
        <DataTable<ReactionBreakdown>
          rows={breakdown}
          columns={[
            { key: 'audience_role', header: 'Role', render: (r) => r.audience_role },
            { key: 'total_reactions', header: 'Total', render: (r) => String(r.total_reactions) },
            { key: 'positive_count', header: 'Positive', render: (r) => String(r.positive_count) },
            { key: 'negative_count', header: 'Negative', render: (r) => String(r.negative_count) },
            { key: 'avg_clarity_rating', header: 'Avg Clarity (1-10)', render: (r) => Number(r.avg_clarity_rating).toFixed(2) },
            { key: 'avg_resonance_rating', header: 'Avg Resonance (1-10)', render: (r) => Number(r.avg_resonance_rating).toFixed(2) },
            { key: 'adoption_pct', header: 'Adoption %', render: (r) => (r.adoption_pct ?? 0) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.audience_role ?? i)}
        />
      </Section>

      <Section title="Refinement Evolution Timeline">
        <DataTable<TimelineRow>
          rows={timeline}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
            { key: 'version_number', header: 'Ver', render: (r) => String(r.version_number) },
            { key: 'refinement_round', header: 'Refine #', render: (r) => String(r.refinement_round) },
            { key: 'draft_word_count', header: 'Draft Words', render: (r) => String(r.draft_word_count) },
            { key: 'refined_word_count', header: 'Refined Words', render: (r) => String(r.refined_word_count) },
            { key: 'clarity_score', header: 'Clarity', render: (r) => Number(r.clarity_score).toFixed(2) },
            { key: 'status', header: 'Status', render: (r) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Top Adopted Statements">
        <DataTable<TopAdopted>
          rows={top}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
            { key: 'version_number', header: 'Ver', render: (r) => String(r.version_number) },
            { key: 'statement_text', header: 'Statement', render: (r) => r.statement_text },
            { key: 'total_reactions', header: 'Reactions', render: (r) => String(r.total_reactions) },
            { key: 'adopted_count', header: 'Adopted', render: (r) => String(r.adopted_count) },
            { key: 'recall_count', header: 'Recalled 1-Week', render: (r) => String(r.recall_count) },
            { key: 'avg_resonance', header: 'Avg Resonance', render: (r) => r.avg_resonance != null ? Number(r.avg_resonance).toFixed(2) : '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Status Pipeline">
        <DataTable<StatusRow>
          rows={statuses}
          columns={[
            { key: 'status', header: 'Status', render: (r) => r.status },
            { key: 'statement_count', header: 'Count', render: (r) => String(r.statement_count) },
            { key: 'avg_clarity', header: 'Avg Clarity', render: (r) => Number(r.avg_clarity).toFixed(2) },
            { key: 'avg_refinement_rounds', header: 'Avg Refine Rounds', render: (r) => Number(r.avg_refinement_rounds).toFixed(2) },
            { key: 'latest_quarter', header: 'Latest Quarter', render: (r) => r.latest_quarter },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.status ?? i)}
        />
      </Section>

      <Section title="All Reactions">
        <DataTable<ReactionRow>
          rows={reactions}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
            { key: 'version_number', header: 'Ver', render: (r) => String(r.version_number) },
            { key: 'audience_member', header: 'Member', render: (r) => r.audience_member },
            { key: 'audience_role', header: 'Role', render: (r) => r.audience_role },
            { key: 'reaction_sentiment', header: 'Sentiment', render: (r) => r.reaction_sentiment },
            { key: 'clarity_rating', header: 'Clarity', render: (r) => String(r.clarity_rating) },
            { key: 'resonance_rating', header: 'Resonance', render: (r) => String(r.resonance_rating) },
            { key: 'adopted', header: 'Adopted', render: (r) => r.adopted ? 'yes' : 'no' },
            { key: 'recall_after_week', header: 'Recall 1w', render: (r) => r.recall_after_week ? 'yes' : 'no' },
            { key: 'feedback_text', header: 'Feedback', render: (r) => r.feedback_text ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.reaction_id ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-xl font-semibold mt-1">{value}</div>
    </div>
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
