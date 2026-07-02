import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ScoreRow = {
  engineer_user_id: string;
  full_name: string | null;
  tier: string | null;
  checkins_6mo: number | null;
  avg_stress: number | null;
  avg_workload: number | null;
  avg_growth: number | null;
  wellness_score: number | null;
  last_checkin: string | null;
};

type ActionRow = {
  engineer_user_id: string;
  full_name: string | null;
  tier: string | null;
  last_stress: number | null;
  last_workload: number | null;
  last_growth: number | null;
  wants_callback: boolean | null;
  submitted_at: string | null;
  reason: string | null;
};

type TrendRow = {
  period_month: string;
  checkins: number | null;
  avg_stress: number | null;
  avg_workload: number | null;
  avg_growth: number | null;
  callbacks: number | null;
};

type OpenActionRow = {
  id: string;
  engineer_user_id: string;
  full_name: string | null;
  action_type: string;
  notes: string | null;
  created_at: string;
};

export default async function FounderEngineerWellnessCheckinPage() {
  const sb = await getSupabaseServerClient();

  let scoreboard: ScoreRow[] = [];
  let actionList: ActionRow[] = [];
  let trend: TrendRow[] = [];
  let openActions: OpenActionRow[] = [];
  let errorMsg: string | null = null;

  try {
    const r1 = await sb.rpc('founder_engineer_wellness_scoreboard');
    if (r1.error) throw r1.error;
    scoreboard = (r1.data ?? []) as ScoreRow[];

    const r2 = await sb.rpc('founder_engineer_wellness_action_list');
    if (r2.error) throw r2.error;
    actionList = (r2.data ?? []) as ActionRow[];

    const r3 = await sb.rpc('founder_engineer_wellness_monthly_trend');
    if (r3.error) throw r3.error;
    trend = (r3.data ?? []) as TrendRow[];

    const r4 = await sb.rpc('founder_engineer_wellness_open_actions');
    if (r4.error) throw r4.error;
    openActions = (r4.data ?? []) as OpenActionRow[];
  } catch (e) {
    errorMsg = e instanceof Error ? e.message : 'failed to load wellness data';
  }

  const totalEngineers = scoreboard.length;
  const lowScore = scoreboard.filter((r) => (r.wellness_score ?? 99) < 5).length;
  const callbacks = actionList.filter((r) => r.wants_callback).length;
  const checkinsThisMonth = trend[0]?.checkins ?? 0;

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'full_name', header: 'Engineer', render: (r) => r.full_name ?? '—' },
    { key: 'tier', header: 'Tier', render: (r) => r.tier ?? '—' },
    { key: 'checkins_6mo', header: 'Check-ins 6mo', render: (r) => String(r.checkins_6mo ?? 0) },
    { key: 'avg_stress', header: 'Avg Stress', render: (r) => (r.avg_stress != null ? r.avg_stress.toFixed(2) : '—') },
    { key: 'avg_workload', header: 'Avg Workload', render: (r) => (r.avg_workload != null ? r.avg_workload.toFixed(2) : '—') },
    { key: 'avg_growth', header: 'Avg Growth', render: (r) => (r.avg_growth != null ? r.avg_growth.toFixed(2) : '—') },
    { key: 'wellness_score', header: 'Wellness', render: (r) => (r.wellness_score != null ? r.wellness_score.toFixed(2) : '—') },
    { key: 'last_checkin', header: 'Last Check-in', render: (r) => (r.last_checkin ? new Date(r.last_checkin).toLocaleDateString() : '—') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'full_name', header: 'Engineer', render: (r) => r.full_name ?? '—' },
    { key: 'tier', header: 'Tier', render: (r) => r.tier ?? '—' },
    { key: 'reason', header: 'Reason', render: (r) => r.reason ?? '—' },
    { key: 'last_stress', header: 'Stress', render: (r) => String(r.last_stress ?? '—') },
    { key: 'last_workload', header: 'Workload', render: (r) => String(r.last_workload ?? '—') },
    { key: 'last_growth', header: 'Growth', render: (r) => String(r.last_growth ?? '—') },
    { key: 'wants_callback', header: 'Callback?', render: (r) => (r.wants_callback ? 'yes' : 'no') },
    { key: 'submitted_at', header: 'Submitted', render: (r) => (r.submitted_at ? new Date(r.submitted_at).toLocaleDateString() : '—') },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month', render: (r) => new Date(r.period_month).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' }) },
    { key: 'checkins', header: 'Check-ins', render: (r) => String(r.checkins ?? 0) },
    { key: 'avg_stress', header: 'Avg Stress', render: (r) => (r.avg_stress != null ? r.avg_stress.toFixed(2) : '—') },
    { key: 'avg_workload', header: 'Avg Workload', render: (r) => (r.avg_workload != null ? r.avg_workload.toFixed(2) : '—') },
    { key: 'avg_growth', header: 'Avg Growth', render: (r) => (r.avg_growth != null ? r.avg_growth.toFixed(2) : '—') },
    { key: 'callbacks', header: 'Callbacks', render: (r) => String(r.callbacks ?? 0) },
  ];

  const openCols: Column<OpenActionRow>[] = [
    { key: 'full_name', header: 'Engineer', render: (r) => r.full_name ?? '—' },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
    { key: 'created_at', header: 'Opened', render: (r) => new Date(r.created_at).toLocaleDateString() },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Engineer Wellness Check-in</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Monthly stress, workload, and growth signal from field engineers. Wellness score combines inverted stress + inverted workload + growth, scale 1-10. Lower scores rise to the action list.
        </p>
        <p style={{ color: '#888', fontSize: 13 }}>Round r1627</p>
      </header>

      {errorMsg ? (
        <div style={{ padding: 16, background: '#fee', border: '1px solid #f88', borderRadius: 8, marginBottom: 16 }}>
          <strong>Error loading wellness data:</strong> {errorMsg}
        </div>
      ) : null}

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <div style={{ padding: 16, background: '#f7f7f8', borderRadius: 10 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Engineers tracked</div>
          <div style={{ fontSize: 26, fontWeight: 700 }}>{totalEngineers}</div>
        </div>
        <div style={{ padding: 16, background: '#fff4f0', borderRadius: 10 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Low wellness (under 5)</div>
          <div style={{ fontSize: 26, fontWeight: 700, color: '#c0392b' }}>{lowScore}</div>
        </div>
        <div style={{ padding: 16, background: '#fffbe6', borderRadius: 10 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Callback requests</div>
          <div style={{ fontSize: 26, fontWeight: 700 }}>{callbacks}</div>
        </div>
        <div style={{ padding: 16, background: '#f0f7ff', borderRadius: 10 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Check-ins this month</div>
          <div style={{ fontSize: 26, fontWeight: 700 }}>{checkinsThisMonth}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600 }}>Founder action list</h2>
        <p style={{ color: '#666', fontSize: 13 }}>Engineers flagged in the last 45 days by callback request, high stress, overload, or stalled growth.</p>
        <DataTable rows={actionList} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600 }}>Per-engineer wellness scoreboard</h2>
        <p style={{ color: '#666', fontSize: 13 }}>Rolling 6-month averages, weakest first.</p>
        <DataTable rows={scoreboard} columns={scoreCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600 }}>Monthly trend</h2>
        <DataTable rows={trend} columns={trendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600 }}>Open founder actions</h2>
        <DataTable rows={openActions} columns={openCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
