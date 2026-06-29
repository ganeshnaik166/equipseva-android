import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainSummary = {
  hospital_chain_name: string;
  total_cycles: number;
  failed_cycles: number;
  pass_rate_pct: number | null;
  total_incidents: number;
  unresolved_incidents: number;
};

type StageRow = {
  reprocessing_stage: string;
  total_cycles: number;
  failures: number;
  failure_rate_pct: number | null;
  avg_duration_minutes: number | null;
};

type QuarterRow = {
  quarter_label: string;
  cycles_count: number;
  failed_count: number;
  incidents_count: number;
  total_fines_rupees: number;
  patients_exposed: number;
};

type ScopeRow = {
  scope_serial: string;
  scope_model: string;
  hospital_chain_name: string;
  hospital_branch_city: string;
  total_cycles: number;
  failed_cycles: number;
  fail_pct: number | null;
};

type SeverityRow = {
  severity: string;
  incident_count: number;
  patients_exposed: number;
  total_fines_rupees: number;
  avg_resolution_days: number | null;
  regulatory_reports: number;
};

type ChemRow = {
  chemical_used: string;
  cycles_run: number;
  avg_concentration_ppm: number | null;
  avg_temperature_c: number | null;
  pass_rate_pct: number | null;
  avg_cost_rupees: number | null;
};

type IncidentRow = {
  id: string;
  hospital_chain_name: string;
  hospital_branch_city: string;
  quarter_label: string;
  incident_opened_at: string;
  incident_category: string;
  severity: string;
  scope_serial: string;
  patients_exposed_count: number;
  root_cause: string;
  fine_imposed_rupees: number;
};

type BranchRow = {
  hospital_chain_name: string;
  hospital_branch_city: string;
  cycles: number;
  failures: number;
  incidents: number;
  patients_exposed: number;
  total_fines_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(1) + '%';
}

function fmtDateTime(s: string): string {
  try {
    return new Date(s).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    chainSummary,
    stageBreakdown,
    quarterTrend,
    riskScopes,
    severityMatrix,
    chemicalAudit,
    openIncidents,
    branchHeatmap,
  ] = await Promise.all([
    supabase.rpc('r2911_chain_compliance_summary'),
    supabase.rpc('r2911_stage_failure_breakdown'),
    supabase.rpc('r2911_quarterly_trend'),
    supabase.rpc('r2911_top_risk_scopes'),
    supabase.rpc('r2911_incident_severity_matrix'),
    supabase.rpc('r2911_chemical_efficacy_audit'),
    supabase.rpc('r2911_open_incidents_log'),
    supabase.rpc('r2911_branch_heatmap'),
  ]);

  const chains: ChainSummary[] = (chainSummary.data as ChainSummary[]) ?? [];
  const stages: StageRow[] = (stageBreakdown.data as StageRow[]) ?? [];
  const quarters: QuarterRow[] = (quarterTrend.data as QuarterRow[]) ?? [];
  const scopes: ScopeRow[] = (riskScopes.data as ScopeRow[]) ?? [];
  const severity: SeverityRow[] = (severityMatrix.data as SeverityRow[]) ?? [];
  const chemicals: ChemRow[] = (chemicalAudit.data as ChemRow[]) ?? [];
  const incidents: IncidentRow[] = (openIncidents.data as IncidentRow[]) ?? [];
  const branches: BranchRow[] = (branchHeatmap.data as BranchRow[]) ?? [];

  const totalCycles = chains.reduce((s, c) => s + Number(c.total_cycles ?? 0), 0);
  const totalFailures = chains.reduce((s, c) => s + Number(c.failed_cycles ?? 0), 0);
  const totalIncidents = chains.reduce((s, c) => s + Number(c.total_incidents ?? 0), 0);
  const unresolved = chains.reduce((s, c) => s + Number(c.unresolved_incidents ?? 0), 0);
  const totalFines = quarters.reduce((s, q) => s + Number(q.total_fines_rupees ?? 0), 0);
  const totalExposed = quarters.reduce((s, q) => s + Number(q.patients_exposed ?? 0), 0);
  const overallPass = totalCycles > 0 ? (100 * (totalCycles - totalFailures)) / totalCycles : 0;

  const chainCols: Column<ChainSummary>[] = [
    { key: 'hospital_chain_name', header: 'Chain', render: (r) => r.hospital_chain_name },
    { key: 'total_cycles', header: 'Cycles', render: (r) => String(r.total_cycles) },
    { key: 'failed_cycles', header: 'Failed', render: (r) => String(r.failed_cycles) },
    { key: 'pass_rate_pct', header: 'Pass %', render: (r) => fmtPct(r.pass_rate_pct) },
    { key: 'total_incidents', header: 'Incidents', render: (r) => String(r.total_incidents) },
    { key: 'unresolved_incidents', header: 'Open', render: (r) => String(r.unresolved_incidents) },
  ];

  const stageCols: Column<StageRow>[] = [
    { key: 'reprocessing_stage', header: 'Stage', render: (r) => r.reprocessing_stage },
    { key: 'total_cycles', header: 'Cycles', render: (r) => String(r.total_cycles) },
    { key: 'failures', header: 'Failures', render: (r) => String(r.failures) },
    { key: 'failure_rate_pct', header: 'Fail %', render: (r) => fmtPct(r.failure_rate_pct) },
    { key: 'avg_duration_minutes', header: 'Avg min', render: (r) => (r.avg_duration_minutes ?? '-') + '' },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
    { key: 'cycles_count', header: 'Cycles', render: (r) => String(r.cycles_count) },
    { key: 'failed_count', header: 'Failed', render: (r) => String(r.failed_count) },
    { key: 'incidents_count', header: 'Incidents', render: (r) => String(r.incidents_count) },
    { key: 'patients_exposed', header: 'Exposed', render: (r) => String(r.patients_exposed) },
    { key: 'total_fines_rupees', header: 'Fines', render: (r) => fmtRupees(r.total_fines_rupees) },
  ];

  const scopeCols: Column<ScopeRow>[] = [
    { key: 'scope_serial', header: 'Serial', render: (r) => r.scope_serial },
    { key: 'scope_model', header: 'Model', render: (r) => r.scope_model },
    { key: 'hospital_chain_name', header: 'Chain', render: (r) => r.hospital_chain_name },
    { key: 'hospital_branch_city', header: 'City', render: (r) => r.hospital_branch_city },
    { key: 'total_cycles', header: 'Cycles', render: (r) => String(r.total_cycles) },
    { key: 'failed_cycles', header: 'Failed', render: (r) => String(r.failed_cycles) },
    { key: 'fail_pct', header: 'Fail %', render: (r) => fmtPct(r.fail_pct) },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity.toUpperCase() },
    { key: 'incident_count', header: 'Incidents', render: (r) => String(r.incident_count) },
    { key: 'patients_exposed', header: 'Patients', render: (r) => String(r.patients_exposed) },
    { key: 'total_fines_rupees', header: 'Fines', render: (r) => fmtRupees(r.total_fines_rupees) },
    { key: 'avg_resolution_days', header: 'Avg days', render: (r) => (r.avg_resolution_days ?? '-') + '' },
    { key: 'regulatory_reports', header: 'Reported', render: (r) => String(r.regulatory_reports) },
  ];

  const chemCols: Column<ChemRow>[] = [
    { key: 'chemical_used', header: 'Chemical', render: (r) => r.chemical_used },
    { key: 'cycles_run', header: 'Cycles', render: (r) => String(r.cycles_run) },
    { key: 'avg_concentration_ppm', header: 'Avg ppm', render: (r) => (r.avg_concentration_ppm ?? '-') + '' },
    { key: 'avg_temperature_c', header: 'Avg °C', render: (r) => (r.avg_temperature_c ?? '-') + '' },
    { key: 'pass_rate_pct', header: 'Pass %', render: (r) => fmtPct(r.pass_rate_pct) },
    { key: 'avg_cost_rupees', header: 'Avg cost', render: (r) => fmtRupees(r.avg_cost_rupees) },
  ];

  const incidentCols: Column<IncidentRow>[] = [
    { key: 'incident_opened_at', header: 'Opened', render: (r) => fmtDateTime(r.incident_opened_at) },
    { key: 'severity', header: 'Sev', render: (r) => r.severity.toUpperCase() },
    { key: 'hospital_chain_name', header: 'Chain', render: (r) => r.hospital_chain_name },
    { key: 'hospital_branch_city', header: 'City', render: (r) => r.hospital_branch_city },
    { key: 'incident_category', header: 'Category', render: (r) => r.incident_category },
    { key: 'scope_serial', header: 'Serial', render: (r) => r.scope_serial },
    { key: 'patients_exposed_count', header: 'Exposed', render: (r) => String(r.patients_exposed_count) },
    { key: 'root_cause', header: 'Root cause', render: (r) => r.root_cause },
    { key: 'fine_imposed_rupees', header: 'Fine', render: (r) => fmtRupees(r.fine_imposed_rupees) },
  ];

  const branchCols: Column<BranchRow>[] = [
    { key: 'hospital_chain_name', header: 'Chain', render: (r) => r.hospital_chain_name },
    { key: 'hospital_branch_city', header: 'City', render: (r) => r.hospital_branch_city },
    { key: 'cycles', header: 'Cycles', render: (r) => String(r.cycles) },
    { key: 'failures', header: 'Failed', render: (r) => String(r.failures) },
    { key: 'incidents', header: 'Incidents', render: (r) => String(r.incidents) },
    { key: 'patients_exposed', header: 'Exposed', render: (r) => String(r.patients_exposed) },
    { key: 'total_fines_rupees', header: 'Fines', render: (r) => fmtRupees(r.total_fines_rupees) },
  ];

  const kpis = [
    { label: 'Total Cycles', value: totalCycles.toLocaleString('en-IN') },
    { label: 'Failed Cycles', value: totalFailures.toLocaleString('en-IN') },
    { label: 'Overall Pass Rate', value: overallPass.toFixed(1) + '%' },
    { label: 'Total Incidents', value: totalIncidents.toLocaleString('en-IN') },
    { label: 'Unresolved', value: unresolved.toLocaleString('en-IN') },
    { label: 'Patients Exposed', value: totalExposed.toLocaleString('en-IN') },
    { label: 'Total Fines', value: fmtRupees(totalFines) },
    { label: 'Chains Tracked', value: String(chains.length) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
          Hospital Chain Quarterly Endoscope Reprocessing Compliance Tracker
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Founder-only quarterly audit of endoscope reprocessing cycles across hospital chains —
          stage-level pass rates, chemical efficacy, scope-level risk, branch heatmap, and severity-ranked
          incident log with patient exposure and regulatory fines.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Chain compliance summary</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chain data."
          rowKey={(r, i) => String((r as ChainSummary).hospital_chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stage-level failure breakdown</h2>
        <DataTable
          rows={stages}
          columns={stageCols}
          emptyMessage="No stage data."
          rowKey={(r, i) => String((r as StageRow).reprocessing_stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly trend</h2>
        <DataTable
          rows={quarters}
          columns={quarterCols}
          emptyMessage="No quarterly data."
          rowKey={(r, i) => String((r as QuarterRow).quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top-risk scopes</h2>
        <DataTable
          rows={scopes}
          columns={scopeCols}
          emptyMessage="No scope risk data."
          rowKey={(r, i) => String((r as ScopeRow).scope_serial ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Incident severity matrix</h2>
        <DataTable
          rows={severity}
          columns={sevCols}
          emptyMessage="No severity data."
          rowKey={(r, i) => String((r as SeverityRow).severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Chemical efficacy audit</h2>
        <DataTable
          rows={chemicals}
          columns={chemCols}
          emptyMessage="No chemical data."
          rowKey={(r, i) => String((r as ChemRow).chemical_used ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Branch heatmap</h2>
        <DataTable
          rows={branches}
          columns={branchCols}
          emptyMessage="No branch data."
          rowKey={(r, i) => String((r as BranchRow).hospital_chain_name + '-' + (r as BranchRow).hospital_branch_city) || String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open incidents log (severity-ranked)</h2>
        <DataTable
          rows={incidents}
          columns={incidentCols}
          emptyMessage="No incidents."
          rowKey={(r, i) => String((r as IncidentRow).id ?? i)}
        />
      </section>
    </div>
  );
}
