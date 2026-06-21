import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Kpi = { label: string; value: string | number };

function fmtSec(s: number): string {
  if (!s || s <= 0) return '0m';
  const m = Math.round(s / 60);
  if (m < 60) return m + 'm';
  return Math.floor(m / 60) + 'h ' + (m % 60) + 'm';
}

function fmtDate(d: string | null): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-IN'); } catch { return d ?? '—'; }
}

export default async function FounderEngineerTrainingVideosPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let queue: any[] = [];
  let top: any[] = [];
  let progress: any[] = [];
  let cats: any[] = [];

  try {
    const r = await sb.rpc('founder_training_video_kpis');
    kpis = r.data ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_training_video_review_queue');
    queue = (r.data as any[]) ?? [];
  } catch { queue = []; }

  try {
    const r = await sb.rpc('founder_training_video_top_watched');
    top = (r.data as any[]) ?? [];
  } catch { top = []; }

  try {
    const r = await sb.rpc('founder_training_video_engineer_progress');
    progress = (r.data as any[]) ?? [];
  } catch { progress = []; }

  try {
    const r = await sb.rpc('founder_training_video_category_breakdown');
    cats = (r.data as any[]) ?? [];
  } catch { cats = []; }

  const kpiCards: Kpi[] = [
    { label: 'Approved Videos', value: kpis.approved_videos ?? 0 },
    { label: 'Pending Review', value: kpis.pending_videos ?? 0 },
    { label: 'Rejected', value: kpis.rejected_videos ?? 0 },
    { label: 'Archived', value: kpis.archived_videos ?? 0 },
    { label: 'Total Library', value: kpis.total_videos ?? 0 },
    { label: 'Beginner', value: kpis.beginner_videos ?? 0 },
    { label: 'Intermediate', value: kpis.intermediate_videos ?? 0 },
    { label: 'Advanced', value: kpis.advanced_videos ?? 0 },
    { label: 'Master', value: kpis.master_videos ?? 0 },
    { label: 'Total Minutes', value: kpis.total_minutes_approved ?? 0 },
    { label: 'Total Views', value: kpis.total_views ?? 0 },
    { label: 'Total Completions', value: kpis.total_completions ?? 0 },
    { label: 'Unique Engineers', value: kpis.unique_engineers ?? 0 },
    { label: 'Videos Watched', value: kpis.videos_watched ?? 0 },
    { label: 'Views (7d)', value: kpis.views_7d ?? 0 },
    { label: 'Completion Rate %', value: kpis.completion_rate_pct ?? 0 },
  ];

  const queueCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'difficulty', header: 'Difficulty', render: (r: any) => r.difficulty ?? '—' },
    { key: 'duration', header: 'Duration', render: (r: any) => fmtSec(r.duration_seconds ?? 0) },
    { key: 'curated_by', header: 'Curated By', render: (r: any) => r.curated_by ?? '—' },
    { key: 'created_at', header: 'Submitted', render: (r: any) => fmtDate(r.created_at) },
  ];

  const topCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'difficulty', header: 'Difficulty', render: (r: any) => r.difficulty ?? '—' },
    { key: 'view_count', header: 'Views', render: (r: any) => r.view_count ?? 0 },
    { key: 'completion_count', header: 'Completions', render: (r: any) => r.completion_count ?? 0 },
    { key: 'completion_rate_pct', header: 'Completion %', render: (r: any) => (r.completion_rate_pct ?? 0) + '%' },
  ];

  const progressCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'videos_watched', header: 'Watched', render: (r: any) => r.videos_watched ?? 0 },
    { key: 'videos_completed', header: 'Completed', render: (r: any) => r.videos_completed ?? 0 },
    { key: 'total_seconds', header: 'Time', render: (r: any) => fmtSec(r.total_seconds ?? 0) },
    { key: 'last_viewed_at', header: 'Last Viewed', render: (r: any) => fmtDate(r.last_viewed_at) },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'video_count', header: 'Videos', render: (r: any) => r.video_count ?? 0 },
    { key: 'total_views', header: 'Views', render: (r: any) => r.total_views ?? 0 },
    { key: 'total_completions', header: 'Completions', render: (r: any) => r.total_completions ?? 0 },
    { key: 'completion_rate_pct', header: 'Completion %', render: (r: any) => (r.completion_rate_pct ?? 0) + '%' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Training Video Library</h1>
        <p className="text-sm text-gray-600 mt-1">Curated training videos for engineers. Review queue, view counts, completion rates.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpiCards.map((k) => (
          <div key={k.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-xl font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Review Queue (Pending)</h2>
        <DataTable rows={queue} columns={queueCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Watched Videos</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Progress</h2>
        <DataTable rows={progress} columns={progressCols} rowKey={(r: any) => r.engineer_user_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category Breakdown</h2>
        <DataTable rows={cats} columns={catCols} rowKey={(r: any) => r.category} />
      </section>
    </div>
  );
}
