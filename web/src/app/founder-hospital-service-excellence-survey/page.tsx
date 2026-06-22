import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalServiceExcellenceSurveyPage() {
  const sb = await getSupabaseServerClient();

  const [surveysRes, lowRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_surveys_r1955'),
    sb.rpc('low_score_surveys_r1955', { p_threshold: 3.5 }),
    sb.rpc('recent_actions_r1955', { p_days: 14 }),
  ]);

  const surveys: any[] = Array.isArray(surveysRes.data) ? surveysRes.data : [];
  const lowScores: any[] = Array.isArray(lowRes.data) ? lowRes.data : [];
  const actions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const totalSurveys = surveys.length;
  const completed = surveys.filter((s) => s.status === 'completed').length;
  const inProgress = surveys.filter((s) => s.status === 'in_progress').length;
  const avgNps = surveys.length
    ? Math.round(
        surveys.reduce((acc, s) => acc + Number(s.nps_score || 0), 0) / surveys.length,
      )
    : 0;

  const surveyColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name || '—' },
    { key: 'survey_date', header: 'Date', render: (r: any) => r.survey_date || '—' },
    { key: 'response_count', header: 'Responses', render: (r: any) => String(r.response_count ?? 0) },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => Number(r.avg_score ?? 0).toFixed(2) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => String(r.nps_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '—' },
    {
      key: 'top_themes_md',
      header: 'Top Themes',
      render: (r: any) => (r.top_themes_md ? String(r.top_themes_md).slice(0, 80) : '—'),
    },
    {
      key: 'captured_at',
      header: 'Captured',
      render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '—'),
    },
  ];

  const lowColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name || '—' },
    { key: 'survey_date', header: 'Date', render: (r: any) => r.survey_date || '—' },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => Number(r.avg_score ?? 0).toFixed(2) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => String(r.nps_score ?? 0) },
    { key: 'response_count', header: 'Responses', render: (r: any) => String(r.response_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '—' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name || '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type || '—' },
    {
      key: 'taken_at',
      header: 'Taken At',
      render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '—'),
    },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    {
      key: 'notes_md',
      header: 'Notes',
      render: (r: any) => (r.notes_md ? String(r.notes_md).slice(0, 80) : '—'),
    },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Service Excellence Survey
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round 1955 — per-hospital service excellence surveys with response tracking,
        NPS scoring, and follow-up action log.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Surveys</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalSurveys}</div>
          </div>
          <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Completed</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{completed}</div>
          </div>
          <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>In Progress</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{inProgress}</div>
          </div>
          <div style={{ padding: 16, background: '#f4f4f5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg NPS</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{avgNps}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Surveys (latest 200)
        </h2>
        <DataTable
          rows={surveys}
          columns={surveyColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Low Score Surveys (below 3.5)
        </h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Surveys with avg score below threshold — require follow-up.
        </p>
        <DataTable
          rows={lowScores}
          columns={lowColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Actions (last 14 days)
        </h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
