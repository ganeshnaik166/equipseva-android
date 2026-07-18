import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyInvestorBoardDeckBuilderPage() {
  const supabase = await getSupabaseServerClient();

  const [sectionsRes, questionsRes, funnelRes, topOpenRes, trendRes, kindRes, ownerRes] = await Promise.all([
    supabase.rpc('list_deck_sections_r2501'),
    supabase.rpc('list_questions_r2501'),
    supabase.rpc('status_funnel_r2501'),
    supabase.rpc('top_open_questions_r2501'),
    supabase.rpc('monthly_time_to_final_trend_r2501'),
    supabase.rpc('section_kind_breakdown_r2501'),
    supabase.rpc('owner_load_r2501'),
  ]);

  const sections = sectionsRes.data ?? [];
  const questions = questionsRes.data ?? [];
  const funnel = funnelRes.data ?? [];
  const topOpen = topOpenRes.data ?? [];
  const trend = trendRes.data ?? [];
  const kindBreakdown = kindRes.data ?? [];
  const ownerLoad = ownerRes.data ?? [];

  const fmtDate = (v: string | null) => (v ? new Date(v).toLocaleString('en-IN') : '—');

  const sectionCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'section_kind', header: 'Section', render: (r: any) => r.section_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'draft_at', header: 'Drafted', render: (r: any) => fmtDate(r.draft_at) },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => fmtDate(r.reviewed_at) },
    { key: 'finalized_at', header: 'Finalized', render: (r: any) => fmtDate(r.finalized_at) },
    { key: 'time_to_final_hours', header: 'Hrs to Final', render: (r: any) => r.time_to_final_hours ?? '—' },
    { key: 'top_question_anticipated', header: 'Top Q Anticipated', render: (r: any) => r.top_question_anticipated ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const questionCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'section_kind', header: 'Section', render: (r: any) => r.section_kind },
    { key: 'question_text', header: 'Question', render: (r: any) => r.question_text },
    { key: 'asked_by', header: 'Asked By', render: (r: any) => r.asked_by },
    { key: 'answer_owner_email', header: 'Answer Owner', render: (r: any) => r.answer_owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'answered_at', header: 'Answered', render: (r: any) => fmtDate(r.answered_at) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'section_count', header: 'Sections', render: (r: any) => r.section_count },
  ];

  const topOpenCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'section_kind', header: 'Section', render: (r: any) => r.section_kind },
    { key: 'question_text', header: 'Question', render: (r: any) => r.question_text },
    { key: 'asked_by', header: 'Asked By', render: (r: any) => r.asked_by },
    { key: 'answer_owner_email', header: 'Owner', render: (r: any) => r.answer_owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'avg_hours', header: 'Avg Hrs to Final', render: (r: any) => r.avg_hours },
    { key: 'finalized_count', header: 'Finalized Sections', render: (r: any) => r.finalized_count },
  ];

  const kindCols: Column<any>[] = [
    { key: 'section_kind', header: 'Section Kind', render: (r: any) => r.section_kind },
    { key: 'total_sections', header: 'Total', render: (r: any) => r.total_sections },
    { key: 'finalized', header: 'Finalized', render: (r: any) => r.finalized },
    { key: 'in_review', header: 'In Review', render: (r: any) => r.in_review },
    { key: 'draft', header: 'Draft', render: (r: any) => r.draft },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'sections_owned', header: 'Sections', render: (r: any) => r.sections_owned },
    { key: 'open_questions', header: 'Open Qs', render: (r: any) => r.open_questions },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Monthly Investor Board Deck Builder</h1>
        <p className="text-sm text-gray-600">
          Track deck sections month-over-month: draft &gt; in review &gt; finalized &gt; sent. Anticipated questions
          & owner load surfaced for tight prep cycles.
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-2">Deck Sections</h2>
        <DataTable
          rows={sections}
          columns={sectionCols}
          emptyMessage="No deck sections yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Anticipated Questions</h2>
        <DataTable
          rows={questions}
          columns={questionCols}
          emptyMessage="No questions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No funnel data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Top Open / Escalated Questions</h2>
        <DataTable
          rows={topOpen}
          columns={topOpenCols}
          emptyMessage="No open questions."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Monthly Time-to-Final Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Section Kind Breakdown</h2>
        <DataTable
          rows={kindBreakdown}
          columns={kindCols}
          emptyMessage="No breakdown data."
          rowKey={(r: any, i: number) => String(r.section_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
