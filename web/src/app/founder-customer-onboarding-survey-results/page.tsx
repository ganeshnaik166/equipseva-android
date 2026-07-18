import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [surveys, followups, complaints, npsDist, csatDist, topHospitals, weeklyTrend] = await Promise.all([
    supabase.rpc('list_surveys_r2500'),
    supabase.rpc('list_followups_r2500'),
    supabase.rpc('top_complaint_themes_r2500'),
    supabase.rpc('nps_distribution_r2500'),
    supabase.rpc('csat_distribution_r2500'),
    supabase.rpc('top_hospitals_by_nps_r2500'),
    supabase.rpc('weekly_completion_trend_r2500'),
  ]);

  const surveyCols: Column<any>[] = [
    { key: 'survey_wave_label', header: 'Wave', render: (r: any) => r.survey_wave_label },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleDateString() : '-' },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '-' },
    { key: 'nps', header: 'NPS', render: (r: any) => r.nps ?? '-' },
    { key: 'csat', header: 'CSAT', render: (r: any) => r.csat ?? '-' },
    { key: 'top_compliment', header: 'Compliment', render: (r: any) => r.top_compliment || '-' },
    { key: 'top_complaint', header: 'Complaint', render: (r: any) => r.top_complaint || '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email || '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes || '-' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'action_at', header: 'When', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleDateString() : '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email || '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes || '-' },
  ];

  const complaintCols: Column<any>[] = [
    { key: 'top_complaint', header: 'Complaint Theme', render: (r: any) => r.top_complaint },
    { key: 'mention_count', header: 'Mentions', render: (r: any) => r.mention_count },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps },
  ];

  const npsCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'response_count', header: 'Responses', render: (r: any) => r.response_count },
  ];

  const csatCols: Column<any>[] = [
    { key: 'csat_score', header: 'CSAT Score', render: (r: any) => r.csat_score },
    { key: 'response_count', header: 'Responses', render: (r: any) => r.response_count },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps },
    { key: 'response_count', header: 'Responses', render: (r: any) => r.response_count },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start },
    { key: 'sent_count', header: 'Sent', render: (r: any) => r.sent_count },
    { key: 'completed_count', header: 'Completed', render: (r: any) => r.completed_count },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => r.completion_pct ?? '-' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Customer Onboarding Survey Results</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>Hospital &gt; survey wave &gt; NPS &gt; CSAT &gt; verbatim themes &gt; follow-up actions.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>NPS Distribution</h2>
        <DataTable
          rows={(npsDist.data ?? []) as any[]}
          columns={npsCols}
          emptyMessage="No NPS responses yet"
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>CSAT Distribution</h2>
        <DataTable
          rows={(csatDist.data ?? []) as any[]}
          columns={csatCols}
          emptyMessage="No CSAT responses yet"
          rowKey={(r: any, i: number) => String(r.csat_score ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Complaint Themes</h2>
        <DataTable
          rows={(complaints.data ?? []) as any[]}
          columns={complaintCols}
          emptyMessage="No complaints logged"
          rowKey={(r: any, i: number) => String(r.top_complaint ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Hospitals by NPS</h2>
        <DataTable
          rows={(topHospitals.data ?? []) as any[]}
          columns={hospitalCols}
          emptyMessage="No hospital NPS data"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly Completion Trend</h2>
        <DataTable
          rows={(weeklyTrend.data ?? []) as any[]}
          columns={weeklyCols}
          emptyMessage="No survey weeks yet"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Surveys</h2>
        <DataTable
          rows={(surveys.data ?? []) as any[]}
          columns={surveyCols}
          emptyMessage="No surveys sent yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Follow-up Actions</h2>
        <DataTable
          rows={(followups.data ?? []) as any[]}
          columns={followupCols}
          emptyMessage="No follow-ups logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
