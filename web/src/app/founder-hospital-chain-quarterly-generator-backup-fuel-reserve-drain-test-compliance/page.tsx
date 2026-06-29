import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ReserveSummary = { chain_code: string; sites: number; avg_reserve_pct: number; red_sites: number; amber_sites: number; green_sites: number };
type CriticalLow = { chain_code: string; hospital_site: string; generator_tag: string; reserve_percent: number; days_of_autonomy: number; next_topup_due: string };
type Outcome = { test_outcome: string; n: number; avg_load: number; avg_duration: number };
type DefectRegion = { region: string; critical: number; major: number; minor: number; safety_hold: number; none_clean: number };
type FuelMix = { fuel_type: string; sites: number; total_capacity_litres: number; total_reserve_litres: number };
type Witness = { nabh_witness: string; tests: number; pass_rate_pct: number };
type CertBacklog = { cert_uploaded: string; n: number; last_test_date: string };
type RiskScore = { chain_code: string; hospital_site: string; reserve_pct: number; last_outcome: string; defect_class: string; risk_score: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [summary, critical, outcome, defect, fuel, witness, cert, risk] = await Promise.all([
    sb.rpc('r2995_reserve_summary_by_chain'),
    sb.rpc('r2995_critical_low_sites'),
    sb.rpc('r2995_drain_outcome_distribution'),
    sb.rpc('r2995_defect_by_region'),
    sb.rpc('r2995_fuel_type_mix'),
    sb.rpc('r2995_nabh_witness_coverage'),
    sb.rpc('r2995_cert_upload_backlog'),
    sb.rpc('r2995_site_risk_score'),
  ]);

  const summaryRows: ReserveSummary[] = (summary.data ?? []) as ReserveSummary[];
  const criticalRows: CriticalLow[] = (critical.data ?? []) as CriticalLow[];
  const outcomeRows: Outcome[] = (outcome.data ?? []) as Outcome[];
  const defectRows: DefectRegion[] = (defect.data ?? []) as DefectRegion[];
  const fuelRows: FuelMix[] = (fuel.data ?? []) as FuelMix[];
  const witnessRows: Witness[] = (witness.data ?? []) as Witness[];
  const certRows: CertBacklog[] = (cert.data ?? []) as CertBacklog[];
  const riskRows: RiskScore[] = (risk.data ?? []) as RiskScore[];

  const summaryCols: Column<ReserveSummary>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Sites', accessor: (r) => r.sites },
    { header: 'Avg Reserve %', accessor: (r) => r.avg_reserve_pct },
    { header: 'Red', accessor: (r) => r.red_sites },
    { header: 'Amber', accessor: (r) => r.amber_sites },
    { header: 'Green', accessor: (r) => r.green_sites },
  ];

  const criticalCols: Column<CriticalLow>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Gen', accessor: (r) => r.generator_tag },
    { header: 'Reserve %', accessor: (r) => r.reserve_percent },
    { header: 'Days Autonomy', accessor: (r) => r.days_of_autonomy },
    { header: 'Next Topup', accessor: (r) => r.next_topup_due },
  ];

  const outcomeCols: Column<Outcome>[] = [
    { header: 'Outcome', accessor: (r) => r.test_outcome },
    { header: 'Tests', accessor: (r) => r.n },
    { header: 'Avg Load %', accessor: (r) => r.avg_load },
    { header: 'Avg Duration (min)', accessor: (r) => r.avg_duration },
  ];

  const defectCols: Column<DefectRegion>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Critical', accessor: (r) => r.critical },
    { header: 'Major', accessor: (r) => r.major },
    { header: 'Minor', accessor: (r) => r.minor },
    { header: 'Safety Hold', accessor: (r) => r.safety_hold },
    { header: 'Clean', accessor: (r) => r.none_clean },
  ];

  const fuelCols: Column<FuelMix>[] = [
    { header: 'Fuel Type', accessor: (r) => r.fuel_type },
    { header: 'Sites', accessor: (r) => r.sites },
    { header: 'Tank Capacity (L)', accessor: (r) => r.total_capacity_litres },
    { header: 'Reserve (L)', accessor: (r) => r.total_reserve_litres },
  ];

  const witnessCols: Column<Witness>[] = [
    { header: 'NABH Witness', accessor: (r) => r.nabh_witness },
    { header: 'Tests', accessor: (r) => r.tests },
    { header: 'Pass Rate %', accessor: (r) => r.pass_rate_pct },
  ];

  const certCols: Column<CertBacklog>[] = [
    { header: 'Cert Upload', accessor: (r) => r.cert_uploaded },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Last Test', accessor: (r) => r.last_test_date },
  ];

  const riskCols: Column<RiskScore>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Reserve %', accessor: (r) => r.reserve_pct },
    { header: 'Last Outcome', accessor: (r) => r.last_outcome },
    { header: 'Defect', accessor: (r) => r.defect_class },
    { header: 'Risk Score', accessor: (r) => r.risk_score },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Generator-Backup Fuel Reserve & Drain Test Compliance</h1>
        <p className="text-sm text-gray-600">Quarterly fuel-reserve telemetry & NABH drain-test outcomes across hospital chains. Founder-only.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reserve summary by chain</h2>
        <DataTable rows={summaryRows} columns={summaryCols} emptyMessage="No chain data" rowKey={(r, i) => String((r as ReserveSummary).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical-low & below-target sites</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical sites" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Drain-test outcome distribution</h2>
        <DataTable rows={outcomeRows} columns={outcomeCols} emptyMessage="No outcomes" rowKey={(r, i) => String((r as Outcome).test_outcome ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Defect class by region</h2>
        <DataTable rows={defectRows} columns={defectCols} emptyMessage="No defects" rowKey={(r, i) => String((r as DefectRegion).region ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fuel-type mix</h2>
        <DataTable rows={fuelRows} columns={fuelCols} emptyMessage="No fuel data" rowKey={(r, i) => String((r as FuelMix).fuel_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">NABH witness coverage</h2>
        <DataTable rows={witnessRows} columns={witnessCols} emptyMessage="No witness data" rowKey={(r, i) => String((r as Witness).nabh_witness ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cert upload backlog</h2>
        <DataTable rows={certRows} columns={certCols} emptyMessage="No cert data" rowKey={(r, i) => String((r as CertBacklog).cert_uploaded ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top-20 site risk score</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No risk data" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
