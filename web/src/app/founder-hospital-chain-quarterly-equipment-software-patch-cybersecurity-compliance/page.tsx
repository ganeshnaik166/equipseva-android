import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_cycles: number; compliant: number; at_risk: number; non_compliant: number; overdue: number; avg_cyber_score: number; total_devices: number; patched: number };
type StatusRow = { compliance_status: string; n: number; devices: number; open_cves: number };
type RiskRow = { chain_name: string; cyber_score: number; critical_cves_open: number; sla_hours_remaining: number; compliance_status: string };
type StateRow = { patch_state: string; n: number; total_cves: number };
type SevRow = { severity: string; n: number; avg_cves: number };
type SlaRow = { chain_name: string; sla_hours_remaining: number; critical_cves_open: number; compliance_status: string };
type FailedRow = { device_model: string; serial_no: string; os_version: string; current_patch_version: string; required_patch_version: string; cve_count: number; severity: string };
type CovRow = { chain_name: string; total_devices: number; patched_devices: number; coverage_pct: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [s, st, risk, dev, sev, sla, failed, cov] = await Promise.all([
    sb.rpc('r2931_summary'),
    sb.rpc('r2931_cycles_by_status'),
    sb.rpc('r2931_top_risk_chains'),
    sb.rpc('r2931_device_state_mix'),
    sb.rpc('r2931_severity_breakdown'),
    sb.rpc('r2931_sla_burn_list'),
    sb.rpc('r2931_failed_devices'),
    sb.rpc('r2931_patch_coverage'),
  ]);

  const summary = (s.data?.[0] ?? null) as Summary | null;
  const statusRows = (st.data ?? []) as StatusRow[];
  const riskRows = (risk.data ?? []) as RiskRow[];
  const stateRows = (dev.data ?? []) as StateRow[];
  const sevRows = (sev.data ?? []) as SevRow[];
  const slaRows = (sla.data ?? []) as SlaRow[];
  const failedRows = (failed.data ?? []) as FailedRow[];
  const covRows = (cov.data ?? []) as CovRow[];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Status', render: (r) => r.compliance_status },
    { key: 'n', header: 'Chains', render: (r) => r.n },
    { key: 'devices', header: 'Devices', render: (r) => r.devices },
    { key: 'open_cves', header: 'Open CVEs', render: (r) => r.open_cves },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'cyber_score', header: 'Cyber score', render: (r) => r.cyber_score },
    { key: 'critical_cves_open', header: 'Crit CVEs', render: (r) => r.critical_cves_open },
    { key: 'sla_hours_remaining', header: 'SLA hrs', render: (r) => r.sla_hours_remaining },
    { key: 'compliance_status', header: 'Status', render: (r) => r.compliance_status },
  ];
  const stateCols: Column<StateRow>[] = [
    { key: 'patch_state', header: 'Patch state', render: (r) => r.patch_state },
    { key: 'n', header: 'Devices', render: (r) => r.n },
    { key: 'total_cves', header: 'CVEs', render: (r) => r.total_cves },
  ];
  const sevCols: Column<SevRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'n', header: 'Devices', render: (r) => r.n },
    { key: 'avg_cves', header: 'Avg CVEs', render: (r) => r.avg_cves },
  ];
  const slaCols: Column<SlaRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'sla_hours_remaining', header: 'SLA hrs left', render: (r) => r.sla_hours_remaining },
    { key: 'critical_cves_open', header: 'Crit CVEs', render: (r) => r.critical_cves_open },
    { key: 'compliance_status', header: 'Status', render: (r) => r.compliance_status },
  ];
  const failedCols: Column<FailedRow>[] = [
    { key: 'device_model', header: 'Device', render: (r) => r.device_model },
    { key: 'serial_no', header: 'Serial', render: (r) => r.serial_no },
    { key: 'os_version', header: 'OS', render: (r) => r.os_version },
    { key: 'current_patch_version', header: 'Current', render: (r) => r.current_patch_version },
    { key: 'required_patch_version', header: 'Required', render: (r) => r.required_patch_version },
    { key: 'cve_count', header: 'CVEs', render: (r) => r.cve_count },
    { key: 'severity', header: 'Sev', render: (r) => r.severity },
  ];
  const covCols: Column<CovRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'total_devices', header: 'Total', render: (r) => r.total_devices },
    { key: 'patched_devices', header: 'Patched', render: (r) => r.patched_devices },
    { key: 'coverage_pct', header: 'Coverage %', render: (r) => r.coverage_pct },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1>Hospital Chain Quarterly Equipment Software-Patch & Cybersecurity Compliance</h1>
      <p>Round r2931 — HEAVY. Patch cycles, CVE exposure & SLA burn across chains.</p>

      {summary && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, margin: '16px 0' }}>
          <div><b>Cycles</b><div>{summary.total_cycles}</div></div>
          <div><b>Compliant</b><div>{summary.compliant}</div></div>
          <div><b>At risk</b><div>{summary.at_risk}</div></div>
          <div><b>Non-compliant</b><div>{summary.non_compliant}</div></div>
          <div><b>Overdue</b><div>{summary.overdue}</div></div>
          <div><b>Avg cyber score</b><div>{summary.avg_cyber_score}</div></div>
          <div><b>Devices</b><div>{summary.total_devices}</div></div>
          <div><b>Patched</b><div>{summary.patched}</div></div>
        </section>
      )}

      <h2>Status mix</h2>
      <DataTable rows={statusRows} columns={statusCols} emptyMessage="No status rows" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />

      <h2>Top-risk chains (lowest cyber score)</h2>
      <DataTable rows={riskRows} columns={riskCols} emptyMessage="No risk rows" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />

      <h2>Device patch state</h2>
      <DataTable rows={stateRows} columns={stateCols} emptyMessage="No device states" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />

      <h2>Severity breakdown</h2>
      <DataTable rows={sevRows} columns={sevCols} emptyMessage="No severity rows" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />

      <h2>SLA burn (&lt;= 168 hrs)</h2>
      <DataTable rows={slaRows} columns={slaCols} emptyMessage="No SLA burn" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />

      <h2>Failed / pending devices</h2>
      <DataTable rows={failedRows} columns={failedCols} emptyMessage="No failed devices" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />

      <h2>Patch coverage by chain</h2>
      <DataTable rows={covRows} columns={covCols} emptyMessage="No coverage rows" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
    </div>
  );
}
