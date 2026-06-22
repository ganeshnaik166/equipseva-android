import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { StatCard } from '@/components/StatCard';

export const dynamic = 'force-dynamic';

export default async function HospitalPricingPowerAssessmentPage() {
  const sb = await getSupabaseServerClient();

  const [kpisR, bandsR, rankingR, recentR, outcomeR, actionR, pendingR] = await Promise.all([
    sb.rpc('fn_r2271_pricing_kpis'),
    sb.rpc('fn_r2271_power_band_distribution'),
    sb.rpc('fn_r2271_elasticity_ranking'),
    sb.rpc('fn_r2271_recent_hikes'),
    sb.rpc('fn_r2271_outcome_by_category'),
    sb.rpc('fn_r2271_action_queue'),
    sb.rpc('fn_r2271_pending_decisions'),
  ]);

  const kpis = kpisR.data?.[0] ?? {
    total_hospitals_assessed: 0,
    locked_in_count: 0,
    at_risk_count: 0,
    avg_elasticity: 0,
    total_hikes_logged: 0,
    acceptance_rate_pct: 0,
  };

  const bands = bandsR.data ?? [];
  const ranking = rankingR.data ?? [];
  const recent = recentR.data ?? [];
  const outcomeByCategory = outcomeR.data ?? [];
  const actionQueue = actionR.data ?? [];
  const pending = pendingR.data ?? [];

  const bandCols: Column<any>[] = [
    { key: 'power_band', header: 'Power Band', render: (r) => r.power_band },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'avg_score', header: 'Avg Elasticity', render: (r) => Number(r.avg_score).toFixed(2) },
  ];

  const rankCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'hospital_tier', header: 'Tier', render: (r) => r.hospital_tier },
    { key: 'elasticity_score', header: 'Score', render: (r) => Number(r.elasticity_score).toFixed(2) },
    { key: 'power_band', header: 'Band', render: (r) => r.power_band },
    { key: 'total_hikes', header: 'Hikes', render: (r) => r.total_hikes },
    { key: 'accepted', header: 'Accept', render: (r) => r.accepted },
    { key: 'rejected', header: 'Reject', render: (r) => r.rejected },
    { key: 'recommended_action', header: 'Action', render: (r) => r.recommended_action },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'hike_category', header: 'Category', render: (r) => r.hike_category },
    { key: 'old_rate', header: 'Old', render: (r) => `Rs ${Number(r.old_rate).toLocaleString('en-IN')}` },
    { key: 'new_rate', header: 'New', render: (r) => `Rs ${Number(r.new_rate).toLocaleString('en-IN')}` },
    { key: 'hike_pct', header: 'Hike %', render: (r) => `${Number(r.hike_pct).toFixed(2)}%` },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'final_rate', header: 'Final', render: (r) => r.final_rate ? `Rs ${Number(r.final_rate).toLocaleString('en-IN')}` : '-' },
    { key: 'pushback_notes', header: 'Notes', render: (r) => r.pushback_notes ?? '-' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'hike_category', header: 'Category', render: (r) => r.hike_category },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'accepted', header: 'Accepted', render: (r) => r.accepted },
    { key: 'negotiated', header: 'Negotiated', render: (r) => r.negotiated },
    { key: 'rejected', header: 'Rejected', render: (r) => r.rejected },
    { key: 'churned', header: 'Churned', render: (r) => r.churned },
    { key: 'acceptance_pct', header: 'Accept %', render: (r) => `${Number(r.acceptance_pct).toFixed(2)}%` },
  ];

  const actionCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'power_band', header: 'Band', render: (r) => r.power_band },
    { key: 'recommended_action', header: 'Action', render: (r) => r.recommended_action },
    { key: 'elasticity_score', header: 'Score', render: (r) => Number(r.elasticity_score).toFixed(2) },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '-' },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'hike_category', header: 'Category', render: (r) => r.hike_category },
    { key: 'hike_pct', header: 'Hike %', render: (r) => `${Number(r.hike_pct).toFixed(2)}%` },
    { key: 'new_rate', header: 'New Rate', render: (r) => `Rs ${Number(r.new_rate).toLocaleString('en-IN')}` },
    { key: 'days_since_proposed', header: 'Days Open', render: (r) => r.days_since_proposed },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Pricing-Power Assessment
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Which hospitals accept rate hikes, which push back. Lower elasticity score &eq; stronger pricing power for us.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <StatCard label="Hospitals Assessed" value={String(kpis.total_hospitals_assessed)} />
        <StatCard label="Locked-In" value={String(kpis.locked_in_count)} />
        <StatCard label="At-Risk" value={String(kpis.at_risk_count)} />
        <StatCard label="Avg Elasticity" value={Number(kpis.avg_elasticity).toFixed(2)} />
        <StatCard label="Total Hikes Logged" value={String(kpis.total_hikes_logged)} />
        <StatCard label="Acceptance Rate" value={`${Number(kpis.acceptance_rate_pct).toFixed(1)}%`} />
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Power-Band Distribution</h2>
        <DataTable columns={bandCols} rows={bands} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Elasticity Ranking (lowest = strongest hold)</h2>
        <DataTable columns={rankCols} rows={ranking} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent Hike Events</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Outcome by Category</h2>
        <DataTable columns={outcomeCols} rows={outcomeByCategory} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Action Queue</h2>
        <DataTable columns={actionCols} rows={actionQueue} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Pending Decisions (Followups)</h2>
        <DataTable columns={pendingCols} rows={pending} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
