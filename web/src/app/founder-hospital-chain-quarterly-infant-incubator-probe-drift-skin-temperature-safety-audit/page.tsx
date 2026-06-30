import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type DriftSeverityRow = { drift_severity: string; audits: number; babies_at_risk: number; avg_drift_celsius: number };
type ChainRiskRow = { hospital_chain: string; total_audits: number; critical_or_failure: number; babies_at_risk: number };
type ProbeProfileRow = { probe_type: string; audits: number; max_abs_drift: number; avg_abs_drift: number };
type OverdueRow = { hospital_chain: string; facility_code: string; incubator_serial: string; next_due_date: string | null; drift_severity: string };
type RemStatusRow = { remediation_status: string; items: number; total_cost_rupees: number; p0_count: number };
type VendorRow = { assigned_vendor: string; items: number; completed: number; open_or_escalated: number; total_cost_rupees: number };
type IncidentRow = { hospital_chain: string; facility_code: string; incubator_serial: string; probe_type: string; drift_celsius: number; babies_at_risk: number; action_taken: string | null };
type QuarterRow = { audit_quarter: string; audits: number; critical_or_failure: number; babies_at_risk: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [severity, chains, probes, overdue, remStatus, vendors, incidents, quarters] = await Promise.all([
    supabase.rpc('founder_r3075_drift_severity_rollup'),
    supabase.rpc('founder_r3075_chain_risk_summary'),
    supabase.rpc('founder_r3075_probe_type_profile'),
    supabase.rpc('founder_r3075_overdue_calibrations'),
    supabase.rpc('founder_r3075_remediation_status_board'),
    supabase.rpc('founder_r3075_vendor_performance'),
    supabase.rpc('founder_r3075_top_critical_incidents'),
    supabase.rpc('founder_r3075_quarter_trend'),
  ]);

  const severityRows: DriftSeverityRow[] = (severity.data ?? []) as DriftSeverityRow[];
  const chainRows: ChainRiskRow[] = (chains.data ?? []) as ChainRiskRow[];
  const probeRows: ProbeProfileRow[] = (probes.data ?? []) as ProbeProfileRow[];
  const overdueRows: OverdueRow[] = (overdue.data ?? []) as OverdueRow[];
  const remRows: RemStatusRow[] = (remStatus.data ?? []) as RemStatusRow[];
  const vendorRows: VendorRow[] = (vendors.data ?? []) as VendorRow[];
  const incidentRows: IncidentRow[] = (incidents.data ?? []) as IncidentRow[];
  const quarterRows: QuarterRow[] = (quarters.data ?? []) as QuarterRow[];

  const severityCols: Column<DriftSeverityRow>[] = [
    { header: 'Drift Severity', cell: (r) => r.drift_severity },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Babies at Risk', cell: (r) => r.babies_at_risk },
    { header: 'Avg |Drift| °C', cell: (r) => r.avg_drift_celsius },
  ];

  const chainCols: Column<ChainRiskRow>[] = [
    { header: 'Hospital Chain', cell: (r) => r.hospital_chain },
    { header: 'Total Audits', cell: (r) => r.total_audits },
    { header: 'Critical / Failure', cell: (r) => r.critical_or_failure },
    { header: 'Babies at Risk', cell: (r) => r.babies_at_risk },
  ];

  const probeCols: Column<ProbeProfileRow>[] = [
    { header: 'Probe Type', cell: (r) => r.probe_type },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Max |Drift| °C', cell: (r) => r.max_abs_drift },
    { header: 'Avg |Drift| °C', cell: (r) => r.avg_abs_drift },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { header: 'Chain', cell: (r) => r.hospital_chain },
    { header: 'Facility', cell: (r) => r.facility_code },
    { header: 'Incubator', cell: (r) => r.incubator_serial },
    { header: 'Next Due', cell: (r) => r.next_due_date ?? '-' },
    { header: 'Severity', cell: (r) => r.drift_severity },
  ];

  const remCols: Column<RemStatusRow>[] = [
    { header: 'Status', cell: (r) => r.remediation_status },
    { header: 'Items', cell: (r) => r.items },
    { header: 'Total Cost (Rs)', cell: (r) => r.total_cost_rupees },
    { header: 'P0 Count', cell: (r) => r.p0_count },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { header: 'Vendor', cell: (r) => r.assigned_vendor },
    { header: 'Items', cell: (r) => r.items },
    { header: 'Completed', cell: (r) => r.completed },
    { header: 'Open / Escalated', cell: (r) => r.open_or_escalated },
    { header: 'Total Cost (Rs)', cell: (r) => r.total_cost_rupees },
  ];

  const incidentCols: Column<IncidentRow>[] = [
    { header: 'Chain', cell: (r) => r.hospital_chain },
    { header: 'Facility', cell: (r) => r.facility_code },
    { header: 'Incubator', cell: (r) => r.incubator_serial },
    { header: 'Probe', cell: (r) => r.probe_type },
    { header: 'Drift °C', cell: (r) => r.drift_celsius },
    { header: 'Babies at Risk', cell: (r) => r.babies_at_risk },
    { header: 'Action', cell: (r) => r.action_taken ?? '-' },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', cell: (r) => r.audit_quarter },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Critical / Failure', cell: (r) => r.critical_or_failure },
    { header: 'Babies at Risk', cell: (r) => r.babies_at_risk },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Round 3075 — Hospital Chain Quarterly Infant Incubator Probe-Drift &amp; Skin-Temperature Safety Audit</h1>
        <p className="text-sm text-gray-600">Founder console · NICU probe-drift surveillance across hospital chains. Drift &gt;= 0.5°C = major; &gt;= 1.0°C = critical.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Drift severity rollup</h2>
        <DataTable rows={severityRows} columns={severityCols} emptyMessage="No drift audits." rowKey={(r, i) => String((r as { drift_severity?: string }).drift_severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital chain risk summary</h2>
        <DataTable rows={chainRows} columns={chainCols} emptyMessage="No chain data." rowKey={(r, i) => String((r as { hospital_chain?: string }).hospital_chain ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Probe-type drift profile</h2>
        <DataTable rows={probeRows} columns={probeCols} emptyMessage="No probe data." rowKey={(r, i) => String((r as { probe_type?: string }).probe_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue calibrations (next_due &lt;= today)</h2>
        <DataTable rows={overdueRows} columns={overdueCols} emptyMessage="No overdue calibrations." rowKey={(r, i) => String((r as { incubator_serial?: string }).incubator_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation status board</h2>
        <DataTable rows={remRows} columns={remCols} emptyMessage="No remediation items." rowKey={(r, i) => String((r as { remediation_status?: string }).remediation_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor performance</h2>
        <DataTable rows={vendorRows} columns={vendorCols} emptyMessage="No vendor activity." rowKey={(r, i) => String((r as { assigned_vendor?: string }).assigned_vendor ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top critical incidents (major / critical / failure)</h2>
        <DataTable rows={incidentRows} columns={incidentCols} emptyMessage="No critical incidents." rowKey={(r, i) => String((r as { incubator_serial?: string }).incubator_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter-over-quarter trend</h2>
        <DataTable rows={quarterRows} columns={quarterCols} emptyMessage="No quarterly data." rowKey={(r, i) => String((r as { audit_quarter?: string }).audit_quarter ?? i)} />
      </section>
    </main>
  );
}
