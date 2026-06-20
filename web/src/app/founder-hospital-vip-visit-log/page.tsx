import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n == null) return '0';
  return Number(n).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function FounderHospitalVipVisitLogPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpisRaw: any = {};
  let recentVisits: any[] = [];
  let overdue: any[] = [];
  let purposeBreakdown: any[] = [];
  let coverage: any[] = [];
  let leaderboard: any[] = [];

  try {
    const r = await sb.rpc('founder_vip_visit_kpis');
    kpisRaw = (r.data as any) ?? {};
  } catch (_e) { kpisRaw = {}; }

  try {
    const r = await sb.rpc('founder_vip_recent_visits', { p_limit: 50 });
    recentVisits = (r.data as any[]) ?? [];
  } catch (_e) { recentVisits = []; }

  try {
    const r = await sb.rpc('founder_vip_overdue_followups');
    overdue = (r.data as any[]) ?? [];
  } catch (_e) { overdue = []; }

  try {
    const r = await sb.rpc('founder_vip_purpose_breakdown');
    purposeBreakdown = (r.data as any[]) ?? [];
  } catch (_e) { purposeBreakdown = []; }

  try {
    const r = await sb.rpc('founder_vip_hospital_coverage');
    coverage = (r.data as any[]) ?? [];
  } catch (_e) { coverage = []; }

  try {
    const r = await sb.rpc('founder_vip_visitor_leaderboard');
    leaderboard = (r.data as any[]) ?? [];
  } catch (_e) { leaderboard = []; }

  const kpis: Kpi[] = [
    { label: 'Total visits', value: fmtInt(kpisRaw.total_visits) },
    { label: 'Visits 30d', value: fmtInt(kpisRaw.visits_30d) },
    { label: 'Visits 90d', value: fmtInt(kpisRaw.visits_90d) },
    { label: 'Visits YTD', value: fmtInt(kpisRaw.visits_ytd) },
    { label: 'Unique hospitals', value: fmtInt(kpisRaw.unique_hospitals_visited) },
    { label: 'VIP targets', value: fmtInt(kpisRaw.vip_targets_count) },
    { label: 'Overdue visits', value: fmtInt(kpisRaw.overdue_visits) },
    { label: 'Due next 30d', value: fmtInt(kpisRaw.due_next_30d) },
    { label: 'Positive outcome %', value: String(kpisRaw.positive_outcome_pct ?? 0) + '%' },
    { label: 'Closed-won', value: fmtInt(kpisRaw.closed_won_count) },
    { label: 'Closed-lost', value: fmtInt(kpisRaw.closed_lost_count) },
    { label: 'Blockers 90d', value: fmtInt(kpisRaw.blocker_count) },
    { label: 'Avg duration min', value: fmtInt(kpisRaw.avg_duration_minutes) },
    { label: 'Founder visit share', value: String(kpisRaw.founder_visit_share_pct ?? 0) + '%' },
    { label: 'Pipeline (positive)', value: fmtRupees(kpisRaw.estimated_pipeline_rupees) },
    { label: 'Targets never visited', value: fmtInt(kpisRaw.targets_never_visited) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'visit_date', header: 'Date', render: (r: any) => r.visit_date ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'visitor_role', header: 'Role', render: (r: any) => r.visitor_role ?? '—' },
    { key: 'visit_purpose', header: 'Purpose', render: (r: any) => r.visit_purpose ?? '—' },
    { key: 'duration_minutes', header: 'Mins', render: (r: any) => fmtInt(r.duration_minutes) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'next_visit_due', header: 'Next due', render: (r: any) => r.next_visit_due ?? '—' },
    { key: 'days_until_due', header: 'Days to due', render: (r: any) => r.days_until_due == null ? '—' : String(r.days_until_due) },
    { key: 'estimated_revenue_lift_rupees', header: 'Est. lift', render: (r: any) => fmtRupees(r.estimated_revenue_lift_rupees) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'last_visit_date', header: 'Last visit', render: (r: any) => r.last_visit_date ?? '—' },
    { key: 'next_visit_due', header: 'Due', render: (r: any) => r.next_visit_due ?? '—' },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => fmtInt(r.days_overdue) },
    { key: 'last_purpose', header: 'Last purpose', render: (r: any) => r.last_purpose ?? '—' },
    { key: 'last_outcome', header: 'Last outcome', render: (r: any) => r.last_outcome ?? '—' },
  ];

  const purposeCols: Column<any>[] = [
    { key: 'visit_purpose', header: 'Purpose', render: (r: any) => r.visit_purpose ?? '—' },
    { key: 'visit_count', header: 'Visits', render: (r: any) => fmtInt(r.visit_count) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => fmtInt(r.positive_count) },
    { key: 'avg_duration', header: 'Avg min', render: (r: any) => fmtInt(r.avg_duration) },
    { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
  ];

  const coverageCols: Column<any>[] = [
    { key: 'vip_rank', header: 'Rank', render: (r: any) => fmtInt(r.vip_rank) },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'cadence_days', header: 'Cadence (d)', render: (r: any) => fmtInt(r.cadence_days) },
    { key: 'last_visit_date', header: 'Last visit', render: (r: any) => r.last_visit_date ?? '—' },
    { key: 'days_since_last_visit', header: 'Days since', render: (r: any) => r.days_since_last_visit == null ? '—' : String(r.days_since_last_visit) },
    { key: 'total_visits', header: 'Total visits', render: (r: any) => fmtInt(r.total_visits) },
    { key: 'cadence_status', header: 'Status', render: (r: any) => r.cadence_status ?? '—' },
  ];

  const leaderboardCols: Column<any>[] = [
    { key: 'visitor_email', header: 'Visitor', render: (r: any) => r.visitor_email ?? '—' },
    { key: 'visitor_role', header: 'Role', render: (r: any) => r.visitor_role ?? '—' },
    { key: 'visit_count', header: 'Visits', render: (r: any) => fmtInt(r.visit_count) },
    { key: 'unique_hospitals', header: 'Hospitals', render: (r: any) => fmtInt(r.unique_hospitals) },
    { key: 'positive_outcome_count', header: 'Positive', render: (r: any) => fmtInt(r.positive_outcome_count) },
    { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital VIP Visit Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Every visit founder/CTO/sales made to top-50 hospitals. Purpose, outcome, next-visit cadence.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent visits (last 50)</h2>
        <DataTable columns={recentCols} rows={recentVisits} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overdue follow-ups</h2>
        <DataTable columns={overdueCols} rows={overdue} rowKey={(r: any) => r.visit_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Purpose breakdown (180d)</h2>
        <DataTable columns={purposeCols} rows={purposeBreakdown} rowKey={(r: any) => r.visit_purpose} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top-50 hospital coverage</h2>
        <DataTable columns={coverageCols} rows={coverage} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Visitor leaderboard (180d)</h2>
        <DataTable columns={leaderboardCols} rows={leaderboard} rowKey={(r: any) => r.visitor_user_id} />
      </section>
    </main>
  );
}
