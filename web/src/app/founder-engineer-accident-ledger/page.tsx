import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtRupees(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtNum(n: any, digits = 2): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return v.toFixed(digits);
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try {
    return new Date(String(s)).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return String(s);
  }
}

export default async function FounderEngineerAccidentLedgerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let incidents: any[] = [];
  let byEngineer: any[] = [];
  let claimPipeline: any[] = [];
  let lessonLadder: any[] = [];
  let typeSeverity: any[] = [];

  try {
    const r = await sb.rpc('founder_accident_ledger_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch {
    kpis = {};
  }
  try {
    const r = await sb.rpc('founder_accident_incidents_recent', { p_limit: 50 });
    incidents = r.data || [];
  } catch {
    incidents = [];
  }
  try {
    const r = await sb.rpc('founder_accident_by_engineer', { p_limit: 50 });
    byEngineer = r.data || [];
  } catch {
    byEngineer = [];
  }
  try {
    const r = await sb.rpc('founder_accident_claim_pipeline');
    claimPipeline = r.data || [];
  } catch {
    claimPipeline = [];
  }
  try {
    const r = await sb.rpc('founder_accident_lesson_ladder');
    lessonLadder = r.data || [];
  } catch {
    lessonLadder = [];
  }
  try {
    const r = await sb.rpc('founder_accident_by_type_severity');
    typeSeverity = r.data || [];
  } catch {
    typeSeverity = [];
  }

  const cards: Kpi[] = [
    { label: 'Total Incidents', value: fmtInt(kpis.total_incidents) },
    { label: 'Open Incidents', value: fmtInt(kpis.open_incidents) },
    { label: 'Near Misses', value: fmtInt(kpis.near_miss_count) },
    { label: 'Critical', value: fmtInt(kpis.critical_count) },
    { label: 'Severe', value: fmtInt(kpis.severe_count) },
    { label: 'Moderate', value: fmtInt(kpis.moderate_count) },
    { label: 'Minor', value: fmtInt(kpis.minor_count) },
    { label: 'Hospitalized', value: fmtInt(kpis.hospitalized_count) },
    { label: 'Days Lost (total)', value: fmtInt(kpis.days_lost_total) },
    { label: 'Claims Submitted', value: fmtInt(kpis.claims_submitted) },
    { label: 'Claims Approved', value: fmtInt(kpis.claims_approved) },
    { label: 'Claims Paid', value: fmtInt(kpis.claims_paid) },
    { label: 'Claims Rejected', value: fmtInt(kpis.claims_rejected) },
    { label: 'Claim Payout', value: fmtRupees(kpis.total_claim_payout_rupees) },
    { label: 'Engineers Affected', value: fmtInt(kpis.engineers_with_incident) },
    { label: 'Avg Lesson Rank', value: fmtNum(kpis.avg_lesson_rank, 2) },
  ];

  const incidentCols: Column<any>[] = [
    { key: 'incident_at', header: 'When', render: (r: any) => fmtDate(r.incident_at) },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'incident_type', header: 'Type', render: (r: any) => r.incident_type ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'body_part', header: 'Body Part', render: (r: any) => r.body_part ?? '—' },
    { key: 'hospitalized', header: 'Hosp.', render: (r: any) => (r.hospitalized ? 'Yes' : 'No') },
    { key: 'days_lost', header: 'Days Lost', render: (r: any) => fmtInt(r.days_lost) },
    { key: 'medical_claim_amount_rupees', header: 'Claim', render: (r: any) => fmtRupees(r.medical_claim_amount_rupees) },
    { key: 'medical_claim_status', header: 'Claim Status', render: (r: any) => r.medical_claim_status ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const engineerCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'cached_highest_tier', header: 'Tier', render: (r: any) => r.cached_highest_tier ?? '—' },
    { key: 'incidents_count', header: 'Incidents', render: (r: any) => fmtInt(r.incidents_count) },
    { key: 'near_misses', header: 'Near Miss', render: (r: any) => fmtInt(r.near_misses) },
    { key: 'hospitalizations', header: 'Hosp.', render: (r: any) => fmtInt(r.hospitalizations) },
    { key: 'days_lost_total', header: 'Days Lost', render: (r: any) => fmtInt(r.days_lost_total) },
    { key: 'total_claims_paid_rupees', header: 'Claims Paid', render: (r: any) => fmtRupees(r.total_claims_paid_rupees) },
    { key: 'last_incident_at', header: 'Last Incident', render: (r: any) => fmtDate(r.last_incident_at) },
    { key: 'safety_rating_impact', header: 'Safety Impact', render: (r: any) => fmtNum(r.safety_rating_impact, 2) },
  ];

  const claimCols: Column<any>[] = [
    { key: 'medical_claim_status', header: 'Status', render: (r: any) => r.medical_claim_status ?? '—' },
    { key: 'incident_count', header: 'Count', render: (r: any) => fmtInt(r.incident_count) },
    { key: 'total_amount_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_amount_rupees) },
    { key: 'avg_days_to_settle', header: 'Avg Days to Settle', render: (r: any) => fmtNum(r.avg_days_to_settle, 1) },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'lesson_ladder_rank', header: 'Ladder Rank', render: (r: any) => fmtInt(r.lesson_ladder_rank) },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => fmtInt(r.incident_count) },
    { key: 'hospitalized_count', header: 'Hospitalized', render: (r: any) => fmtInt(r.hospitalized_count) },
    { key: 'days_lost_total', header: 'Days Lost', render: (r: any) => fmtInt(r.days_lost_total) },
    { key: 'sample_lesson', header: 'Sample Lesson', render: (r: any) => r.sample_lesson ?? '—' },
  ];

  const typeSevCols: Column<any>[] = [
    { key: 'incident_type', header: 'Type', render: (r: any) => r.incident_type ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'incident_count', header: 'Count', render: (r: any) => fmtInt(r.incident_count) },
    { key: 'days_lost_total', header: 'Days Lost', render: (r: any) => fmtInt(r.days_lost_total) },
    { key: 'total_claim_rupees', header: 'Claim Total', render: (r: any) => fmtRupees(r.total_claim_rupees) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Accident & Injury Ledger</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        On-site engineer injuries during repair jobs, medical claim pipeline, lessons-learned ladder, and safety rating impact per engineer.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 12, marginBottom: 24 }}>
        {cards.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Incidents</h2>
        <DataTable columns={incidentCols} rows={incidents} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Engineer</h2>
        <DataTable columns={engineerCols} rows={byEngineer} rowKey={(r: any) => r.engineer_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Medical Claim Pipeline</h2>
        <DataTable columns={claimCols} rows={claimPipeline} rowKey={(r: any) => r.medical_claim_status} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Lessons-Learned Ladder</h2>
        <DataTable columns={lessonCols} rows={lessonLadder} rowKey={(r: any) => String(r.lesson_ladder_rank)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Type & Severity</h2>
        <DataTable columns={typeSevCols} rows={typeSeverity} rowKey={(r: any) => String(r.incident_type) + '-' + String(r.severity)} />
      </section>
    </div>
  );
}
