import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CardRow = {
  id: string;
  engineer_user_id: string;
  month_start: string;
  jobs_completed: number;
  avg_rating: number | null;
  avg_response_min: number | null;
  satisfaction_score: number | null;
  payout_rupees: number;
  kpi_grade: string;
  recorded_at: string;
};

type FeedbackRow = {
  id: string;
  card_id: string;
  founder_feedback_md: string;
  recognition_award: string | null;
  action_required: string;
  fed_back_at: string;
};

type TopRow = {
  engineer_user_id: string;
  a_plus_count: number;
  total_payout: number;
  avg_rating: number | null;
  last_month: string | null;
};

type BottomRow = {
  engineer_user_id: string;
  poor_grade_count: number;
  total_payout: number;
  avg_rating: number | null;
  last_month: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cardsRes, feedbackRes, topRes, bottomRes] = await Promise.all([
    sb.rpc('list_engineer_kpi_cards_r1804', { p_limit: 200 }),
    sb.rpc('list_engineer_kpi_feedback_r1804', { p_limit: 200 }),
    sb.rpc('top_a_plus_engineers_r1804', { p_limit: 20 }),
    sb.rpc('bottom_engineers_r1804', { p_limit: 20 }),
  ]);

  const cards: CardRow[] = (cardsRes.data as CardRow[]) ?? [];
  const feedback: FeedbackRow[] = (feedbackRes.data as FeedbackRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const bottom: BottomRow[] = (bottomRes.data as BottomRow[]) ?? [];

  const cardCols: Column<CardRow>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? 0) },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => r.avg_rating == null ? '-' : Number(r.avg_rating).toFixed(2) },
    { key: 'avg_response_min', header: 'Resp min', render: (r: any) => r.avg_response_min == null ? '-' : String(r.avg_response_min) },
    { key: 'satisfaction_score', header: 'Sat', render: (r: any) => r.satisfaction_score == null ? '-' : Number(r.satisfaction_score).toFixed(1) },
    { key: 'payout_rupees', header: 'Payout (Rs)', render: (r: any) => Number(r.payout_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'kpi_grade', header: 'Grade', render: (r: any) => String(r.kpi_grade ?? '').toUpperCase() },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const feedbackCols: Column<FeedbackRow>[] = [
    { key: 'fed_back_at', header: 'When', render: (r: any) => r.fed_back_at ? new Date(r.fed_back_at).toLocaleString() : '' },
    { key: 'card_id', header: 'Card', render: (r: any) => String(r.card_id ?? '').slice(0, 8) },
    { key: 'action_required', header: 'Action', render: (r: any) => String(r.action_required ?? '') },
    { key: 'recognition_award', header: 'Award', render: (r: any) => String(r.recognition_award ?? '-') },
    { key: 'founder_feedback_md', header: 'Feedback', render: (r: any) => {
      const s = String(r.founder_feedback_md ?? '');
      return s.length > 80 ? s.slice(0, 80) + '...' : s;
    }},
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'a_plus_count', header: 'A+ months', render: (r: any) => String(r.a_plus_count ?? 0) },
    { key: 'total_payout', header: 'Total Payout (Rs)', render: (r: any) => Number(r.total_payout ?? 0).toLocaleString('en-IN') },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => r.avg_rating == null ? '-' : Number(r.avg_rating).toFixed(2) },
    { key: 'last_month', header: 'Last month', render: (r: any) => String(r.last_month ?? '') },
  ];

  const bottomCols: Column<BottomRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'poor_grade_count', header: 'C/D months', render: (r: any) => String(r.poor_grade_count ?? 0) },
    { key: 'total_payout', header: 'Total Payout (Rs)', render: (r: any) => Number(r.total_payout ?? 0).toLocaleString('en-IN') },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => r.avg_rating == null ? '-' : Number(r.avg_rating).toFixed(2) },
    { key: 'last_month', header: 'Last month', render: (r: any) => String(r.last_month ?? '') },
  ];

  const aPlusCards = cards.filter((c) => c.kpi_grade === 'a_plus').length;
  const poorCards = cards.filter((c) => c.kpi_grade === 'c' || c.kpi_grade === 'd').length;

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer KPI Card</h1>
        <p className="text-sm text-neutral-600">
          Per-engineer monthly KPI cards. Grades A+ &gt; A &gt; B &gt; C &gt; D. C/D engineers need coaching or PIP.
        </p>
        <div className="text-xs text-neutral-500">
          {cards.length} cards · {aPlusCards} A+ · {poorCards} C/D · {feedback.length} feedback entries
        </div>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Top A+ Engineers</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Bottom Engineers (C/D)</h2>
        <DataTable rows={bottom} columns={bottomCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Monthly KPI Cards</h2>
        <DataTable rows={cards} columns={cardCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Founder Feedback Log</h2>
        <DataTable rows={feedback} columns={feedbackCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
