import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-IN'); } catch { return String(d); }
}

export default async function FounderHospitalQbrSchedulerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiRow: any = null;
  let upcoming: any[] = [];
  let top50: any[] = [];
  let outcomes: any[] = [];
  let overdue: any[] = [];
  let ownerLoad: any[] = [];
  let agendaMix: any[] = [];

  try {
    const r = await sb.rpc('founder_hospital_qbr_kpis');
    kpiRow = Array.isArray(r.data) ? r.data[0] : null;
  } catch { kpiRow = null; }

  try {
    const r = await sb.rpc('founder_hospital_qbr_upcoming');
    upcoming = Array.isArray(r.data) ? r.data : [];
  } catch { upcoming = []; }

  try {
    const r = await sb.rpc('founder_hospital_qbr_top50_coverage');
    top50 = Array.isArray(r.data) ? r.data : [];
  } catch { top50 = []; }

  try {
    const r = await sb.rpc('founder_hospital_qbr_outcomes_feed');
    outcomes = Array.isArray(r.data) ? r.data : [];
  } catch { outcomes = []; }

  try {
    const r = await sb.rpc('founder_hospital_qbr_overdue');
    overdue = Array.isArray(r.data) ? r.data : [];
  } catch { overdue = []; }

  try {
    const r = await sb.rpc('founder_hospital_qbr_owner_load');
    ownerLoad = Array.isArray(r.data) ? r.data : [];
  } catch { ownerLoad = []; }

  try {
    const r = await sb.rpc('founder_hospital_qbr_agenda_mix');
    agendaMix = Array.isArray(r.data) ? r.data : [];
  } catch { agendaMix = []; }

  const k = kpiRow ?? {};
  const kpis: Kpi[] = [
    { label: 'Total scheduled', value: fmtInt(k.total_scheduled) },
    { label: 'Completed', value: fmtInt(k.total_completed) },
    { label: 'No-shows', value: fmtInt(k.total_no_show) },
    { label: 'Cancelled', value: fmtInt(k.total_cancelled) },
    { label: 'Upcoming 7d', value: fmtInt(k.upcoming_7d) },
    { label: 'Upcoming 30d', value: fmtInt(k.upcoming_30d) },
    { label: 'Overdue', value: fmtInt(k.overdue_count) },
    { label: 'Avg CSAT', value: k.avg_csat != null ? String(k.avg_csat) : '—' },
    { label: 'Avg NPS', value: k.avg_nps != null ? String(k.avg_nps) : '—' },
    { label: 'Churn risk', value: fmtInt(k.churn_risk_count) },
    { label: 'Expansion intent', value: fmtInt(k.expansion_intent_count) },
    { label: 'Expansion pipeline', value: fmtRupees(k.expansion_pipeline_rupees) },
    { label: 'Open action items', value: fmtInt(k.open_action_items) },
    { label: 'Completion rate', value: (k.completion_rate_pct ?? 0) + '%' },
    { label: 'Hospitals covered', value: fmtInt(k.hospitals_covered) },
    { label: 'Top-50 covered', value: (k.top50_covered_pct ?? 0) + '%' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '—' },
    { key: 'scheduled_at', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_at) },
    { key: 'days_until', header: 'Days until', render: (r: any) => r.days_until ?? '—' },
    { key: 'cs_owner_email', header: 'CS owner', render: (r: any) => r.cs_owner_email ?? '—' },
    { key: 'meeting_mode', header: 'Mode', render: (r: any) => r.meeting_mode ?? '—' },
    { key: 'agenda_template', header: 'Agenda', render: (r: any) => r.agenda_template ?? '—' },
    { key: 'hospital_rank_snapshot', header: 'Rank', render: (r: any) => r.hospital_rank_snapshot ?? '—' },
  ];

  const top50Cols: Column<any>[] = [
    { key: 'rank_position', header: 'Rank', render: (r: any) => r.rank_position ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'revenue_rupees_90d', header: 'Revenue 90d', render: (r: any) => fmtRupees(r.revenue_rupees_90d) },
    { key: 'last_qbr_at', header: 'Last QBR', render: (r: any) => fmtDate(r.last_qbr_at) },
    { key: 'days_since_last_qbr', header: 'Days since', render: (r: any) => r.days_since_last_qbr ?? '—' },
    { key: 'next_qbr_at', header: 'Next QBR', render: (r: any) => fmtDate(r.next_qbr_at) },
    { key: 'qbr_count_total', header: 'QBRs total', render: (r: any) => r.qbr_count_total ?? 0 },
  ];

  const outcomesCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '—' },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => r.csat_score ?? '—' },
    { key: 'nps_score', header: 'NPS', render: (r: any) => r.nps_score ?? '—' },
    { key: 'renewal_intent', header: 'Renewal intent', render: (r: any) => r.renewal_intent ?? '—' },
    { key: 'expansion_rupees_pipeline', header: 'Expansion', render: (r: any) => fmtRupees(r.expansion_rupees_pipeline) },
    { key: 'open_action_items_count', header: 'Open AIs', render: (r: any) => r.open_action_items_count ?? 0 },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '—' },
    { key: 'scheduled_at', header: 'Was scheduled', render: (r: any) => fmtDate(r.scheduled_at) },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => r.days_overdue ?? '—' },
    { key: 'cs_owner_email', header: 'CS owner', render: (r: any) => r.cs_owner_email ?? '—' },
    { key: 'hospital_rank_snapshot', header: 'Rank', render: (r: any) => r.hospital_rank_snapshot ?? '—' },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'cs_owner_email', header: 'CS owner', render: (r: any) => r.cs_owner_email ?? '—' },
    { key: 'total_assigned', header: 'Assigned', render: (r: any) => r.total_assigned ?? 0 },
    { key: 'upcoming_count', header: 'Upcoming', render: (r: any) => r.upcoming_count ?? 0 },
    { key: 'completed_count', header: 'Completed', render: (r: any) => r.completed_count ?? 0 },
    { key: 'no_show_count', header: 'No-shows', render: (r: any) => r.no_show_count ?? 0 },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => r.avg_csat ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital QBR Scheduler</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quarterly business reviews for top-50 hospitals by revenue. Founder/CS owner. Agenda templates. Outcome tracker.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        {kpis.map((kp, i) => (
          <div key={i} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{kp.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{kp.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming QBRs (next 60 days)</h2>
        <DataTable rowKey={(r: any) => r.id} columns={upcomingCols} rows={upcoming} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top-50 hospitals by revenue (90d) coverage</h2>
        <DataTable rowKey={(r: any) => r.hospital_org_id} columns={top50Cols} rows={top50} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent QBR outcomes</h2>
        <DataTable rowKey={(r: any) => r.outcome_id} columns={outcomesCols} rows={outcomes} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overdue QBRs</h2>
        <DataTable rowKey={(r: any) => r.id} columns={overdueCols} rows={overdue} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>CS owner load</h2>
        <DataTable rowKey={(r: any) => r.cs_owner_email} columns={ownerCols} rows={ownerLoad} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Agenda template mix</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
          {agendaMix.map((a: any, i: number) => (
            <div key={i} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
              <div style={{ fontSize: 12, color: '#666' }}>{a.agenda_template ?? '—'}</div>
              <div style={{ fontSize: 16, fontWeight: 600 }}>{fmtInt(a.scheduled_count)} scheduled / {fmtInt(a.completed_count)} done</div>
              <div style={{ fontSize: 12, color: '#666', marginTop: 4 }}>
                Avg CSAT: {a.avg_csat ?? '—'} {String.fromCharCode(183)} Expansion: {fmtRupees(a.expansion_pipeline_rupees)}
              </div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
