import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerCustomerSatisfactionPulseSurveyPage() {
  const supabase = await getSupabaseServerClient();

  const [
    surveysRes,
    actionsRes,
    complaintsRes,
    csatDistRes,
    npsRes,
    trendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_surveys_r2634'),
    supabase.rpc('list_followup_actions_r2634'),
    supabase.rpc('top_complaint_focus_r2634'),
    supabase.rpc('csat_distribution_r2634'),
    supabase.rpc('nps_summary_r2634'),
    supabase.rpc('monthly_pulse_trend_r2634'),
    supabase.rpc('owner_load_r2634'),
  ]);

  const surveys = (surveysRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const complaints = (complaintsRes.data ?? []) as any[];
  const csatDist = (csatDistRes.data ?? []) as any[];
  const nps = ((npsRes.data ?? []) as any[])[0] ?? null;
  const trend = (trendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const fmt = (v: any) => (v === null || v === undefined || v === '' ? '—' : String(v));
  const fmtDate = (v: any) => {
    if (!v) return '—';
    try {
      return new Date(v).toISOString().slice(0, 16).replace('T', ' ');
    } catch {
      return String(v);
    }
  };

  const surveyCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => String(r.engineer_id ?? '').slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'csat', header: 'CSAT', render: (r: any) => (r.csat === null || r.csat === undefined ? '—' : String(r.csat)) },
    { key: 'nps', header: 'NPS', render: (r: any) => (r.nps === null || r.nps === undefined ? '—' : String(r.nps)) },
    { key: 'top_compliment', header: 'Compliment', render: (r: any) => (r.top_compliment ?? '—') },
    { key: 'top_complaint', header: 'Complaint', render: (r: any) => (r.top_complaint ?? '—') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => (r.owner_email ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes ?? '—') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => fmtDate(r.action_at) },
    { key: 'survey_id', header: 'Survey', render: (r: any) => String(r.survey_id ?? '').slice(0, 8) },
    { key: 'action_kind', header: 'Kind', render: (r: any) => String(r.action_kind) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => (r.owner_email ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes ?? '—') },
  ];

  const complaintCols: Column<any>[] = [
    { key: 'complaint', header: 'Complaint', render: (r: any) => String(r.complaint) },
    { key: 'mentions', header: 'Mentions', render: (r: any) => String(r.mentions) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => (r.avg_csat === null ? '—' : String(r.avg_csat)) },
  ];

  const csatCols: Column<any>[] = [
    { key: 'csat_bucket', header: 'CSAT Score', render: (r: any) => String(r.csat_bucket) },
    { key: 'responses', header: 'Responses', render: (r: any) => String(r.responses) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start).slice(0, 7) },
    { key: 'responses', header: 'Responses', render: (r: any) => String(r.responses) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => (r.avg_csat === null ? '—' : String(r.avg_csat)) },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => (r.avg_nps === null ? '—' : String(r.avg_nps)) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email) },
    { key: 'open_actions', header: 'Open', render: (r: any) => String(r.open_actions) },
    { key: 'done_actions', header: 'Done', render: (r: any) => String(r.done_actions) },
    { key: 'dropped_actions', header: 'Dropped', render: (r: any) => String(r.dropped_actions) },
    { key: 'total_actions', header: 'Total', render: (r: any) => String(r.total_actions) },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.6rem', fontWeight: 700, marginBottom: '0.25rem' }}>
        Engineer & Customer Satisfaction Pulse Survey
      </h1>
      <p style={{ color: '#555', marginBottom: '1.25rem' }}>
        Short post-service pulse on CSAT & NPS, with follow-up actions tracked end-to-end.
      </p>

      <section style={{ marginBottom: '1.5rem', display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '0.75rem' }}>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Promoters</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 600 }}>{nps ? String(nps.promoters) : '0'}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Passives</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 600 }}>{nps ? String(nps.passives) : '0'}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Detractors</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 600 }}>{nps ? String(nps.detractors) : '0'}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Responses</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 600 }}>{nps ? String(nps.responses) : '0'}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>NPS Score</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 600 }}>{nps ? String(nps.nps_score) : '0'}</div>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Recent Surveys</h2>
        <DataTable
          rows={surveys}
          columns={surveyCols}
          emptyMessage="No surveys yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Follow-up Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No follow-up actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Top Complaint Focus</h2>
        <DataTable
          rows={complaints}
          columns={complaintCols}
          emptyMessage="No complaints recorded."
          rowKey={(r: any, i: number) => String(r.complaint ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>CSAT Distribution</h2>
        <DataTable
          rows={csatDist}
          columns={csatCols}
          emptyMessage="No CSAT responses yet."
          rowKey={(r: any, i: number) => String(r.csat_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Monthly Pulse Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owners assigned yet."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
