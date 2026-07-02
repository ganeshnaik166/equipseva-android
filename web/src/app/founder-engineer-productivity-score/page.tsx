import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ScoreRow = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  score_window: string;
  window_start: string;
  jobs_completed: number;
  avg_rating: number;
  hours_logged: number;
  km_traveled: number;
  productivity_score: number;
  recorded_at: string;
};

type TopRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  productivity_score: number;
  jobs_completed: number;
  avg_rating: number;
  window_start: string;
};

type NoteRow = {
  id: string;
  score_id: string;
  founder_note_md: string;
  action: string;
  decided_at: string;
  engineer_user_id: string;
  productivity_score: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [scoresRes, topRes, bottomRes, notesRes] = await Promise.all([
    sb.rpc('list_scores_r1688', { p_window: 'month', p_limit: 100 }),
    sb.rpc('top_performers_r1688', { p_window: 'month', p_limit: 10 }),
    sb.rpc('bottom_performers_r1688', { p_window: 'month', p_limit: 10 }),
    sb.rpc('list_notes_r1688', { p_limit: 50 }),
  ]);

  const scores: ScoreRow[] = (scoresRes.data as ScoreRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const bottom: TopRow[] = (bottomRes.data as TopRow[]) ?? [];
  const notes: NoteRow[] = (notesRes.data as NoteRow[]) ?? [];

  const avgScore =
    scores.length > 0
      ? (scores.reduce((s, r) => s + Number(r.productivity_score || 0), 0) / scores.length).toFixed(1)
      : '0';
  const highCount = scores.filter((r) => Number(r.productivity_score) >= 100).length;
  const lowCount = scores.filter((r) => Number(r.productivity_score) < 30).length;
  const pipNotes = notes.filter((n) => n.action === 'PIP').length;

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span> },
    { key: 'window', header: 'Window', render: (r: any) => <span className="text-xs uppercase">{r.score_window}</span> },
    { key: 'window_start', header: 'Start', render: (r: any) => <span className="text-xs">{String(r.window_start)}</span> },
    { key: 'jobs', header: 'Jobs', render: (r: any) => <span>{r.jobs_completed}</span> },
    { key: 'rating', header: 'Rating', render: (r: any) => <span>{Number(r.avg_rating).toFixed(2)}</span> },
    { key: 'hours', header: 'Hours', render: (r: any) => <span>{Number(r.hours_logged).toFixed(1)}</span> },
    { key: 'km', header: 'KM', render: (r: any) => <span>{r.km_traveled}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span className="font-bold">{Number(r.productivity_score).toFixed(1)}</span> },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'rank', header: '#', render: (r: any, i?: number) => <span>{(i ?? 0) + 1}</span> },
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span className="font-bold text-emerald-700">{Number(r.productivity_score).toFixed(1)}</span> },
    { key: 'jobs', header: 'Jobs', render: (r: any) => <span>{r.jobs_completed}</span> },
    { key: 'rating', header: 'Rating', render: (r: any) => <span>{Number(r.avg_rating).toFixed(2)}</span> },
  ];

  const bottomCols: Column<TopRow>[] = [
    { key: 'rank', header: '#', render: (r: any, i?: number) => <span>{(i ?? 0) + 1}</span> },
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_email ?? r.engineer_user_id.slice(0, 8)}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span className="font-bold text-rose-700">{Number(r.productivity_score).toFixed(1)}</span> },
    { key: 'jobs', header: 'Jobs', render: (r: any) => <span>{r.jobs_completed}</span> },
    { key: 'rating', header: 'Rating', render: (r: any) => <span>{Number(r.avg_rating).toFixed(2)}</span> },
  ];

  const noteCols: Column<NoteRow>[] = [
    { key: 'action', header: 'Action', render: (r: any) => <span className="text-xs font-semibold uppercase">{r.action}</span> },
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_user_id.slice(0, 8)}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span>{Number(r.productivity_score).toFixed(1)}</span> },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs">{r.founder_note_md.slice(0, 80)}</span> },
    { key: 'decided', header: 'Decided', render: (r: any) => <span className="text-xs">{new Date(r.decided_at).toLocaleDateString()}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Productivity Score</h1>
        <p className="text-sm text-gray-600">Composite score from jobs done + rating + travel. High performers (&gt;100) coach others; low (&lt;30) get PIP.</p>
      </header>

      <section className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Avg Score</div>
          <div className="text-2xl font-bold">{avgScore}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">High (&gt;=100)</div>
          <div className="text-2xl font-bold text-emerald-700">{highCount}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Low (&lt;30)</div>
          <div className="text-2xl font-bold text-rose-700">{lowCount}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">PIP Notes</div>
          <div className="text-2xl font-bold text-amber-700">{pipNotes}</div>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">All Scores (Monthly)</h2>
        <DataTable rows={scores} columns={scoreCols} rowKey={(r: any, i?: number) => String(r.id ?? i)} />
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div>
          <h2 className="mb-3 text-lg font-semibold text-emerald-800">Top Performers</h2>
          <DataTable rows={top} columns={topCols} rowKey={(r: any, i?: number) => String(r.engineer_user_id ?? i)} />
        </div>
        <div>
          <h2 className="mb-3 text-lg font-semibold text-rose-800">Bottom Performers (Action Queue)</h2>
          <DataTable rows={bottom} columns={bottomCols} rowKey={(r: any, i?: number) => String(r.engineer_user_id ?? i)} />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Founder Review Notes</h2>
        <DataTable rows={notes} columns={noteCols} rowKey={(r: any, i?: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
