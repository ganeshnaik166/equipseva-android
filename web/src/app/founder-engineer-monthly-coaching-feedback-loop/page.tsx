import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Session = {
  id: string;
  cycle_month: string;
  engineer_code: string;
  engineer_tier: string;
  coach_name: string;
  feedback_kind: string;
  improvement_area: string;
  action_taken: string;
  outcome_score: number;
  status: string;
  owner_coach: string;
  notes: string | null;
  created_at: string;
  closed_at: string | null;
};

type FocusRow = {
  improvement_area: string;
  sessions_count: number;
  avg_score: number;
  open_count: number;
};

type StatusRow = { status: string; sessions_count: number; avg_score: number };
type TrendRow = { cycle_month: string; sessions_count: number; avg_score: number; closed_count: number };
type OwnerRow = { owner_coach: string; open_count: number; closed_count: number; avg_score: number };
type GapRow = {
  improvement_area: string;
  engineer_tier: string;
  target_score: number;
  pass_threshold: number;
  actual_avg: number | null;
  gap_vs_target: number | null;
  sessions_count: number;
};
type Summary = {
  total_sessions: number;
  open_sessions: number;
  closed_sessions: number;
  escalated_sessions: number;
  avg_outcome_score: number;
  distinct_engineers: number;
  distinct_coaches: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, sessionsRes, focusRes, statusRes, trendRes, ownerRes, gapRes] = await Promise.all([
    supabase.rpc('coaching_summary_r2670'),
    supabase.rpc('list_coaching_sessions_r2670'),
    supabase.rpc('top_improvement_focus_r2670'),
    supabase.rpc('coaching_status_funnel_r2670'),
    supabase.rpc('monthly_coaching_score_trend_r2670'),
    supabase.rpc('coach_owner_load_r2670'),
    supabase.rpc('tier_gap_vs_benchmark_r2670'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] ?? null) as Summary | null;
  const sessions: Session[] = (sessionsRes.data ?? []) as Session[];
  const focus: FocusRow[] = (focusRes.data ?? []) as FocusRow[];
  const statusRows: StatusRow[] = (statusRes.data ?? []) as StatusRow[];
  const trend: TrendRow[] = (trendRes.data ?? []) as TrendRow[];
  const owner: OwnerRow[] = (ownerRes.data ?? []) as OwnerRow[];
  const gaps: GapRow[] = (gapRes.data ?? []) as GapRow[];

  const fmtDate = (d: string | null) => (d ? new Date(d).toLocaleDateString() : '—');
  const fmtNum = (n: number | null | undefined) =>
    n === null || n === undefined ? '—' : Number(n).toFixed(2);

  return (
    <div style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>
        Engineer Monthly Coaching Feedback Loop
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Founder console · r2670 · engineer × coach × feedback kind × improvement area × action × outcome score
      </p>

      {/* KPI cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Kpi label="Total sessions" value={summary?.total_sessions ?? 0} />
        <Kpi label="Open / in-progress" value={summary?.open_sessions ?? 0} />
        <Kpi label="Closed" value={summary?.closed_sessions ?? 0} />
        <Kpi label="Escalated" value={summary?.escalated_sessions ?? 0} tone={(summary?.escalated_sessions ?? 0) > 0 ? 'warn' : 'ok'} />
        <Kpi label="Avg outcome (0-10)" value={fmtNum(summary?.avg_outcome_score)} />
        <Kpi label="Engineers coached" value={summary?.distinct_engineers ?? 0} />
        <Kpi label="Active coaches" value={summary?.distinct_coaches ?? 0} />
      </div>

      <Section title="Top improvement focus areas">
        <DataTable
          rows={focus}
          rowKey={(r, i) => String((r as FocusRow).improvement_area ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'improvement_area', header: 'Improvement area', render: (r) => (r as FocusRow).improvement_area },
            { key: 'sessions_count', header: 'Sessions', render: (r) => String((r as FocusRow).sessions_count) },
            { key: 'avg_score', header: 'Avg score', render: (r) => fmtNum((r as FocusRow).avg_score) },
            { key: 'open_count', header: 'Still open', render: (r) => String((r as FocusRow).open_count) },
          ]}
        />
      </Section>

      <Section title="Status funnel">
        <DataTable
          rows={statusRows}
          rowKey={(r, i) => String((r as StatusRow).status ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'status', header: 'Status', render: (r) => (r as StatusRow).status },
            { key: 'sessions_count', header: 'Sessions', render: (r) => String((r as StatusRow).sessions_count) },
            { key: 'avg_score', header: 'Avg score', render: (r) => fmtNum((r as StatusRow).avg_score) },
          ]}
        />
      </Section>

      <Section title="Monthly score trend (most recent first)">
        <DataTable
          rows={trend}
          rowKey={(r, i) => String((r as TrendRow).cycle_month ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'cycle_month', header: 'Cycle month', render: (r) => fmtDate((r as TrendRow).cycle_month) },
            { key: 'sessions_count', header: 'Sessions', render: (r) => String((r as TrendRow).sessions_count) },
            { key: 'avg_score', header: 'Avg score', render: (r) => fmtNum((r as TrendRow).avg_score) },
            { key: 'closed_count', header: 'Closed', render: (r) => String((r as TrendRow).closed_count) },
          ]}
        />
      </Section>

      <Section title="Coach owner load">
        <DataTable
          rows={owner}
          rowKey={(r, i) => String((r as OwnerRow).owner_coach ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'owner_coach', header: 'Owner coach', render: (r) => (r as OwnerRow).owner_coach },
            { key: 'open_count', header: 'Open', render: (r) => String((r as OwnerRow).open_count) },
            { key: 'closed_count', header: 'Closed', render: (r) => String((r as OwnerRow).closed_count) },
            { key: 'avg_score', header: 'Avg score', render: (r) => fmtNum((r as OwnerRow).avg_score) },
          ]}
        />
      </Section>

      <Section title="Tier gap vs benchmark (actual avg & gap vs target)">
        <DataTable
          rows={gaps}
          rowKey={(r, i) => `${(r as GapRow).improvement_area}-${(r as GapRow).engineer_tier}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'improvement_area', header: 'Area', render: (r) => (r as GapRow).improvement_area },
            { key: 'engineer_tier', header: 'Tier', render: (r) => (r as GapRow).engineer_tier },
            { key: 'target_score', header: 'Target', render: (r) => fmtNum((r as GapRow).target_score) },
            { key: 'pass_threshold', header: 'Pass >=', render: (r) => fmtNum((r as GapRow).pass_threshold) },
            { key: 'actual_avg', header: 'Actual avg', render: (r) => fmtNum((r as GapRow).actual_avg) },
            { key: 'gap_vs_target', header: 'Gap', render: (r) => fmtNum((r as GapRow).gap_vs_target) },
            { key: 'sessions_count', header: 'N', render: (r) => String((r as GapRow).sessions_count) },
          ]}
        />
      </Section>

      <Section title="All coaching sessions">
        <DataTable
          rows={sessions}
          rowKey={(r, i) => String((r as Session).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'cycle_month', header: 'Cycle', render: (r) => fmtDate((r as Session).cycle_month) },
            { key: 'engineer_code', header: 'Engineer', render: (r) => (r as Session).engineer_code },
            { key: 'engineer_tier', header: 'Tier', render: (r) => (r as Session).engineer_tier },
            { key: 'coach_name', header: 'Coach', render: (r) => (r as Session).coach_name },
            { key: 'feedback_kind', header: 'Kind', render: (r) => (r as Session).feedback_kind },
            { key: 'improvement_area', header: 'Area', render: (r) => (r as Session).improvement_area },
            { key: 'action_taken', header: 'Action', render: (r) => (r as Session).action_taken },
            { key: 'outcome_score', header: 'Score', render: (r) => fmtNum((r as Session).outcome_score) },
            { key: 'status', header: 'Status', render: (r) => (r as Session).status },
            { key: 'owner_coach', header: 'Owner', render: (r) => (r as Session).owner_coach },
            { key: 'closed_at', header: 'Closed', render: (r) => fmtDate((r as Session).closed_at) },
          ]}
        />
      </Section>

      <p style={{ color: '#888', fontSize: 12, marginTop: 28 }}>
        Founder-only data. Score scale 0-10; gap &lt; 0 means below target, gap &gt;= 0 means at/above target.
      </p>
    </div>
  );
}

function Kpi({ label, value, tone }: { label: string; value: string | number; tone?: 'ok' | 'warn' }) {
  const border = tone === 'warn' ? '#f59e0b' : '#e5e7eb';
  return (
    <div style={{ border: `1px solid ${border}`, borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 600 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '8px 0 10px' }}>{title}</h2>
      {children}
    </section>
  );
}
