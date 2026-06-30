import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = {
  audit_month: string;
  total_audits: number;
  passed: number;
  minor: number;
  major: number;
  critical_fails: number;
  cross_connections: number;
  total_billing_rupees: number;
};

type CriticalCross = {
  hospital_name: string;
  hospital_city: string;
  workstation_brand: string;
  o2_purity_pct: number;
  n2o_purity_pct: number;
  pipeline_pressure_bar: number;
  next_audit_due: string | null;
};

type EngineerPerf = {
  engineer_name: string;
  certification: string;
  audits_done: number;
  pass_rate_pct: number | null;
  avg_duration_min: number | null;
  total_billing_rupees: number;
};

type BrandFleet = {
  workstation_brand: string;
  fleet_count: number;
  avg_age_years: number | null;
  oldest_unit_years: number;
  failure_rate_pct: number | null;
};

type FindingsCat = {
  finding_category: string;
  total_findings: number;
  critical_count: number;
  high_count: number;
  open_count: number;
  total_rectification_cost_rupees: number;
};

type CityRisk = {
  hospital_city: string;
  hospital_tier: string;
  audit_count: number;
  cross_conn_count: number;
  avg_o2_purity: number | null;
  avg_n2o_purity: number | null;
};

type OpenFinding = {
  hospital_name: string;
  finding_category: string;
  severity: string;
  patient_risk_level: string;
  deviation_pct: number;
  corrective_action: string;
  rectification_cost_rupees: number;
  oem_dispatch_required: boolean;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    monthly,
    criticals,
    engineers,
    brands,
    findingsCats,
    cityRisk,
    openBacklog,
  ] = await Promise.all([
    supabase.rpc('rpc_r3066_monthly_audit_summary'),
    supabase.rpc('rpc_r3066_critical_cross_connections'),
    supabase.rpc('rpc_r3066_engineer_performance'),
    supabase.rpc('rpc_r3066_brand_fleet_age'),
    supabase.rpc('rpc_r3066_findings_by_category'),
    supabase.rpc('rpc_r3066_city_tier_risk'),
    supabase.rpc('rpc_r3066_open_findings_backlog'),
  ]);

  const monthlyRows: MonthlySummary[] = (monthly.data as MonthlySummary[]) ?? [];
  const criticalRows: CriticalCross[] = (criticals.data as CriticalCross[]) ?? [];
  const engineerRows: EngineerPerf[] = (engineers.data as EngineerPerf[]) ?? [];
  const brandRows: BrandFleet[] = (brands.data as BrandFleet[]) ?? [];
  const findingsCatRows: FindingsCat[] = (findingsCats.data as FindingsCat[]) ?? [];
  const cityRiskRows: CityRisk[] = (cityRisk.data as CityRisk[]) ?? [];
  const openRows: OpenFinding[] = (openBacklog.data as OpenFinding[]) ?? [];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.total_audits },
    { header: 'Pass', accessor: (r) => r.passed },
    { header: 'Minor', accessor: (r) => r.minor },
    { header: 'Major', accessor: (r) => r.major },
    { header: 'Critical', accessor: (r) => r.critical_fails },
    { header: 'X-Conn', accessor: (r) => r.cross_connections },
    { header: 'Billing (Rs)', accessor: (r) => r.total_billing_rupees.toLocaleString('en-IN') },
  ];

  const criticalCols: Column<CriticalCross>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Brand', accessor: (r) => r.workstation_brand },
    { header: 'O2 %', accessor: (r) => r.o2_purity_pct },
    { header: 'N2O %', accessor: (r) => r.n2o_purity_pct },
    { header: 'Pressure bar', accessor: (r) => r.pipeline_pressure_bar },
    { header: 'Next Audit', accessor: (r) => r.next_audit_due ?? '-' },
  ];

  const engineerCols: Column<EngineerPerf>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Cert', accessor: (r) => r.certification },
    { header: 'Audits', accessor: (r) => r.audits_done },
    { header: 'Pass %', accessor: (r) => r.pass_rate_pct ?? '-' },
    { header: 'Avg min', accessor: (r) => r.avg_duration_min ?? '-' },
    { header: 'Billing (Rs)', accessor: (r) => r.total_billing_rupees.toLocaleString('en-IN') },
  ];

  const brandCols: Column<BrandFleet>[] = [
    { header: 'Brand', accessor: (r) => r.workstation_brand },
    { header: 'Fleet', accessor: (r) => r.fleet_count },
    { header: 'Avg Age', accessor: (r) => r.avg_age_years ?? '-' },
    { header: 'Oldest', accessor: (r) => r.oldest_unit_years },
    { header: 'Failure %', accessor: (r) => r.failure_rate_pct ?? '-' },
  ];

  const findingsCatCols: Column<FindingsCat>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Total', accessor: (r) => r.total_findings },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'High', accessor: (r) => r.high_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Cost (Rs)', accessor: (r) => r.total_rectification_cost_rupees.toLocaleString('en-IN') },
  ];

  const cityRiskCols: Column<CityRisk>[] = [
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Tier', accessor: (r) => r.hospital_tier },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'X-Conn', accessor: (r) => r.cross_conn_count },
    { header: 'Avg O2 %', accessor: (r) => r.avg_o2_purity ?? '-' },
    { header: 'Avg N2O %', accessor: (r) => r.avg_n2o_purity ?? '-' },
  ];

  const openCols: Column<OpenFinding>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Risk', accessor: (r) => r.patient_risk_level },
    { header: 'Deviation %', accessor: (r) => r.deviation_pct },
    { header: 'Action', accessor: (r) => r.corrective_action },
    { header: 'Cost (Rs)', accessor: (r) => r.rectification_cost_rupees.toLocaleString('en-IN') },
    { header: 'OEM?', accessor: (r) => (r.oem_dispatch_required ? 'yes' : 'no') },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
          Engineer Monthly Customer Site Anesthesia Workstation O2/N2O Pipeline Cross-Connection Audit
        </h1>
        <p style={{ color: '#555' }}>
          Round r3066 — patient-safety critical: cross-connection between O2 &amp; N2O lines can be life-threatening.
          Pass rate target &gt;=95%. Critical findings require immediate shutdown &amp; OEM dispatch.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Audit Summary</h2>
        <DataTable<MonthlySummary>
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No audit months recorded."
          rowKey={(r, i) => String(r.audit_month ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical Cross-Connections Detected</h2>
        <DataTable<CriticalCross>
          rows={criticalRows}
          columns={criticalCols}
          emptyMessage="No cross-connections detected."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Engineer Performance (Pass % & Billing)</h2>
        <DataTable<EngineerPerf>
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer data."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Workstation Brand Fleet Age & Failure Rate</h2>
        <DataTable<BrandFleet>
          rows={brandRows}
          columns={brandCols}
          emptyMessage="No fleet data."
          rowKey={(r, i) => String(r.workstation_brand ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Findings by Category</h2>
        <DataTable<FindingsCat>
          rows={findingsCatRows}
          columns={findingsCatCols}
          emptyMessage="No findings recorded."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>City & Tier Risk Profile</h2>
        <DataTable<CityRisk>
          rows={cityRiskRows}
          columns={cityRiskCols}
          emptyMessage="No city data."
          rowKey={(r, i) => String((r.hospital_city ?? '') + (r.hospital_tier ?? '') + i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open Findings Backlog (Severity sorted)</h2>
        <DataTable<OpenFinding>
          rows={openRows}
          columns={openCols}
          emptyMessage="No open findings — all rectified."
          rowKey={(r, i) => String(r.hospital_name + r.finding_category + i)}
        />
      </section>
    </div>
  );
}
