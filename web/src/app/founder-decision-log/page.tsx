import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type DecisionRow = {
  id: string;
  decision_date: string;
  decision_title: string;
  category: string;
  has_actual_outcome: boolean;
  outcome_recorded_at: string | null;
  review_count: number;
  correct_count: number;
  incorrect_count: number;
  created_at: string;
};

type DistributionRow = {
  category: string;
  total_decisions: number;
  with_outcome: number;
  correct_count: number;
  incorrect_count: number;
  mixed_count: number;
  too_early_count: number;
};

type LessonRow = {
  id: string;
  decision_date: string;
  decision_title: string;
  category: string;
  lesson_md: string;
  outcome_recorded_at: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [decisionsRes, distributionRes, lessonsRes] = await Promise.all([
    sb.rpc('list_decisions_r1714'),
    sb.rpc('judgment_distribution_r1714'),
    sb.rpc('recent_lessons_r1714'),
  ]);

  const decisions: DecisionRow[] = (decisionsRes.data as DecisionRow[] | null) ?? [];
  const distribution: DistributionRow[] = (distributionRes.data as DistributionRow[] | null) ?? [];
  const lessons: LessonRow[] = (lessonsRes.data as LessonRow[] | null) ?? [];

  const decisionCols: Column<DecisionRow>[] = [
    { key: 'decision_date', header: 'Date', render: (r: any) => r.decision_date ?? '—' },
    { key: 'decision_title', header: 'Title', render: (r: any) => r.decision_title },
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'has_actual_outcome', header: 'Outcome recorded', render: (r: any) => (r.has_actual_outcome ? 'yes' : 'no') },
    { key: 'outcome_recorded_at', header: 'Recorded at', render: (r: any) => r.outcome_recorded_at ?? '—' },
    { key: 'review_count', header: 'Reviews', render: (r: any) => r.review_count },
    { key: 'correct_count', header: 'Correct', render: (r: any) => r.correct_count },
    { key: 'incorrect_count', header: 'Incorrect', render: (r: any) => r.incorrect_count },
  ];

  const distributionCols: Column<DistributionRow>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'total_decisions', header: 'Total', render: (r: any) => r.total_decisions },
    { key: 'with_outcome', header: 'With outcome', render: (r: any) => r.with_outcome },
    { key: 'correct_count', header: 'Correct', render: (r: any) => r.correct_count },
    { key: 'incorrect_count', header: 'Incorrect', render: (r: any) => r.incorrect_count },
    { key: 'mixed_count', header: 'Mixed', render: (r: any) => r.mixed_count },
    { key: 'too_early_count', header: 'Too early', render: (r: any) => r.too_early_count },
  ];

  const lessonCols: Column<LessonRow>[] = [
    { key: 'decision_date', header: 'Date', render: (r: any) => r.decision_date ?? '—' },
    { key: 'decision_title', header: 'Decision', render: (r: any) => r.decision_title },
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md },
    { key: 'outcome_recorded_at', header: 'Recorded at', render: (r: any) => r.outcome_recorded_at ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Decision Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Capture major founder decisions with context, options considered, and expected outcome. Record actual outcome later and judge whether the call was correct, incorrect, mixed, or too early.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Decisions ({decisions.length})</h2>
        <DataTable
          rows={decisions}
          columns={decisionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Judgment distribution by category ({distribution.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Across product, people, finance, strategy, legal, and ops. Higher correct counts indicate stronger judgment in that lane.
        </p>
        <DataTable
          rows={distribution}
          columns={distributionCols}
          rowKey={(r: any, i: number) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent lessons ({lessons.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Lessons captured after outcomes were recorded. Review weekly to compound founder judgment.
        </p>
        <DataTable
          rows={lessons}
          columns={lessonCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
