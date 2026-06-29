import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type PromiseRow = { promise_code: string; promise_text: string; category: string; status: string; honesty_grade: string; progress_percent: number | null };
type StatusRow = { status: string; promise_count: number; avg_progress: number | null };
type GradeRow = { honesty_grade: string; promise_count: number; category_breakdown: string | null };
type SeverityRow = { severity: string; finding_count: number; open_count: number };
type FindingRow = { finding_code: string; letter_year: number; finding_type: string; passage: string; reality: string; recommendation: string | null };
type CategoryRow = { category: string; promise_count: number; avg_progress: number | null; on_track_count: number };
type YearRow = { letter_year: number; total_findings: number; accurate_count: number; overstatement_count: number; accuracy_pct: number | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [scorecard, status, grade, severity, openCrit, cat, yr] = await Promise.all([
    sb.rpc('f_r3037_promise_scorecard'),
    sb.rpc('f_r3037_status_distribution'),
    sb.rpc('f_r3037_honesty_grade_distribution'),
    sb.rpc('f_r3037_findings_by_severity'),
    sb.rpc('f_r3037_open_critical_findings'),
    sb.rpc('f_r3037_category_honesty'),
    sb.rpc('f_r3037_year_accuracy'),
  ]);

  const scorecardRows = (scorecard.data ?? []) as PromiseRow[];
  const statusRows = (status.data ?? []) as StatusRow[];
  const gradeRows = (grade.data ?? []) as GradeRow[];
  const severityRows = (severity.data ?? []) as SeverityRow[];
  const openCritRows = (openCrit.data ?? []) as FindingRow[];
  const catRows = (cat.data ?? []) as CategoryRow[];
  const yrRows = (yr.data ?? []) as YearRow[];

  const scorecardCols: Column<PromiseRow>[] = [
    { header: 'Code', accessor: (r) => r.promise_code },
    { header: 'Promise', accessor: (r) => r.promise_text },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Grade', accessor: (r) => r.honesty_grade },
    { header: 'Progress %', accessor: (r) => (r.progress_percent ?? '—') },
  ];

  const statusCols: Column<StatusRow>[] = [
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Promises', accessor: (r) => r.promise_count },
    { header: 'Avg Progress', accessor: (r) => (r.avg_progress ?? '—') },
  ];

  const gradeCols: Column<GradeRow>[] = [
    { header: 'Grade', accessor: (r) => r.honesty_grade },
    { header: 'Count', accessor: (r) => r.promise_count },
    { header: 'Categories', accessor: (r) => (r.category_breakdown ?? '—') },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'Open', accessor: (r) => r.open_count },
  ];

  const openCritCols: Column<FindingRow>[] = [
    { header: 'Code', accessor: (r) => r.finding_code },
    { header: 'Year', accessor: (r) => r.letter_year },
    { header: 'Type', accessor: (r) => r.finding_type },
    { header: 'Passage', accessor: (r) => r.passage },
    { header: 'Reality', accessor: (r) => r.reality },
    { header: 'Recommendation', accessor: (r) => (r.recommendation ?? '—') },
  ];

  const catCols: Column<CategoryRow>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Promises', accessor: (r) => r.promise_count },
    { header: 'Avg Progress', accessor: (r) => (r.avg_progress ?? '—') },
    { header: 'On Track', accessor: (r) => r.on_track_count },
  ];

  const yrCols: Column<YearRow>[] = [
    { header: 'Letter Year', accessor: (r) => r.letter_year },
    { header: 'Findings', accessor: (r) => r.total_findings },
    { header: 'Accurate', accessor: (r) => r.accurate_count },
    { header: 'Overstatements', accessor: (r) => r.overstatement_count },
    { header: 'Accuracy %', accessor: (r) => (r.accuracy_pct ?? '—') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Engineer-Founder Annual-Letter Honesty &amp; Promise Audit</h1>
        <p className="text-sm text-gray-600 mt-1">
          Audit every promise made in past annual letters &amp; grade the founder&apos;s honesty quarterly.
          Promises &gt;= 90% progress count as on-track; findings &lt;= medium are advisory.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Promise Scorecard</h2>
        <DataTable rows={scorecardRows} columns={scorecardCols} emptyMessage="No promises tracked" rowKey={(r, i) => String((r as { id?: string }).id ?? r.promise_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Distribution</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No status data" rowKey={(r, i) => String(r.status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Honesty Grade Distribution</h2>
        <DataTable rows={gradeRows} columns={gradeCols} emptyMessage="No grade data" rowKey={(r, i) => String(r.honesty_grade ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Findings by Severity</h2>
        <DataTable rows={severityRows} columns={severityCols} emptyMessage="No findings" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Critical & High Findings</h2>
        <DataTable rows={openCritRows} columns={openCritCols} emptyMessage="No open critical findings" rowKey={(r, i) => String(r.finding_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category Honesty</h2>
        <DataTable rows={catRows} columns={catCols} emptyMessage="No category data" rowKey={(r, i) => String(r.category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Year-over-Year Accuracy</h2>
        <DataTable rows={yrRows} columns={yrCols} emptyMessage="No year data" rowKey={(r, i) => String(r.letter_year ?? i)} />
      </section>
    </div>
  );
}
