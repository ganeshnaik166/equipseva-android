import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n ?? 0);
  return Number.isFinite(v) ? v.toLocaleString('en-IN') : '0';
}

function fmtRupees(n: any): string {
  const v = Number(n ?? 0);
  return Number.isFinite(v) ? '₹' + v.toLocaleString('en-IN') : '₹0';
}

function fmtNum(n: any, digits = 1): string {
  const v = Number(n ?? 0);
  return Number.isFinite(v) ? v.toFixed(digits) : '0';
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return '—'; }
}

export default async function FounderRuralDeploymentPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let enrollments: any[] = [];
  let trips: any[] = [];
  let coverage: any[] = [];
  let scoreboard: any[] = [];
  let underserved: any[] = [];
  let monthly: any[] = [];

  try {
    const r = await sb.rpc('founder_rural_overview_kpis_v4');
    kpis = (r.data as any) ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_rural_enrollments_list_v4', { p_limit: 100 });
    enrollments = (r.data as any[]) ?? [];
  } catch { enrollments = []; }

  try {
    const r = await sb.rpc('founder_rural_trips_recent_v4', { p_limit: 100 });
    trips = (r.data as any[]) ?? [];
  } catch { trips = []; }

  try {
    const r = await sb.rpc('founder_rural_district_coverage_v4');
    coverage = (r.data as any[]) ?? [];
  } catch { coverage = []; }

  try {
    const r = await sb.rpc('founder_rural_engineer_scoreboard_v4');
    scoreboard = (r.data as any[]) ?? [];
  } catch { scoreboard = []; }

  try {
    const r = await sb.rpc('founder_rural_underserved_districts_v4');
    underserved = (r.data as any[]) ?? [];
  } catch { underserved = []; }

  try {
    const r = await sb.rpc('founder_rural_monthly_spend_v4');
    monthly = (r.data as any[]) ?? [];
  } catch { monthly = []; }

  const cards: Kpi[] = [
    { label: 'Total Enrolled', value: fmtInt(kpis.total_enrolled) },
    { label: 'Active Enrolled', value: fmtInt(kpis.active_enrolled) },
    { label: 'Total Trips', value: fmtInt(kpis.total_trips) },
    { label: 'Successful Trips', value: fmtInt(kpis.successful_trips) },
    { label: 'Partial Trips', value: fmtInt(kpis.partial_trips) },
    { label: 'Failed Trips', value: fmtInt(kpis.failed_trips) },
    { label: 'Pending Trips', value: fmtInt(kpis.pending_trips) },
    { label: 'Total Km', value: fmtNum(kpis.total_km, 1) },
    { label: 'Travel Cost', value: fmtRupees(kpis.total_travel_cost_rupees) },
    { label: 'Per-Diem Paid', value: fmtRupees(kpis.total_per_diem_rupees) },
    { label: 'Monthly Stipend Outflow', value: fmtRupees(kpis.monthly_stipend_outflow_rupees) },
    { label: 'Jobs Completed', value: fmtInt(kpis.jobs_completed) },
    { label: 'Jobs Attempted', value: fmtInt(kpis.jobs_attempted) },
    { label: 'Districts Touched', value: fmtInt(kpis.distinct_districts) },
    { label: 'States Touched', value: fmtInt(kpis.distinct_states) },
    { label: 'Avg Km / Trip', value: fmtNum(kpis.avg_km_per_trip, 1) },
  ];

  const enrollCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'cached_highest_tier', header: 'Tier', render: (r: any) => r.cached_highest_tier ?? '—' },
    { key: 'willing', header: 'Willing', render: (r: any) => (r.willing ? 'Yes' : 'No') },
    { key: 'home_state', header: 'Home State', render: (r: any) => r.home_state ?? '—' },
    { key: 'preferred_states_count', header: 'Pref States', render: (r: any) => fmtInt(r.preferred_states_count) },
    { key: 'preferred_districts_count', header: 'Pref Districts', render: (r: any) => fmtInt(r.preferred_districts_count) },
    { key: 'max_travel_km', header: 'Max Km', render: (r: any) => fmtInt(r.max_travel_km) },
    { key: 'monthly_stipend_rupees', header: 'Stipend/mo', render: (r: any) => fmtRupees(r.monthly_stipend_rupees) },
    { key: 'per_km_allowance_paise', header: 'Per Km (paise)', render: (r: any) => fmtInt(r.per_km_allowance_paise) },
    { key: 'per_diem_rupees', header: 'Per Diem', render: (r: any) => fmtRupees(r.per_diem_rupees) },
    { key: 'vehicle_type', header: 'Vehicle', render: (r: any) => r.vehicle_type ?? '—' },
    { key: 'enrolled_at', header: 'Enrolled', render: (r: any) => fmtDate(r.enrolled_at) },
    { key: 'paused_at', header: 'Paused', render: (r: any) => fmtDate(r.paused_at) },
  ];

  const tripCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'trip_state', header: 'State', render: (r: any) => r.trip_state ?? '—' },
    { key: 'trip_district', header: 'District', render: (r: any) => r.trip_district ?? '—' },
    { key: 'trip_pincode', header: 'Pincode', render: (r: any) => r.trip_pincode ?? '—' },
    { key: 'distance_km', header: 'Km', render: (r: any) => fmtNum(r.distance_km, 1) },
    { key: 'departed_at', header: 'Departed', render: (r: any) => fmtDate(r.departed_at) },
    { key: 'returned_at', header: 'Returned', render: (r: any) => fmtDate(r.returned_at) },
    { key: 'duration_days', header: 'Days', render: (r: any) => fmtNum(r.duration_days, 1) },
    { key: 'jobs_completed', header: 'Jobs Done', render: (r: any) => fmtInt(r.jobs_completed) },
    { key: 'jobs_attempted', header: 'Jobs Tried', render: (r: any) => fmtInt(r.jobs_attempted) },
    { key: 'hospitals_visited', header: 'Hospitals', render: (r: any) => fmtInt(r.hospitals_visited) },
    { key: 'travel_cost_rupees', header: 'Travel', render: (r: any) => fmtRupees(r.travel_cost_rupees) },
    { key: 'per_diem_paid_rupees', header: 'Per Diem', render: (r: any) => fmtRupees(r.per_diem_paid_rupees) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  const coverageCols: Column<any>[] = [
    { key: 'trip_state', header: 'State', render: (r: any) => r.trip_state ?? '—' },
    { key: 'trip_district', header: 'District', render: (r: any) => r.trip_district ?? '—' },
    { key: 'trip_count', header: 'Trips', render: (r: any) => fmtInt(r.trip_count) },
    { key: 'successful_count', header: 'Successful', render: (r: any) => fmtInt(r.successful_count) },
    { key: 'unique_engineers', header: 'Engineers', render: (r: any) => fmtInt(r.unique_engineers) },
    { key: 'total_km', header: 'Km', render: (r: any) => fmtNum(r.total_km, 1) },
    { key: 'total_travel_cost_rupees', header: 'Travel Spend', render: (r: any) => fmtRupees(r.total_travel_cost_rupees) },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => fmtInt(r.jobs_completed) },
    { key: 'last_visit_at', header: 'Last Visit', render: (r: any) => fmtDate(r.last_visit_at) },
  ];

  const scoreCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'trip_count', header: 'Trips', render: (r: any) => fmtInt(r.trip_count) },
    { key: 'successful_count', header: 'Successful', render: (r: any) => fmtInt(r.successful_count) },
    { key: 'total_km', header: 'Total Km', render: (r: any) => fmtNum(r.total_km, 1) },
    { key: 'jobs_completed', header: 'Jobs Done', render: (r: any) => fmtInt(r.jobs_completed) },
    { key: 'travel_cost_rupees', header: 'Travel', render: (r: any) => fmtRupees(r.travel_cost_rupees) },
    { key: 'per_diem_rupees', header: 'Per Diem', render: (r: any) => fmtRupees(r.per_diem_rupees) },
    { key: 'distinct_districts', header: 'Districts', render: (r: any) => fmtInt(r.distinct_districts) },
    { key: 'last_trip_at', header: 'Last Trip', render: (r: any) => fmtDate(r.last_trip_at) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Engineer Rural Deployment Tracker</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        r1578 · Rural-willing engineers, stipend & allowance economics, per-trip outcomes, and underserved district coverage.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        {cards.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Enrollments</h2>
        <DataTable columns={enrollCols} rows={enrollments} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Trips</h2>
        <DataTable columns={tripCols} rows={trips} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>District Coverage</h2>
        <DataTable columns={coverageCols} rows={coverage} rowKey={(r: any) => (r.trip_state ?? '') + '|' + (r.trip_district ?? '')} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Scoreboard</h2>
        <DataTable columns={scoreCols} rows={scoreboard} rowKey={(r: any) => r.engineer_id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Underserved Districts</h2>
        <DataTable
          columns={[
            { key: 'state_name', header: 'State', render: (r: any) => r.state_name ?? '—' },
            { key: 'district', header: 'District', render: (r: any) => r.district ?? '—' },
            { key: 'trips', header: 'Trips', render: (r: any) => fmtInt(r.trips) },
            { key: 'successful', header: 'Successful', render: (r: any) => fmtInt(r.successful) },
            { key: 'last_visit_at', header: 'Last Visit', render: (r: any) => fmtDate(r.last_visit_at) },
            { key: 'days_since_visit', header: 'Days Since', render: (r: any) => fmtNum(r.days_since_visit, 0) },
          ]}
          rows={underserved}
          rowKey={(r: any) => (r.state_name ?? '') + '|' + (r.district ?? '')}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Spend</h2>
        <DataTable
          columns={[
            { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
            { key: 'trip_count', header: 'Trips', render: (r: any) => fmtInt(r.trip_count) },
            { key: 'total_km', header: 'Km', render: (r: any) => fmtNum(r.total_km, 1) },
            { key: 'travel_cost_rupees', header: 'Travel', render: (r: any) => fmtRupees(r.travel_cost_rupees) },
            { key: 'per_diem_rupees', header: 'Per Diem', render: (r: any) => fmtRupees(r.per_diem_rupees) },
            { key: 'combined_cost_rupees', header: 'Total Cost', render: (r: any) => fmtRupees(r.combined_cost_rupees) },
          ]}
          rows={monthly}
          rowKey={(r: any) => String(r.month_start)}
        />
      </section>
    </div>
  );
}
