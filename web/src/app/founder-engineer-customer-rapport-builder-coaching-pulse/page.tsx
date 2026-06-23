import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [leaderboardRes, tierRes, atRiskRes, recentRes, focusRes] = await Promise.all([
    supabase.rpc('rapport_pulse_leaderboard_r2334', { p_limit: 50 }),
    supabase.rpc('rapport_pulse_tier_distribution_r2334'),
    supabase.rpc('rapport_pulse_at_risk_r2334'),
    supabase.rpc('rapport_coaching_recent_r2334', { p_limit: 100 }),
    supabase.rpc('rapport_coaching_focus_breakdown_r2334'),
  ]);

  const leaderboard = (leaderboardRes.data ?? []) as any[];
  const tiers = (tierRes.data ?? []) as any[];
  const atRisk = (atRiskRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];

  const leaderboardCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? r.engineer_email ?? '—' },
    { key: 'rapport_tier', header: 'Tier', render: (r) => r.rapport_tier },
    { key: 'rapport_score', header: 'Score', render: (r) => r.rapport_score ?? '—' },
    { key: 'csat_avg', header: 'CSAT', render: (r) => `${r.csat_avg ?? '—'} (n=${r.csat_responses ?? 0})` },
    { key: 'repeat_request_rate', header: 'Repeat %', render: (r) => r.repeat_request_rate ?? '—' },
    { key: 'name_recall_rate', header: 'Name recall %', render: (r) => r.name_recall_rate ?? '—' },
    { key: 'pulse_window_end', header: 'Window end', render: (r) => r.pulse_window_end ?? '—' },
  ];

  const tierCols: Column<any>[] = [
    { key: 'rapport_tier', header: 'Tier', render: (r) => r.rapport_tier },
    { key: 'engineer_count', header: 'Engineers', render: (r) => r.engineer_count },
    { key: 'avg_rapport_score', header: 'Avg score', render: (r) => r.avg_rapport_score ?? '—' },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r) => r.avg_csat ?? '—' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? r.engineer_email ?? '—' },
    { key: 'rapport_score', header: 'Score', render: (r) => r.rapport_score ?? '—' },
    { key: 'csat_avg', header: 'CSAT', render: (r) => r.csat_avg ?? '—' },
    { key: 'repeat_request_rate', header: 'Repeat %', render: (r) => r.repeat_request_rate ?? '—' },
    { key: 'open_coaching_sessions', header: 'Open sessions', render: (r) => r.open_coaching_sessions ?? 0 },
    { key: 'pulse_window_end', header: 'Window end', render: (r) => r.pulse_window_end ?? '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r) => new Date(r.created_at).toLocaleString() },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'coach_email', header: 'Coach', render: (r) => r.coach_email },
    { key: 'session_type', header: 'Type', render: (r) => r.session_type },
    { key: 'focus_area', header: 'Focus', render: (r) => r.focus_area },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome ?? 'pending' },
    { key: 'follow_up_at', header: 'Follow-up', render: (r) => r.follow_up_at ?? '—' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'focus_area', header: 'Focus area', render: (r) => r.focus_area },
    { key: 'session_count', header: 'Sessions', render: (r) => r.session_count },
    { key: 'improved_count', header: 'Improved', render: (r) => r.improved_count },
    { key: 'pending_count', header: 'Pending', render: (r) => r.pending_count },
    { key: 'improvement_rate', header: 'Improvement %', render: (r) => r.improvement_rate ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>
        Engineer Customer-Rapport Coaching Pulse
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Rank field engineers on customer rapport indicators — CSAT, repeat-request rate, and name-recall —
        then drive a coaching log so the &gt;= at_risk tier shrinks each pulse.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier distribution</h2>
        <DataTable
          rows={tiers}
          columns={tierCols}
          rowKey={(r) => r.rapport_tier}
          emptyMessage="No pulse rows yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Rapport leaderboard</h2>
        <DataTable
          rows={leaderboard}
          columns={leaderboardCols}
          rowKey={(r) => r.engineer_user_id}
          emptyMessage="No engineers ranked yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>At-risk engineers</h2>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r) => r.engineer_user_id}
          emptyMessage="No engineers in at_risk tier."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Coaching focus breakdown</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          rowKey={(r) => r.focus_area}
          emptyMessage="No coaching sessions logged."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent coaching sessions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r) => r.id}
          emptyMessage="No coaching sessions yet."
        />
      </section>
    </main>
  );
}
