import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LatestMemo = {
  id: number;
  memo_title: string;
  ships_total: number;
  written_at: string;
  phase_label: string;
  reflection_body: string;
  vision_next_1500: string;
  pinned: boolean;
};

type MemoRow = {
  id: number;
  memo_title: string;
  ships_total: number;
  written_at: string;
  phase_label: string;
  pinned: boolean;
  lesson_count: number;
};

type LessonRow = {
  id: number;
  lesson_rank: number;
  lesson_category: string;
  lesson_title: string;
  lesson_body: string;
  ships_range: string | null;
  severity: string;
};

type CategoryRow = {
  lesson_category: string;
  lesson_count: number;
  critical_count: number;
  high_count: number;
};

type TopLessonRow = {
  lesson_rank: number;
  lesson_category: string;
  lesson_title: string;
  severity: string;
  ships_range: string | null;
};

type SeverityRow = {
  severity: string;
  lesson_count: number;
  pct_of_total: number;
};

type SummaryRow = {
  total_memos: number;
  total_lessons: number;
  critical_lessons: number;
  high_lessons: number;
  latest_phase: string;
  latest_ships_total: number;
};

export default async function Founder1500ShipsMilestoneMemoPage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? null;

  const [latestRes, memosRes, topRes, catRes, sevRes, summaryRes] = await Promise.all([
    supabase.rpc('founder_1500_ships_milestone_memo_r2329_latest'),
    supabase.rpc('founder_1500_ships_milestone_memo_r2329_list_memos', { p_limit: 20 }),
    supabase.rpc('founder_1500_ships_milestone_memo_r2329_top_lessons', { p_limit: 12 }),
    supabase.rpc('founder_1500_ships_milestone_memo_r2329_lessons_by_category'),
    supabase.rpc('founder_1500_ships_milestone_memo_r2329_severity_mix'),
    supabase.rpc('founder_1500_ships_milestone_memo_r2329_summary'),
  ]);

  const latest = (latestRes.data?.[0] ?? null) as LatestMemo | null;
  const memos = (memosRes.data ?? []) as MemoRow[];
  const topLessons = (topRes.data ?? []) as TopLessonRow[];
  const categories = (catRes.data ?? []) as CategoryRow[];
  const severities = (sevRes.data ?? []) as SeverityRow[];
  const summary = (summaryRes.data?.[0] ?? null) as SummaryRow | null;

  let lessons: LessonRow[] = [];
  if (latest?.id) {
    const lessonsRes = await supabase.rpc(
      'founder_1500_ships_milestone_memo_r2329_list_lessons',
      { p_memo_id: latest.id },
    );
    lessons = (lessonsRes.data ?? []) as LessonRow[];
  }

  const anyError = latestRes.error || memosRes.error || topRes.error || catRes.error || sevRes.error || summaryRes.error;

  const memoCols: Column<MemoRow>[] = [
    { key: 'memo_title', header: 'Memo', render: (r) => r.memo_title },
    { key: 'phase_label', header: 'Phase', render: (r) => r.phase_label },
    { key: 'ships_total', header: 'Ships', render: (r) => r.ships_total },
    { key: 'lesson_count', header: 'Lessons', render: (r) => r.lesson_count },
    { key: 'pinned', header: 'Pinned', render: (r) => (r.pinned ? 'yes' : 'no') },
    { key: 'written_at', header: 'Written', render: (r) => new Date(r.written_at).toLocaleString() },
  ];

  const lessonCols: Column<LessonRow>[] = [
    { key: 'lesson_rank', header: '#', render: (r) => r.lesson_rank },
    { key: 'lesson_title', header: 'Lesson', render: (r) => r.lesson_title },
    { key: 'lesson_category', header: 'Category', render: (r) => r.lesson_category },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'ships_range', header: 'Ships Range', render: (r) => r.ships_range ?? '-' },
    { key: 'lesson_body', header: 'Detail', render: (r) => <span className="text-[var(--color-muted)]">{r.lesson_body}</span> },
  ];

  const topCols: Column<TopLessonRow>[] = [
    { key: 'lesson_rank', header: '#', render: (r) => r.lesson_rank },
    { key: 'lesson_title', header: 'Lesson', render: (r) => r.lesson_title },
    { key: 'lesson_category', header: 'Category', render: (r) => r.lesson_category },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'ships_range', header: 'Ships Range', render: (r) => r.ships_range ?? '-' },
  ];

  const catCols: Column<CategoryRow>[] = [
    { key: 'lesson_category', header: 'Category', render: (r) => r.lesson_category },
    { key: 'lesson_count', header: 'Lessons', render: (r) => r.lesson_count },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'high_count', header: 'High', render: (r) => r.high_count },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'lesson_count', header: 'Count', render: (r) => r.lesson_count },
    { key: 'pct_of_total', header: '% of Total', render: (r) => `${r.pct_of_total}%` },
  ];

  return (
    <main className="mx-auto max-w-6xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">1500 Ships Milestone Memo</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Reflection on hitting 1500 ships, top distinct lessons across phases,
          and the next-1500 vision. Founder console only.
        </p>
        {email ? <p className="text-xs text-[var(--color-muted)]">Viewing as {email}</p> : null}
      </header>

      {anyError ? (
        <div className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-900">
          One or more RPCs returned an error. If you are not the founder this is expected.
        </div>
      ) : null}

      {summary ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
          <Kpi label="Memos" value={summary.total_memos} />
          <Kpi label="Lessons" value={summary.total_lessons} />
          <Kpi label="Critical" value={summary.critical_lessons} />
          <Kpi label="High" value={summary.high_lessons} />
          <Kpi label="Phase" value={summary.latest_phase} />
          <Kpi label="Ships" value={summary.latest_ships_total} />
        </section>
      ) : null}

      {latest ? (
        <section className="space-y-3 rounded border border-[var(--color-border)] bg-white p-5">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 className="text-xl font-semibold">{latest.memo_title}</h2>
            <span className="text-xs text-[var(--color-muted)]">
              {latest.phase_label} · {latest.ships_total} ships · {new Date(latest.written_at).toLocaleString()}
            </span>
          </div>
          <div>
            <h3 className="text-sm font-medium uppercase tracking-wider text-[var(--color-muted)]">Reflection</h3>
            <p className="mt-1 whitespace-pre-line text-sm leading-relaxed">{latest.reflection_body}</p>
          </div>
          <div>
            <h3 className="text-sm font-medium uppercase tracking-wider text-[var(--color-muted)]">Vision: next 1500</h3>
            <p className="mt-1 whitespace-pre-line text-sm leading-relaxed">{latest.vision_next_1500}</p>
          </div>
        </section>
      ) : (
        <div className="rounded border border-dashed border-[var(--color-border)] bg-white p-6 text-center text-sm text-[var(--color-muted)]">
          No milestone memo recorded yet.
        </div>
      )}

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top distinct lessons</h2>
        <DataTable<TopLessonRow>
          columns={topCols}
          rows={topLessons}
          rowKey={(r) => `top-${r.lesson_rank}-${r.lesson_title}`}
          emptyMessage="No top lessons surfaced."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All lessons (current memo)</h2>
        <DataTable<LessonRow>
          columns={lessonCols}
          rows={lessons}
          rowKey={(r) => `lesson-${r.id}`}
          emptyMessage="No lessons recorded for the latest memo."
        />
      </section>

      <section className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Lessons by category</h2>
          <DataTable<CategoryRow>
            columns={catCols}
            rows={categories}
            rowKey={(r) => `cat-${r.lesson_category}`}
            emptyMessage="No category counts yet."
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Severity mix</h2>
          <DataTable<SeverityRow>
            columns={sevCols}
            rows={severities}
            rowKey={(r) => `sev-${r.severity}`}
            emptyMessage="No severity mix yet."
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Memo history</h2>
        <DataTable<MemoRow>
          columns={memoCols}
          rows={memos}
          rowKey={(r) => `memo-${r.id}`}
          emptyMessage="No memo history."
        />
      </section>
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded border border-[var(--color-border)] bg-white p-3">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-lg font-semibold">{value}</div>
    </div>
  );
}
