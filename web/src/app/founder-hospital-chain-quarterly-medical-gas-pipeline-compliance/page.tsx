import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_audits: number;
  chains_covered: number;
  sites_covered: number;
  critical_count: number;
  major_gap_count: number;
  compliant_pct: number;
  total_remediation_rupees: number;
};

type CriticalAudit = {
  id: string;
  chain_name: string;
  hospital_site: string;
  city: string;
  gas_type: string;
  compliance_status: string;
  outlets_failed: number;
  leak_rate_ppm: number;
  remediation_cost_rupees: number;
  audit_date: string;
};

type ChainRollup = {
  chain_name: string;
  sites_audited: number;
  total_outlets: number;
  failed_outlets: number;
  avg_leak_rate_ppm: number;
  avg_purity_percent: number;
  total_remediation_rupees: number;
  nabh_pct: number;
};

type GasRisk = {
  gas_type: string;
  audits_count: number;
  avg_outlets_failed: number;
  avg_leak_ppm: number;
  incidents_count: number;
  p0_p1_incidents: number;
  total_patients_at_risk: number;
};

type OpenIncident = {
  id: string;
  chain_name: string;
  hospital_site: string;
  severity: string;
  incident_type: string;
  gas_type: string;
  affected_wards: string;
  patients_at_risk: number;
  downtime_minutes: number;
  cost_rupees: number;
  incident_date: string;
  remediation_status: string;
};

type CityExposure = {
  city: string;
  sites_count: number;
  audits_count: number;
  critical_sites: number;
  total_failed_outlets: number;
  remediation_rupees: number;
};

type UpcomingAudit = {
  chain_name: string;
  hospital_site: string;
  city: string;
  gas_type: string;
  next_audit_due: string;
  days_until: number;
  last_status: string;
};

type SeveritySummary = {
  severity: string;
  incidents_count: number;
  open_count: number;
  total_downtime_minutes: number;
  total_patients_at_risk: number;
  total_cost_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpisRes,
    criticalRes,
    chainRes,
    gasRes,
    openRes,
    cityRes,
    upcomingRes,
    severityRes,
  ] = await Promise.all([
    supabase.rpc('r2915_compliance_kpis'),
    supabase.rpc('r2915_critical_audits'),
    supabase.rpc('r2915_chain_rollup'),
    supabase.rpc('r2915_gas_type_risk'),
    supabase.rpc('r2915_open_incidents'),
    supabase.rpc('r2915_city_exposure'),
    supabase.rpc('r2915_upcoming_audits'),
    supabase.rpc('r2915_incident_severity_summary'),
  ]);

  const kpi: KpiRow | null = (kpisRes.data?.[0] as KpiRow) ?? null;
  const criticals: CriticalAudit[] = (criticalRes.data ?? []) as CriticalAudit[];
  const chains: ChainRollup[] = (chainRes.data ?? []) as ChainRollup[];
  const gases: GasRisk[] = (gasRes.data ?? []) as GasRisk[];
  const opens: OpenIncident[] = (openRes.data ?? []) as OpenIncident[];
  const cities: CityExposure[] = (cityRes.data ?? []) as CityExposure[];
  const upcoming: UpcomingAudit[] = (upcomingRes.data ?? []) as UpcomingAudit[];
  const severities: SeveritySummary[] = (severityRes.data ?? []) as SeveritySummary[];

  const criticalCols: Column<CriticalAudit>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'gas_type', header: 'Gas', render: (r) => r.gas_type },
    { key: 'compliance_status', header: 'Status', render: (r) => r.compliance_status },
    { key: 'outlets_failed', header: 'Failed Outlets', render: (r) => r.outlets_failed },
    { key: 'leak_rate_ppm', header: 'Leak ppm', render: (r) => r.leak_rate_ppm },
    { key: 'remediation_cost_rupees', header: 'Remediation', render: (r) => fmtRupees(r.remediation_cost_rupees) },
    { key: 'audit_date', header: 'Audit Date', render: (r) => r.audit_date },
  ];

  const chainCols: Column<ChainRollup>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'sites_audited', header: 'Sites', render: (r) => r.sites_audited },
    { key: 'total_outlets', header: 'Outlets', render: (r) => r.total_outlets },
    { key: 'failed_outlets', header: 'Failed', render: (r) => r.failed_outlets },
    { key: 'avg_leak_rate_ppm', header: 'Avg Leak ppm', render: (r) => r.avg_leak_rate_ppm },
    { key: 'avg_purity_percent', header: 'Avg Purity %', render: (r) => r.avg_purity_percent },
    { key: 'nabh_pct', header: 'NABH %', render: (r) => r.nabh_pct },
    { key: 'total_remediation_rupees', header: 'Remediation', render: (r) => fmtRupees(r.total_remediation_rupees) },
  ];

  const gasCols: Column<GasRisk>[] = [
    { key: 'gas_type', header: 'Gas', render: (r) => r.gas_type },
    { key: 'audits_count', header: 'Audits', render: (r) => r.audits_count },
    { key: 'avg_outlets_failed', header: 'Avg Outlets Failed', render: (r) => r.avg_outlets_failed },
    { key: 'avg_leak_ppm', header: 'Avg Leak ppm', render: (r) => r.avg_leak_ppm },
    { key: 'incidents_count', header: 'Incidents', render: (r) => r.incidents_count },
    { key: 'p0_p1_incidents', header: 'P0/P1', render: (r) => r.p0_p1_incidents },
    { key: 'total_patients_at_risk', header: 'Patients at Risk', render: (r) => r.total_patients_at_risk },
  ];

  const openCols: Column<OpenIncident>[] = [
    { key: 'severity', header: 'Sev', render: (r) => r.severity.toUpperCase() },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'incident_type', header: 'Type', render: (r) => r.incident_type },
    { key: 'gas_type', header: 'Gas', render: (r) => r.gas_type },
    { key: 'affected_wards', header: 'Wards', render: (r) => r.affected_wards },
    { key: 'patients_at_risk', header: 'Patients', render: (r) => r.patients_at_risk },
    { key: 'downtime_minutes', header: 'Downtime (min)', render: (r) => r.downtime_minutes },
    { key: 'cost_rupees', header: 'Cost', render: (r) => fmtRupees(r.cost_rupees) },
    { key: 'remediation_status', header: 'Status', render: (r) => r.remediation_status },
    { key: 'incident_date', header: 'Date', render: (r) => r.incident_date },
  ];

  const cityCols: Column<CityExposure>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'sites_count', header: 'Sites', render: (r) => r.sites_count },
    { key: 'audits_count', header: 'Audits', render: (r) => r.audits_count },
    { key: 'critical_sites', header: 'Critical', render: (r) => r.critical_sites },
    { key: 'total_failed_outlets', header: 'Failed Outlets', render: (r) => r.total_failed_outlets },
    { key: 'remediation_rupees', header: 'Remediation', render: (r) => fmtRupees(r.remediation_rupees) },
  ];

  const upcomingCols: Column<UpcomingAudit>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'gas_type', header: 'Gas', render: (r) => r.gas_type },
    { key: 'next_audit_due', header: 'Due', render: (r) => r.next_audit_due },
    { key: 'days_until', header: 'Days', render: (r) => r.days_until },
    { key: 'last_status', header: 'Last Status', render: (r) => r.last_status },
  ];

  const sevCols: Column<SeveritySummary>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity.toUpperCase() },
    { key: 'incidents_count', header: 'Count', render: (r) => r.incidents_count },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r) => r.total_downtime_minutes },
    { key: 'total_patients_at_risk', header: 'Patients at Risk', render: (r) => r.total_patients_at_risk },
    { key: 'total_cost_rupees', header: 'Cost', render: (r) => fmtRupees(r.total_cost_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold">Hospital Chain Quarterly Medical-Gas Pipeline Compliance</h1>
        <p className="text-gray-600">
          Founder console r2915 — quarterly audit posture, leak & pressure exposure, NABH/HCFI gaps,
          incident severity, and remediation cost across multi-site hospital chains.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Audits</div>
          <div className="text-2xl font-semibold">{kpi?.total_audits ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Chains / Sites</div>
          <div className="text-2xl font-semibold">{kpi?.chains_covered ?? 0} / {kpi?.sites_covered ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Critical Sites</div>
          <div className="text-2xl font-semibold text-red-600">{kpi?.critical_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Major Gap Sites</div>
          <div className="text-2xl font-semibold text-amber-600">{kpi?.major_gap_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Compliant %</div>
          <div className="text-2xl font-semibold">{kpi?.compliant_pct ?? 0}%</div>
        </div>
        <div className="rounded-lg border p-4 md:col-span-3">
          <div className="text-xs text-gray-500">Total Remediation Cost</div>
          <div className="text-2xl font-semibold">{fmtRupees(kpi?.total_remediation_rupees ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Critical & Major-Gap Audits</h2>
        <DataTable
          rows={criticals}
          columns={criticalCols}
          emptyMessage="No critical or major-gap audits."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Chain-Level Rollup</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chain rollup data."
          rowKey={(r, i) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Gas-Type Risk Profile</h2>
        <DataTable
          rows={gases}
          columns={gasCols}
          emptyMessage="No gas-type data."
          rowKey={(r, i) => String(r.gas_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Open & Escalated Incidents</h2>
        <DataTable
          rows={opens}
          columns={openCols}
          emptyMessage="No open incidents."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">City-Level Exposure</h2>
        <DataTable
          rows={cities}
          columns={cityCols}
          emptyMessage="No city exposure data."
          rowKey={(r, i) => String(r.city ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Upcoming Audits (next 90 days)</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No audits scheduled in next 90 days."
          rowKey={(r, i) => String((r.chain_name ?? '') + '-' + (r.hospital_site ?? '') + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Incident Severity Summary</h2>
        <DataTable
          rows={severities}
          columns={sevCols}
          emptyMessage="No incident data."
          rowKey={(r, i) => String(r.severity ?? i)}
        />
      </section>
    </div>
  );
}
