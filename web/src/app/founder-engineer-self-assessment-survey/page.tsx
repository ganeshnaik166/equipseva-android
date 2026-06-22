import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SurveyRow = {
  id: string;
  engineer_user_id: string;
  survey_period: string;
  satisfaction_score: number;
  growth_areas_md: string | null;
  blockers_md: string | null;
  status: string;
  captured_at: string;
};

type LowScoreRow = {
  id: string;
  engineer_user_id: string;
  survey_period: string;
  satisfaction_score: number;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  survey_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

function fmt(d: string | null) {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return d;
  }
}

function shorten(s: string | null, n = 80) {
  if (!s) return '—';
  return s.length > n ? s.slice(0, n) + '…' : s;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [surveysRes, lowRes, actionsRes] = await Promise.all([
    sb.rpc('list_surveys_r2152'),
    sb.rpc('low_scores_r2152'),
    sb.rpc('recent_actions_r2152'),
  ]);

  const surveys: SurveyRow[] = (surveysRes.data as SurveyRow[] | null) ?? [];
  const lowScores: LowScoreRow[] = (lowRes.data as LowScoreRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];

  const surveyCols: Column<SurveyRow>[] = [
    { key: 'survey_period', header: 'Period', render: (r: any) => r.survey_period ?? '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'satisfaction_score', header: 'Score', render: (r: any) => `${r.satisfaction_score ?? '—'} / 10` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'growth_areas_md', header: 'Growth', render: (r: any) => shorten(r.growth_areas_md, 60) },
    { key: 'blockers_md', header: 'Blockers', render: (r: any) => shorten(r.blockers_md, 60) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmt(r.captured_at) },
  ];

  const lowCols: Column<LowScoreRow>[] = [
    { key: 'survey_period', header: 'Period', render: (r: any) => r.survey_period ?? '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'satisfaction_score', header: 'Score', render: (r: any) => `${r.satisfaction_score ?? '—'} / 10` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmt(r.captured_at) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'survey_id', header: 'Survey', render: (r: any) => String(r.survey_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => shorten(r.notes_md, 80) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmt(r.taken_at) },
  ];

  const totalSurveys = surveys.length;
  const lowCount = lowScores.length;
  const recentActions = actions.length;
  const avgScore =
    surveys.length > 0
      ? (surveys.reduce((a, s) => a + (s.satisfaction_score ?? 0), 0) / surveys.length).toFixed(1)
      : '—';

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Self-Assessment Survey
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Round 2152 — quarterly engineer satisfaction capture, low-score watchlist, and follow-up action log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Surveys captured</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalSurveys}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Average score</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{avgScore}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Low scores (5 or under)</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{lowCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Recent actions</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{recentActions}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent surveys</h2>
        <DataTable
          rows={surveys}
          columns={surveyCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Low score watchlist (score 5 or under)
        </h2>
        <DataTable
          rows={lowScores}
          columns={lowCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent follow-up actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px', background: '#fafafa' }}>
        <h3 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '8px' }}>Status vocabulary</h3>
        <ul style={{ fontSize: '13px', color: '#444', lineHeight: 1.6, paddingLeft: '20px' }}>
          <li><b>captured</b> — survey submitted, no follow-up yet.</li>
          <li><b>follow_up_needed</b> — low score or flagged blocker, coach to reach out.</li>
          <li><b>escalated</b> — founder review required.</li>
          <li><b>closed</b> — resolved or recognized.</li>
        </ul>
      </section>
    </main>
  );
}
