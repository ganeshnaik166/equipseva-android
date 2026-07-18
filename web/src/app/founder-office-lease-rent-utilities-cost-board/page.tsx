import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { lease_verdict: string; locations: number; pct: number };
type CityRow = {
  city: string;
  locations: number;
  total_monthly_rent_rupees: number;
  total_monthly_utilities_rupees: number;
  avg_occupancy_pct: number;
  avg_rent_per_seat_rupees: number;
  at_risk_locations: number;
  healthy_pct: number;
};
type MatrixRow = {
  site_type: string;
  lease_verdict: string;
  locations: number;
  total_monthly_rent_rupees: number;
  avg_occupancy_pct: number;
};
type TrendRow = {
  lease_end: string;
  expiring_locations: number;
  monthly_rent_at_stake_rupees: number;
  pending_or_renegotiate: number;
  exit_or_relocate: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_savings_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_rupees: number;
  pct: number;
};
type ImpactRow = {
  cost_impact: string;
  findings: number;
  open_findings: number;
  total_savings_rupees: number;
};
type RiskRow = {
  location_name: string;
  city: string;
  site_type: string;
  lease_end: string;
  monthly_rent_rupees: number;
  occupancy_pct: number | null;
  renewal_decision: string;
  lease_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    cityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3249_lease_verdict_rollup'),
    supabase.rpc('founder_r3249_city_cost_scorecard'),
    supabase.rpc('founder_r3249_site_type_verdict_matrix'),
    supabase.rpc('founder_r3249_lease_expiry_trend'),
    supabase.rpc('founder_r3249_capa_status_board'),
    supabase.rpc('founder_r3249_root_cause_pareto'),
    supabase.rpc('founder_r3249_cost_impact_digest'),
    supabase.rpc('founder_r3249_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const cityRows: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'lease_verdict', header: 'Verdict' },
    { key: 'locations', header: 'Locations' },
    { key: 'pct', header: 'Share %' },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City' },
    { key: 'locations', header: 'Locations' },
    { key: 'total_monthly_rent_rupees', header: 'Monthly Rent (INR)' },
    { key: 'total_monthly_utilities_rupees', header: 'Monthly Utilities (INR)' },
    { key: 'avg_occupancy_pct', header: 'Avg Occupancy %' },
    { key: 'avg_rent_per_seat_rupees', header: 'Avg Rent/Seat (INR)' },
    { key: 'at_risk_locations', header: 'At Risk' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'site_type', header: 'Site Type' },
    { key: 'lease_verdict', header: 'Verdict' },
    { key: 'locations', header: 'Locations' },
    { key: 'total_monthly_rent_rupees', header: 'Monthly Rent (INR)' },
    { key: 'avg_occupancy_pct', header: 'Avg Occupancy %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'lease_end', header: 'Lease End' },
    { key: 'expiring_locations', header: 'Locations' },
    { key: 'monthly_rent_at_stake_rupees', header: 'Rent at Stake (INR/mo)' },
    { key: 'pending_or_renegotiate', header: 'Pending / Renegotiate' },
    { key: 'exit_or_relocate', header: 'Exit / Relocate / Downsize' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_savings_rupees', header: 'Avg Savings (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'cost_impact', header: 'Cost Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'location_name', header: 'Location' },
    { key: 'city', header: 'City' },
    { key: 'site_type', header: 'Site Type' },
    { key: 'lease_end', header: 'Lease End' },
    { key: 'monthly_rent_rupees', header: 'Monthly Rent (INR)' },
    { key: 'occupancy_pct', header: 'Occupancy %' },
    { key: 'renewal_decision', header: 'Decision' },
    { key: 'lease_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Office Lease, Rent &amp; Utilities Cost Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Location cost register — site type &times; lease window &times; monthly rent &amp; security
        deposit &times; escalation clause &times; lock-in &times; utilities spend &times; seat
        occupancy &times; rent-per-seat &amp; renewal decision. Founder-gated view: lease verdicts,
        city cost scorecards, expiry runway, and cost-optimization CAPA across all EquipSeva
        offices, warehouses and service centers.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Lease verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No lease records logged yet."
          rowKey={(r, i) => String(r.lease_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. City cost scorecard</h2>
        <DataTable
          rows={cityRows}
          columns={cityCols}
          emptyMessage="No city rollups."
          rowKey={(r, i) => String(r.city ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Site type &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No leases by site type."
          rowKey={(r, i) => `${r.site_type}-${r.lease_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Lease expiry trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No expiry data."
          rowKey={(r, i) => String(r.lease_end ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No cost-impact rollups."
          rowKey={(r, i) => String(r.cost_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk lease queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk leases."
          rowKey={(r, i) => `${r.location_name}-${r.lease_end}-${i}`}
        />
      </section>
    </main>
  );
}
