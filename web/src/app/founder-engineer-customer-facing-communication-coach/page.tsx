import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Coaching = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  coaching_focus: string;
  current_score: number;
  target_score: number;
  status: string;
  started_at: string;
  last_assessed_at: string | null;
};

type NeedsAttention = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  coaching_focus: string;
  current_score: number;
  target_score: number;
  gap: number;
  last_assessed_at: string | null;
};

type RecentAction = {
  id: string;
  coaching_id: string;
  engineer_email: string | null;
  coaching_focus: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  score_change: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [coachingsRes, attentionRes, recentRes] = await Promise.all([
    sb.rpc('list_engineer_comm_coachings_r1948'),
    sb.rpc('needs_attention_engineer_comm_coachings_r1948'),
    sb.rpc('recent_engineer_comm_coaching_actions_r1948'),
  ]);

  const coachings: Coaching[] = (coachingsRes.data ?? []) as Coaching[];
  const attention: NeedsAttention[] = (attentionRes.data ?? []) as NeedsAttention[];
  const recent: RecentAction[] = (recentRes.data ?? []) as RecentAction[];

  const coachingCols: Column<Coaching>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id },
    { key: 'coaching_focus', header: 'Focus', render: (r: any) => r.coaching_focus },
    { key: 'current_score', header: 'Current', render: (r: any) => String(r.current_score) },
    { key: 'target_score', header: 'Target', render: (r: any) => String(r.target_score) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'started_at', header: 'Started', render: (r: any) => new Date(r.started_at).toLocaleDateString() },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleDateString() : 'never' },
  ];

  const attentionCols: Column<NeedsAttention>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id },
    { key: 'coaching_focus', header: 'Focus', render: (r: any) => r.coaching_focus },
    { key: 'current_score', header: 'Current', render: (r: any) => String(r.current_score) },
    { key: 'target_score', header: 'Target', render: (r: any) => String(r.target_score) },
    { key: 'gap', header: 'Gap', render: (r: any) => String(r.gap) },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleDateString() : 'never' },
  ];

  const recentCols: Column<RecentAction>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'coaching_focus', header: 'Focus', render: (r: any) => r.coaching_focus },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'score_change', header: 'Delta', render: (r: any) => (r.score_change > 0 ? '+' : '') + String(r.score_change) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Customer-Facing Communication Coach</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Coach engineers on tone, empathy, jargon reduction, escalation handling, closing, and active listening.
        Track current vs target score and log roleplays, shadows, call reviews, and feedback.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Coaching Plans ({coachings.length})</h2>
        <DataTable rows={coachings} columns={coachingCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Needs Attention (gap &gt;= 3 or flagged)</h2>
        <DataTable rows={attention} columns={attentionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions ({recent.length})</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
