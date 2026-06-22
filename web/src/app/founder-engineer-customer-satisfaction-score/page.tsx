import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ScoreRow = {
  id: string;
  engineer_user_id: string;
  period_label: string;
  total_jobs: number;
  csat_responses_count: number;
  avg_csat_score: number;
  promoter_count: number;
  detractor_count: number;
  status: string;
  captured_at: string;
};

type TopRow = {
  id: string;
  engineer_user_id: string;
  period_label: string;
  avg_csat_score: number;
  promoter_count: number;
  total_jobs: number;
  status: string;
};

type ActionRow = {
  id: string;
  score_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [scoresRes, topRes, actionsRes] = await Promise.all([
    sb.rpc('list_engineer_csat_scores_r1968', { p_status: null, p_limit: 200 }),
    sb.rpc('top_engineer_csat_scorers_r1968', { p_limit: 10 }),
    sb.rpc('recent_engineer_csat_actions_r1968', { p_limit: 50 }),
  ]);

  const scores: ScoreRow[] = (scoresRes.data as ScoreRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => r.total_jobs },
    { key: 'csat_responses_count', header: 'Responses', render: (r: any) => r.csat_responses_count },
    { key: 'avg_csat_score', header: 'Avg CSAT', render: (r: any) => Number(r.avg_csat_score ?? 0).toFixed(2) },
    { key: 'promoter_count', header: 'Promoters', render: (r: any) => r.promoter_count },
    { key: 'detractor_count', header: 'Detractors', render: (r: any) => r.detractor_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleDateString() },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'avg_csat_score', header: 'Avg CSAT', render: (r: any) => Number(r.avg_csat_score ?? 0).toFixed(2) },
    { key: 'promoter_count', header: 'Promoters', render: (r: any) => r.promoter_count },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => r.total_jobs },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'score_id', header: 'Score', render: (r: any) => String(r.score_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Customer Satisfaction Score</h1>
        <p className="text-sm text-gray-600">
          Per-engineer CSAT tracking across periods, promoters and detractors with founder actions.
        </p>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Top scorers</h2>
        <p className="text-sm text-gray-600">Engineers ranked by average CSAT and promoter count.</p>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">All CSAT score records</h2>
        <p className="text-sm text-gray-600">Most recent capture first. Status flags those needing review or at risk.</p>
        <DataTable rows={scores} columns={scoreCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent founder actions</h2>
        <p className="text-sm text-gray-600">Coaching, bonuses, promotions, escalations and recognition entries.</p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
