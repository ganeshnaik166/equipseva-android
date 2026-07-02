import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type DifficultyRow = { difficulty: string; question_count: number; avg_confidence: number; battle_ready_count: number };
type CategoryRow = { category: string; total: number; ready: number; drafting: number; avg_conf: number };
type GapRow = { question_code: string; question_text: string; category: string; confidence_score: number; prep_status: string };
type RehearsalRow = { question_code: string; headline: string; rehearsal_count: number; approval_status: string; last_rehearsed: string | null };
type ArchetypeRow = { asker_archetype: string; question_count: number; battle_ready: number; avg_difficulty_rank: number };
type QuarterRow = { expected_in_quarter: string; total: number; battle_ready: number; not_started: number; readiness_pct: number };
type FunnelRow = { approval_status: string; answer_count: number; avg_word_count: number; avg_rehearsals: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [diff, cat, gaps, rehearsal, archetype, quarter, funnel] = await Promise.all([
    sb.rpc('r2957_questions_by_difficulty'),
    sb.rpc('r2957_questions_by_category'),
    sb.rpc('r2957_low_confidence_gaps'),
    sb.rpc('r2957_rehearsal_leaderboard'),
    sb.rpc('r2957_archetype_coverage'),
    sb.rpc('r2957_quarter_readiness'),
    sb.rpc('r2957_answer_approval_funnel'),
  ]);

  const diffCols: Column<DifficultyRow>[] = [
    { header: 'Difficulty', accessor: (r) => r.difficulty },
    { header: 'Questions', accessor: (r) => r.question_count },
    { header: 'Avg Confidence', accessor: (r) => r.avg_confidence },
    { header: 'Battle Ready', accessor: (r) => r.battle_ready_count },
  ];

  const catCols: Column<CategoryRow>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Ready', accessor: (r) => r.ready },
    { header: 'Drafting', accessor: (r) => r.drafting },
    { header: 'Avg Conf', accessor: (r) => r.avg_conf },
  ];

  const gapCols: Column<GapRow>[] = [
    { header: 'Code', accessor: (r) => r.question_code },
    { header: 'Question', accessor: (r) => r.question_text },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Confidence', accessor: (r) => r.confidence_score },
    { header: 'Status', accessor: (r) => r.prep_status },
  ];

  const rehearsalCols: Column<RehearsalRow>[] = [
    { header: 'Code', accessor: (r) => r.question_code },
    { header: 'Headline', accessor: (r) => r.headline },
    { header: 'Rehearsals', accessor: (r) => r.rehearsal_count },
    { header: 'Approval', accessor: (r) => r.approval_status },
    { header: 'Last Rehearsed', accessor: (r) => r.last_rehearsed ?? '-' },
  ];

  const archetypeCols: Column<ArchetypeRow>[] = [
    { header: 'Archetype', accessor: (r) => r.asker_archetype },
    { header: 'Questions', accessor: (r) => r.question_count },
    { header: 'Battle Ready', accessor: (r) => r.battle_ready },
    { header: 'Avg Difficulty Rank', accessor: (r) => r.avg_difficulty_rank },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.expected_in_quarter },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Battle Ready', accessor: (r) => r.battle_ready },
    { header: 'Not Started', accessor: (r) => r.not_started },
    { header: 'Readiness %', accessor: (r) => r.readiness_pct },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { header: 'Approval Status', accessor: (r) => r.approval_status },
    { header: 'Answers', accessor: (r) => r.answer_count },
    { header: 'Avg Word Count', accessor: (r) => r.avg_word_count },
    { header: 'Avg Rehearsals', accessor: (r) => r.avg_rehearsals },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Investor Quarterly-Call Q&A Prep Drillbook</h1>
        <p className="text-sm text-gray-600">Round 2957 — battle-ready answers for every adversarial question.</p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Questions by Difficulty</h2>
        <DataTable<DifficultyRow>
          rows={(diff.data ?? []) as DifficultyRow[]}
          columns={diffCols}
          emptyMessage="No difficulty data"
          rowKey={(r, i) => String(r.difficulty ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Questions by Category (lowest confidence first)</h2>
        <DataTable<CategoryRow>
          rows={(cat.data ?? []) as CategoryRow[]}
          columns={catCols}
          emptyMessage="No category data"
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Low-Confidence Gaps (score &lt;= 6)</h2>
        <DataTable<GapRow>
          rows={(gaps.data ?? []) as GapRow[]}
          columns={gapCols}
          emptyMessage="No gaps"
          rowKey={(r, i) => String(r.question_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rehearsal Leaderboard</h2>
        <DataTable<RehearsalRow>
          rows={(rehearsal.data ?? []) as RehearsalRow[]}
          columns={rehearsalCols}
          emptyMessage="No rehearsal data"
          rowKey={(r, i) => String(r.question_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Archetype Coverage</h2>
        <DataTable<ArchetypeRow>
          rows={(archetype.data ?? []) as ArchetypeRow[]}
          columns={archetypeCols}
          emptyMessage="No archetype data"
          rowKey={(r, i) => String(r.asker_archetype ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Readiness</h2>
        <DataTable<QuarterRow>
          rows={(quarter.data ?? []) as QuarterRow[]}
          columns={quarterCols}
          emptyMessage="No quarter data"
          rowKey={(r, i) => String(r.expected_in_quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Answer Approval Funnel</h2>
        <DataTable<FunnelRow>
          rows={(funnel.data ?? []) as FunnelRow[]}
          columns={funnelCols}
          emptyMessage="No funnel data"
          rowKey={(r, i) => String(r.approval_status ?? i)}
        />
      </section>
    </div>
  );
}
