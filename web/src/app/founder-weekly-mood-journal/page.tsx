import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyMoodJournalPage() {
  const supabase = await getSupabaseServerClient();

  const [mood, corr, trend, decisions, redFlags, dist, pulse] = await Promise.all([
    supabase.rpc('list_mood_r2497'),
    supabase.rpc('list_correlations_r2497'),
    supabase.rpc('weekly_mood_trend_r2497'),
    supabase.rpc('decisions_vs_emotion_r2497'),
    supabase.rpc('top_red_flag_patterns_r2497'),
    supabase.rpc('dominant_emotion_distribution_r2497'),
    supabase.rpc('monthly_pulse_summary_r2497'),
  ]);

  const moodRows = (mood.data ?? []) as any[];
  const corrRows = (corr.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const decisionsRows = (decisions.data ?? []) as any[];
  const redFlagRows = (redFlags.data ?? []) as any[];
  const distRows = (dist.data ?? []) as any[];
  const pulseRows = (pulse.data ?? []) as any[];

  const moodCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'dominant_emotion', header: 'Emotion', render: (r: any) => String(r.dominant_emotion ?? '') },
    { key: 'mood_score', header: 'Mood', render: (r: any) => `${r.mood_score ?? 0}/10` },
    { key: 'energy_score', header: 'Energy', render: (r: any) => `${r.energy_score ?? 0}/10` },
    { key: 'decisions_made_count', header: 'Decisions', render: (r: any) => String(r.decisions_made_count ?? 0) },
    { key: 'decisions_regret_count', header: 'Regretted', render: (r: any) => String(r.decisions_regret_count ?? 0) },
    { key: 'what_worked_md', header: 'What worked', render: (r: any) => String(r.what_worked_md ?? '').slice(0, 80) },
    { key: 'what_didnt_md', header: 'What didn't', render: (r: any) => String(r.what_didnt_md ?? '').slice(0, 80) },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const corrCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'correlation_kind', header: 'Pattern', render: (r: any) => String(r.correlation_kind ?? '') },
    { key: 'correlation_strength', header: 'Strength', render: (r: any) => `${r.correlation_strength ?? 0}%` },
    { key: 'observation_md', header: 'Observation', render: (r: any) => String(r.observation_md ?? '').slice(0, 100) },
    { key: 'action_to_amplify_or_kill', header: 'Amplify/Kill', render: (r: any) => String(r.action_to_amplify_or_kill ?? '').slice(0, 100) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'dominant_emotion', header: 'Emotion', render: (r: any) => String(r.dominant_emotion ?? '') },
    { key: 'mood_score', header: 'Mood', render: (r: any) => `${r.mood_score ?? 0}/10` },
    { key: 'energy_score', header: 'Energy', render: (r: any) => `${r.energy_score ?? 0}/10` },
    { key: 'mood_avg_4wk', header: '4-wk avg mood', render: (r: any) => String(r.mood_avg_4wk ?? '') },
  ];

  const decisionsCols: Column<any>[] = [
    { key: 'dominant_emotion', header: 'Emotion', render: (r: any) => String(r.dominant_emotion ?? '') },
    { key: 'weeks_logged', header: 'Weeks', render: (r: any) => String(r.weeks_logged ?? 0) },
    { key: 'total_decisions', header: 'Decisions', render: (r: any) => String(r.total_decisions ?? 0) },
    { key: 'total_regretted', header: 'Regretted', render: (r: any) => String(r.total_regretted ?? 0) },
    { key: 'regret_rate_pct', header: 'Regret %', render: (r: any) => `${r.regret_rate_pct ?? 0}%` },
  ];

  const redFlagCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'dominant_emotion', header: 'Emotion', render: (r: any) => String(r.dominant_emotion ?? '') },
    { key: 'mood_score', header: 'Mood', render: (r: any) => `${r.mood_score ?? 0}/10` },
    { key: 'decisions_regret_count', header: 'Regretted', render: (r: any) => String(r.decisions_regret_count ?? 0) },
    { key: 'red_flag_patterns_md', header: 'Pattern', render: (r: any) => String(r.red_flag_patterns_md ?? '').slice(0, 160) },
  ];

  const distCols: Column<any>[] = [
    { key: 'dominant_emotion', header: 'Emotion', render: (r: any) => String(r.dominant_emotion ?? '') },
    { key: 'weeks_logged', header: 'Weeks', render: (r: any) => String(r.weeks_logged ?? 0) },
    { key: 'share_pct', header: 'Share %', render: (r: any) => `${r.share_pct ?? 0}%` },
    { key: 'avg_mood', header: 'Avg mood', render: (r: any) => String(r.avg_mood ?? '') },
    { key: 'avg_energy', header: 'Avg energy', render: (r: any) => String(r.avg_energy ?? '') },
  ];

  const pulseCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '') },
    { key: 'weeks_logged', header: 'Weeks', render: (r: any) => String(r.weeks_logged ?? 0) },
    { key: 'avg_mood', header: 'Avg mood', render: (r: any) => String(r.avg_mood ?? '') },
    { key: 'avg_energy', header: 'Avg energy', render: (r: any) => String(r.avg_energy ?? '') },
    { key: 'total_decisions', header: 'Decisions', render: (r: any) => String(r.total_decisions ?? 0) },
    { key: 'total_regretted', header: 'Regretted', render: (r: any) => String(r.total_regretted ?? 0) },
    { key: 'regret_rate_pct', header: 'Regret %', render: (r: any) => `${r.regret_rate_pct ?? 0}%` },
    { key: 'open_correlations', header: 'Open correlations', render: (r: any) => String(r.open_correlations ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Weekly Mood Journal</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track week > dominant emotion > what worked & what didn't > decisions vs emotion > red-flag patterns.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly mood entries</h2>
        <DataTable
          rows={moodRows}
          columns={moodCols}
          emptyMessage="No mood entries logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Emotion <=> decision correlations</h2>
        <DataTable
          rows={corrRows}
          columns={corrCols}
          emptyMessage="No correlations logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly mood trend (4-week rolling)</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Decisions vs emotion (regret rate)</h2>
        <DataTable
          rows={decisionsRows}
          columns={decisionsCols}
          emptyMessage="No decision data."
          rowKey={(r: any, i: number) => String(r.dominant_emotion ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top red-flag patterns</h2>
        <DataTable
          rows={redFlagRows}
          columns={redFlagCols}
          emptyMessage="No red-flag patterns logged."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Dominant emotion distribution</h2>
        <DataTable
          rows={distRows}
          columns={distCols}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.dominant_emotion ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly pulse summary</h2>
        <DataTable
          rows={pulseRows}
          columns={pulseCols}
          emptyMessage="No monthly pulse data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </main>
  );
}
