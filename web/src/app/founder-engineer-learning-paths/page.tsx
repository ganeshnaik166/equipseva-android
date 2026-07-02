import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PathOverview = {
  slug: string;
  title: string;
  track: string;
  step_order: number;
  parent_slug: string | null;
  unlock_tier: string;
  est_hours: number;
  enrolled: number;
  in_progress: number;
  completed: number;
  avg_days_to_complete: number | null;
};

type EngineerBoard = {
  engineer_user_id: string;
  engineer_email: string | null;
  cached_tier: string | null;
  paths_unlocked: number;
  paths_completed: number;
  current_path: string | null;
  current_status: string | null;
  last_activity: string | null;
};

type TrackFunnel = {
  track: string;
  step_order: number;
  title: string;
  completed: number;
  in_progress: number;
  drop_pct: number;
};

type RecentUnlock = {
  engineer_user_id: string;
  engineer_email: string | null;
  path_slug: string;
  path_title: string;
  status: string;
  unlocked_at: string | null;
  updated_at: string | null;
};

type TierCorr = {
  cached_tier: string;
  engineers: number;
  paths_completed: number;
  avg_completed: number;
};

export default async function FounderEngineerLearningPathsPage() {
  const sb = await getSupabaseServerClient();

  const overviewRes = await sb.rpc('founder_learning_paths_overview');
  const boardRes    = await sb.rpc('founder_engineer_learning_board', { p_limit: 50 });
  const funnelRes   = await sb.rpc('founder_learning_track_funnel');
  const recentRes   = await sb.rpc('founder_learning_recent_unlocks', { p_limit: 25 });
  const tierRes     = await sb.rpc('founder_learning_tier_correlation');

  const overview = (overviewRes.data ?? []) as PathOverview[];
  const board    = (boardRes.data ?? []) as EngineerBoard[];
  const funnel   = (funnelRes.data ?? []) as TrackFunnel[];
  const recent   = (recentRes.data ?? []) as RecentUnlock[];
  const tier     = (tierRes.data ?? []) as TierCorr[];

  const totalEnrolled  = overview.reduce((a, r) => a + (r.enrolled ?? 0), 0);
  const totalCompleted = overview.reduce((a, r) => a + (r.completed ?? 0), 0);
  const totalInProg    = overview.reduce((a, r) => a + (r.in_progress ?? 0), 0);

  const overviewCols: Column<PathOverview>[] = [
    { key: 'track',       header: 'Track',       render: (r) => r.track ?? '—' },
    { key: 'step_order',  header: 'Step',        render: (r) => String(r.step_order ?? '—') },
    { key: 'title',       header: 'Path',        render: (r) => r.title ?? '—' },
    { key: 'parent_slug', header: 'Prereq',      render: (r) => r.parent_slug ?? '—' },
    { key: 'unlock_tier', header: 'Unlock tier', render: (r) => r.unlock_tier ?? '—' },
    { key: 'est_hours',   header: 'Est hrs',     render: (r) => String(r.est_hours ?? '—') },
    { key: 'enrolled',    header: 'Enrolled',    render: (r) => String(r.enrolled ?? 0) },
    { key: 'in_progress', header: 'In progress', render: (r) => String(r.in_progress ?? 0) },
    { key: 'completed',   header: 'Completed',   render: (r) => String(r.completed ?? 0) },
    { key: 'avg_days',    header: 'Avg days',    render: (r) => r.avg_days_to_complete == null ? '—' : Number(r.avg_days_to_complete).toFixed(1) },
  ];

  const boardCols: Column<EngineerBoard>[] = [
    { key: 'engineer_email', header: 'Engineer',       render: (r) => r.engineer_email ?? r.engineer_user_id },
    { key: 'cached_tier',    header: 'Tier',           render: (r) => r.cached_tier ?? '—' },
    { key: 'paths_unlocked', header: 'Unlocked',       render: (r) => String(r.paths_unlocked ?? 0) },
    { key: 'paths_completed',header: 'Completed',      render: (r) => String(r.paths_completed ?? 0) },
    { key: 'current_path',   header: 'Current path',   render: (r) => r.current_path ?? '—' },
    { key: 'current_status', header: 'Status',         render: (r) => r.current_status ?? '—' },
    { key: 'last_activity',  header: 'Last activity',  render: (r) => r.last_activity ? new Date(r.last_activity).toLocaleString() : '—' },
  ];

  const funnelCols: Column<TrackFunnel>[] = [
    { key: 'track',       header: 'Track',       render: (r) => r.track ?? '—' },
    { key: 'step_order',  header: 'Step',        render: (r) => String(r.step_order ?? '—') },
    { key: 'title',       header: 'Path',        render: (r) => r.title ?? '—' },
    { key: 'completed',   header: 'Completed',   render: (r) => String(r.completed ?? 0) },
    { key: 'in_progress', header: 'In progress', render: (r) => String(r.in_progress ?? 0) },
    { key: 'drop_pct',    header: 'Drop %',      render: (r) => (r.drop_pct ?? 0) + '%' },
  ];

  const recentCols: Column<RecentUnlock>[] = [
    { key: 'engineer_email', header: 'Engineer',   render: (r) => r.engineer_email ?? r.engineer_user_id },
    { key: 'path_title',     header: 'Path',       render: (r) => r.path_title ?? r.path_slug },
    { key: 'status',         header: 'Status',     render: (r) => r.status ?? '—' },
    { key: 'unlocked_at',    header: 'Unlocked',   render: (r) => r.unlocked_at ? new Date(r.unlocked_at).toLocaleString() : '—' },
    { key: 'updated_at',     header: 'Updated',    render: (r) => r.updated_at ? new Date(r.updated_at).toLocaleString() : '—' },
  ];

  const tierCols: Column<TierCorr>[] = [
    { key: 'cached_tier',     header: 'Tier',           render: (r) => r.cached_tier ?? '—' },
    { key: 'engineers',       header: 'Engineers',      render: (r) => String(r.engineers ?? 0) },
    { key: 'paths_completed', header: 'Paths completed',render: (r) => String(r.paths_completed ?? 0) },
    { key: 'avg_completed',   header: 'Avg / engineer', render: (r) => String(r.avg_completed ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Engineer learning paths</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Predefined ladders (imaging then ultrasound then MRI specialist). Founder unlocks next step per engineer.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Stat label="Paths defined"   value={String(overview.length)} />
        <Stat label="Total enrolled"  value={String(totalEnrolled)} />
        <Stat label="In progress"     value={String(totalInProg)} />
        <Stat label="Completed"       value={String(totalCompleted)} />
        <Stat label="Engineers tracked" value={String(board.length)} />
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>Paths overview</h2>
      <DataTable<PathOverview> rows={overview} columns={overviewCols} rowKey={(r) => r.slug} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Engineer board</h2>
      <DataTable<EngineerBoard> rows={board} columns={boardCols} rowKey={(r) => r.engineer_user_id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Track funnel</h2>
      <DataTable<TrackFunnel> rows={funnel} columns={funnelCols} rowKey={(r) => r.track + ':' + r.step_order} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Recent unlocks</h2>
      <DataTable<RecentUnlock> rows={recent} columns={recentCols} rowKey={(r) => r.engineer_user_id + ':' + r.path_slug} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Tier correlation</h2>
      <DataTable<TierCorr> rows={tier} columns={tierCols} rowKey={(r) => r.cached_tier} />

      <p style={{ color: '#888', fontSize: 12, marginTop: 24 }}>
        Unlock + mark-progress via RPCs founder_unlock_learning_path and founder_mark_learning_progress.
      </p>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ color: '#666', fontSize: 12 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
