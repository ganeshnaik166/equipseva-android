import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [surveysRes, lowRes, actionsRes] = await Promise.all([
    sb.rpc('r1992_list_surveys'),
    sb.rpc('r1992_low_scores'),
    sb.rpc('r1992_recent_actions'),
  ]);

  const surveys: any[] = Array.isArray(surveysRes.data) ? surveysRes.data : [];
  const lows: any[] = Array.isArray(lowRes.data) ? lowRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const totalSurveys = surveys.length;
  const scored = surveys.filter((s) => typeof s.survey_score === 'number');
  const avgScore =
    scored.length > 0
      ? (scored.reduce((sum, s) => sum + Number(s.survey_score || 0), 0) / scored.length).toFixed(2)
      : 'n/a';
  const followUpCount = surveys.filter((s) => s.status === 'follow_up_needed').length;
  const escalatedCount = surveys.filter((s) => s.status === 'escalated').length;

  const surveyCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '-') },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name || '-' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name || '-' },
    { key: 'survey_score', header: 'Score', render: (r: any) => (r.survey_score == null ? '-' : `${r.survey_score} of 5`) },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment || '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '-' },
    { key: 'response_text_md', header: 'Response', render: (r: any) => (r.response_text_md ? String(r.response_text_md).slice(0, 80) : '-') },
  ];

  const lowCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '-') },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name || '-' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name || '-' },
    { key: 'survey_score', header: 'Score', render: (r: any) => (r.survey_score == null ? '-' : `${r.survey_score} of 5`) },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment || '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '-') },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name || '-' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name || '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type || '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ? String(r.notes_md).slice(0, 80) : '-') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Customer Visit Survey</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track post-visit customer surveys per engineer. Flag low scores, log follow-up actions, and escalate when needed.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, background: '#f5f7fa', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total surveys</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalSurveys}</div>
          </div>
          <div style={{ padding: 16, background: '#f5f7fa', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Average score</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{avgScore}</div>
          </div>
          <div style={{ padding: 16, background: '#fff7ed', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Follow-up needed</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{followUpCount}</div>
          </div>
          <div style={{ padding: 16, background: '#fef2f2', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Escalated</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{escalatedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Surveys</h2>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 8 }}>
          Latest 200 captured surveys across all engineers and hospitals.
        </p>
        <DataTable rows={surveys} columns={surveyCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Low Scores (at most 2 of 5)</h2>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 8 }}>
          Surveys with a score of 2 or fewer points. Coach the engineer and follow up with the hospital.
        </p>
        <DataTable rows={lows} columns={lowCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 8 }}>
          Latest 100 follow-up actions logged on visit surveys.
        </p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
