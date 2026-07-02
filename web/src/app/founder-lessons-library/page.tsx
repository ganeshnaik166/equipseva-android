import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderLessonsLibraryPage() {
  const sb = await getSupabaseServerClient();

  const [lessonsRes, refsRes, catsRes, recentRes] = await Promise.all([
    sb.rpc('list_lessons_r2010', { p_status: null, p_category: null }),
    sb.rpc('list_references_r2010', { p_lesson_id: null }),
    sb.rpc('top_categories_r2010'),
    sb.rpc('recent_references_r2010', { p_limit: 25 }),
  ]);

  const lessons = (lessonsRes.data ?? []) as any[];
  const refs = (refsRes.data ?? []) as any[];
  const cats = (catsRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const lessonCols: Column<any>[] = [
    { key: 'lesson_label', header: 'Lesson', render: (r: any) => String(r.lesson_label ?? '') },
    { key: 'lesson_category', header: 'Category', render: (r: any) => String(r.lesson_category ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'lesson_md', header: 'Detail', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.lesson_md ?? '').slice(0, 240)}</span> },
    { key: 'source_event_md', header: 'Source', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.source_event_md ?? '').slice(0, 160)}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const refCols: Column<any>[] = [
    { key: 'lesson_label', header: 'Lesson', render: (r: any) => String(r.lesson_label ?? '') },
    { key: 'reference_context_md', header: 'Context', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.reference_context_md ?? '').slice(0, 200)}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.outcome_md ?? '').slice(0, 160)}</span> },
    { key: 'referenced_at', header: 'When', render: (r: any) => r.referenced_at ? new Date(r.referenced_at).toLocaleString() : '' },
  ];

  const catCols: Column<any>[] = [
    { key: 'lesson_category', header: 'Category', render: (r: any) => String(r.lesson_category ?? '') },
    { key: 'lesson_count', header: 'Total', render: (r: any) => String(r.lesson_count ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'last_captured_at', header: 'Last captured', render: (r: any) => r.last_captured_at ? new Date(r.last_captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'lesson_label', header: 'Lesson', render: (r: any) => String(r.lesson_label ?? '') },
    { key: 'lesson_category', header: 'Category', render: (r: any) => String(r.lesson_category ?? '') },
    { key: 'reference_context_md', header: 'Context', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.reference_context_md ?? '').slice(0, 200)}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'referenced_at', header: 'When', render: (r: any) => r.referenced_at ? new Date(r.referenced_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Founder Lessons Library</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Searchable library of lessons captured from sales, hiring, product, financial, operational, personal, strategy and marketing events. Track when lessons get referenced and what outcome they drove.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Categories overview</h2>
        <DataTable rows={cats} columns={catCols} rowKey={(r: any, i: number) => String(r.lesson_category ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Lessons</h2>
        <DataTable rows={lessons} columns={lessonCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent references</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All reference log</h2>
        <DataTable rows={refs} columns={refCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
