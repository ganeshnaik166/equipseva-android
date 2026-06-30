import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioRow = {
  lender_type: string;
  facility_count: number;
  total_sanctioned_rupees: number;
  total_utilized_rupees: number;
  total_headroom_rupees: number;
  utilization_pct: number;
  avg_interest_rate_pct: number;
};

type CovenantRow = {
  covenant_status: string;
  facility_count: number;
  exposure_rupees: number;
  pct_of_portfolio: number;
};

type HeadroomRow = {
  facility_code: string;
  lender_name: string;
  facility_type: string;
  sanctioned_rupees: number;
  utilized_rupees: number;
  headroom_rupees: number;
  utilization_pct: number;
  covenant_status: string;
};

type ScenarioRow = {
  scenario: string;
  snapshot_count: number;
  avg_interest_cover_ratio: number;
  avg_dscr: number;
  breach_count: number;
  total_headroom_rupees: number;
  avg_runway_days: number;
};

type BreachRow = {
  facility_code: string;
  lender_name: string;
  scenario: string;
  interest_cover_ratio: number;
  debt_service_cover_ratio: number;
  current_ratio: number;
  debt_to_equity_ratio: number;
  headroom_rupees: number;
  remediation_action: string | null;
};

type CoverDistRow = {
  cover_band: string;
  snapshot_count: number;
  pct_of_total: number;
  avg_headroom_rupees: number;
};

type RemediationRow = {
  remediation_action: string;
  action_count: number;
  affected_facilities: number;
  total_exposure_rupees: number;
  min_runway_days: number;
};

type FacilityTypeRow = {
  facility_type: string;
  facility_count: number;
  total_sanctioned_rupees: number;
  total_utilized_rupees: number;
  weighted_avg_rate_pct: number;
  pct_of_total_sanctioned: number;
};

type CollateralRow = {
  collateral_type: string;
  facility_count: number;
  total_exposure_rupees: number;
  avg_interest_rate_pct: number;
  watchlist_or_breach_count: number;
};

function formatRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  if (n >= 10000000) return `Rs ${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `Rs ${(n / 100000).toFixed(2)} L`;
  return `Rs ${n.toLocaleString('en-IN')}`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    portfolioRes,
    covenantRes,
    headroomRes,
    scenarioRes,
    breachRes,
    coverDistRes,
    remediationRes,
    facilityTypeRes,
    collateralRes,
  ] = await Promise.all([
    supabase.rpc('facility_portfolio_summary_r3101'),
    supabase.rpc('covenant_status_breakdown_r3101'),
    supabase.rpc('facility_headroom_ranking_r3101'),
    supabase.rpc('stress_scenario_summary_r3101'),
    supabase.rpc('covenant_breach_drilldown_r3101'),
    supabase.rpc('interest_cover_distribution_r3101'),
    supabase.rpc('remediation_action_queue_r3101'),
    supabase.rpc('facility_type_concentration_r3101'),
    supabase.rpc('collateral_exposure_breakdown_r3101'),
  ]);

  const portfolio = (portfolioRes.data ?? []) as PortfolioRow[];
  const covenant = (covenantRes.data ?? []) as CovenantRow[];
  const headroom = (headroomRes.data ?? []) as HeadroomRow[];
  const scenario = (scenarioRes.data ?? []) as ScenarioRow[];
  const breach = (breachRes.data ?? []) as BreachRow[];
  const coverDist = (coverDistRes.data ?? []) as CoverDistRow[];
  const remediation = (remediationRes.data ?? []) as RemediationRow[];
  const facilityType = (facilityTypeRes.data ?? []) as FacilityTypeRow[];
  const collateral = (collateralRes.data ?? []) as CollateralRow[];

  const portfolioCols: Column<PortfolioRow>[] = [
    { key: 'lender_type', header: 'Lender Type' },
    { key: 'facility_count', header: 'Facilities' },
    { key: 'total_sanctioned_rupees', header: 'Sanctioned', render: (r) => formatRupees(r.total_sanctioned_rupees) },
    { key: 'total_utilized_rupees', header: 'Utilized', render: (r) => formatRupees(r.total_utilized_rupees) },
    { key: 'total_headroom_rupees', header: 'Headroom', render: (r) => formatRupees(r.total_headroom_rupees) },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'avg_interest_rate_pct', header: 'Avg Rate %' },
  ];

  const covenantCols: Column<CovenantRow>[] = [
    { key: 'covenant_status', header: 'Covenant Status' },
    { key: 'facility_count', header: 'Facilities' },
    { key: 'exposure_rupees', header: 'Exposure', render: (r) => formatRupees(r.exposure_rupees) },
    { key: 'pct_of_portfolio', header: '% Portfolio' },
  ];

  const headroomCols: Column<HeadroomRow>[] = [
    { key: 'facility_code', header: 'Code' },
    { key: 'lender_name', header: 'Lender' },
    { key: 'facility_type', header: 'Type' },
    { key: 'sanctioned_rupees', header: 'Sanctioned', render: (r) => formatRupees(r.sanctioned_rupees) },
    { key: 'utilized_rupees', header: 'Utilized', render: (r) => formatRupees(r.utilized_rupees) },
    { key: 'headroom_rupees', header: 'Headroom', render: (r) => formatRupees(r.headroom_rupees) },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'covenant_status', header: 'Covenant' },
  ];

  const scenarioCols: Column<ScenarioRow>[] = [
    { key: 'scenario', header: 'Scenario' },
    { key: 'snapshot_count', header: 'Snapshots' },
    { key: 'avg_interest_cover_ratio', header: 'Avg ICR' },
    { key: 'avg_dscr', header: 'Avg DSCR' },
    { key: 'breach_count', header: 'Breaches' },
    { key: 'total_headroom_rupees', header: 'Headroom', render: (r) => formatRupees(r.total_headroom_rupees) },
    { key: 'avg_runway_days', header: 'Avg Days Runway' },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'facility_code', header: 'Code' },
    { key: 'lender_name', header: 'Lender' },
    { key: 'scenario', header: 'Scenario' },
    { key: 'interest_cover_ratio', header: 'ICR' },
    { key: 'debt_service_cover_ratio', header: 'DSCR' },
    { key: 'current_ratio', header: 'Curr Ratio' },
    { key: 'debt_to_equity_ratio', header: 'D/E' },
    { key: 'headroom_rupees', header: 'Headroom', render: (r) => formatRupees(r.headroom_rupees) },
    { key: 'remediation_action', header: 'Remediation' },
  ];

  const coverDistCols: Column<CoverDistRow>[] = [
    { key: 'cover_band', header: 'ICR Band' },
    { key: 'snapshot_count', header: 'Snapshots' },
    { key: 'pct_of_total', header: '% Total' },
    { key: 'avg_headroom_rupees', header: 'Avg Headroom', render: (r) => formatRupees(r.avg_headroom_rupees) },
  ];

  const remediationCols: Column<RemediationRow>[] = [
    { key: 'remediation_action', header: 'Action' },
    { key: 'action_count', header: 'Count' },
    { key: 'affected_facilities', header: 'Facilities' },
    { key: 'total_exposure_rupees', header: 'Exposure', render: (r) => formatRupees(r.total_exposure_rupees) },
    { key: 'min_runway_days', header: 'Min Days Runway' },
  ];

  const facilityTypeCols: Column<FacilityTypeRow>[] = [
    { key: 'facility_type', header: 'Facility Type' },
    { key: 'facility_count', header: 'Count' },
    { key: 'total_sanctioned_rupees', header: 'Sanctioned', render: (r) => formatRupees(r.total_sanctioned_rupees) },
    { key: 'total_utilized_rupees', header: 'Utilized', render: (r) => formatRupees(r.total_utilized_rupees) },
    { key: 'weighted_avg_rate_pct', header: 'Wtd Avg Rate %' },
    { key: 'pct_of_total_sanctioned', header: '% Sanctioned' },
  ];

  const collateralCols: Column<CollateralRow>[] = [
    { key: 'collateral_type', header: 'Collateral' },
    { key: 'facility_count', header: 'Facilities' },
    { key: 'total_exposure_rupees', header: 'Exposure', render: (r) => formatRupees(r.total_exposure_rupees) },
    { key: 'avg_interest_rate_pct', header: 'Avg Rate %' },
    { key: 'watchlist_or_breach_count', header: 'Watch/Breach' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Lender & Bank Credit Facility Headroom Stress Tracker</h1>
        <p className="mt-2 text-sm text-gray-600">
          Round r3101 · Quarterly strategic view of working-capital lines, invoice discounting, overdrafts.
          Bank × sanctioned vs utilized × covenant compliance × interest cover × headroom under stress.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-semibold">1. Portfolio Summary by Lender Type</h2>
        <DataTable
          rows={portfolio}
          columns={portfolioCols}
          emptyMessage="No portfolio data."
          rowKey={(r, i) => String(r.lender_type ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">2. Covenant Status Breakdown</h2>
        <DataTable
          rows={covenant}
          columns={covenantCols}
          emptyMessage="No covenant data."
          rowKey={(r, i) => String(r.covenant_status ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">3. Facility Headroom Ranking (Tightest First)</h2>
        <DataTable
          rows={headroom}
          columns={headroomCols}
          emptyMessage="No facility data."
          rowKey={(r, i) => String(r.facility_code ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">4. Stress Scenario Summary</h2>
        <DataTable
          rows={scenario}
          columns={scenarioCols}
          emptyMessage="No scenario data."
          rowKey={(r, i) => String(r.scenario ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">5. Covenant Breach Drilldown</h2>
        <DataTable
          rows={breach}
          columns={breachCols}
          emptyMessage="No covenant breaches detected."
          rowKey={(r, i) => String(`${r.facility_code}-${r.scenario}` ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">6. Interest Cover Ratio Distribution</h2>
        <DataTable
          rows={coverDist}
          columns={coverDistCols}
          emptyMessage="No ICR distribution data."
          rowKey={(r, i) => String(r.cover_band ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">7. Remediation Action Queue (Most Urgent First)</h2>
        <DataTable
          rows={remediation}
          columns={remediationCols}
          emptyMessage="No remediation actions pending."
          rowKey={(r, i) => String(r.remediation_action ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">8. Facility Type Concentration & Collateral Exposure</h2>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
          <DataTable
            rows={facilityType}
            columns={facilityTypeCols}
            emptyMessage="No facility-type data."
            rowKey={(r, i) => String(r.facility_type ?? i)}
          />
          <DataTable
            rows={collateral}
            columns={collateralCols}
            emptyMessage="No collateral data."
            rowKey={(r, i) => String(r.collateral_type ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
