import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalOkrStretchVsRealityPage() {
  const supabase = await getSupabaseServerClient();

  const [okrsRes, lessonsRes, gradeRes, summaryRes, topLessonsRes, trendRes, statusRes] = await Promise.all([
    supabase.rpc('list_personal_okrs_r2505'),
    supabase.rpc('list_lessons_log_r2505'),
    supabase.rpc('grade_distribution_r2505'),
    supabase.rpc('stretch_vs_realistic_summary_r2505'),
    supabase.rpc('top_lessons_r2505'),
    supabase.rpc('quarterly_trend_r2505'),
    supabase.rpc('status_breakdown_r2505'),
  ]);

  const okrs = (okrsRes.data ?? []) as any[];
  const lessons = (lessonsRes.data ?? []) as any[];
  const grades = (gradeRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const topLessons = (topLessonsRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const statusRows = (statusRes.data ?? []) as any[];

  const okrCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'okr_name', header: 'OKR', render: (r: any) => r.okr_name },
    { key: 'kr_text', header: 'Key Result', render: (r: any) => r.kr_text },
    { key: 'stretch_target', header: 'Stretch', render: (r: any) => String(r.stretch_target) },
    { key: 'realistic_target', header: 'Realistic', render: (r: any) => String(r.realistic_target) },
    { key: 'actual_value', header: 'Actual', render: (r: any) => String(r.actual_value) },
    { key: 'delta_to_stretch_pct', header: 'Δ Stretch %', render: (r: any) => String(r.delta_to_stretch_pct) },
    { key: 'delta_to_realistic_pct', header: 'Δ Realistic %', render: (r: any) => String(r.delta_to_realistic_pct) },
    { key: 'honest_grade', header: 'Grade', render: (r: any) => r.honest_grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'lessons_md', header: 'Lessons', render: (r: any) => r.lessons_md ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'lesson_kind', header: 'Kind', render: (r: any) => r.lesson_kind },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md },
    { key: 'action_to_apply', header: 'Action To Apply', render: (r: any) => r.action_to_apply },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'honest_grade', header: 'Grade', render: (r: any) => r.honest_grade },
    { key: 'okr_count', header: 'OKRs', render: (r: any) => String(r.okr_count) },
    { key: 'pct_of_total', header: '% of Total', render: (r: any) => String(r.pct_of_total) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric },
    { key: 'value', header: 'Value', render: (r: any) => String(r.value) },
  ];

  const topLessonsCols: Column<any>[] = [
    { key: 'lesson_kind', header: 'Kind', render: (r: any) => r.lesson_kind },
    { key: 'lesson_count', header: 'Count', render: (r: any) => String(r.lesson_count) },
    { key: 'open_or_in_progress', header: 'Open / In Progress', render: (r: any) => String(r.open_or_in_progress) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'okr_count', header: 'OKRs', render: (r: any) => String(r.okr_count) },
    { key: 'avg_delta_realistic_pct', header: 'Avg Δ Realistic %', render: (r: any) => String(r.avg_delta_realistic_pct) },
    { key: 'hit_realistic_pct', header: 'Hit Realistic %', render: (r: any) => String(r.hit_realistic_pct) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'okr_count', header: 'OKRs', render: (r: any) => String(r.okr_count) },
    { key: 'pct_of_total', header: '% of Total', render: (r: any) => String(r.pct_of_total) },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 600, marginBottom: '0.5rem' }}>
        Founder Personal OKR — Stretch vs Reality
      </h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        Honest self-grading: stretch target vs realistic target vs actual. Lessons logged to apply forward.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No summary."
          rowKey={(r: any, i: number) => String(r.metric ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Grade Distribution</h2>
        <DataTable
          rows={grades}
          columns={gradeCols}
          emptyMessage="No grades."
          rowKey={(r: any, i: number) => String(r.honest_grade ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Status Breakdown</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No status breakdown."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Quarterly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top Lesson Kinds</h2>
        <DataTable
          rows={topLessons}
          columns={topLessonsCols}
          emptyMessage="No lessons categorized."
          rowKey={(r: any, i: number) => String(r.lesson_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Personal OKRs</h2>
        <DataTable
          rows={okrs}
          columns={okrCols}
          emptyMessage="No personal OKRs logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Lessons Log</h2>
        <DataTable
          rows={lessons}
          columns={lessonCols}
          emptyMessage="No lessons logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
