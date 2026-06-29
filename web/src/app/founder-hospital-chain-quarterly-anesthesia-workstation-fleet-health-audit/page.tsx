import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainSummary = { chain_name: string; workstations_audited: number; avg_health_score: number; critical_count: number; high_count: number; pass_rate_pct: number };
type CriticalUnit = { id: string; chain_name: string; hospital_site: string; workstation_model: string; asset_tag: string; overall_health_score: number; downtime_risk: string; next_pm_due: string };
type VaporizerBreak = { status: string; count: number; avg_o2_flush_seconds: number; avg_leak_ml_per_min: number };
type RemediationStatus = { status: string; severity: string; count: number; total_parts_rupees: number; total_labor_rupees: number };
type ModelReliability = { workstation_model: string; units: number; avg_health: number; avg_battery_min: number; fail_rate_pct: number };
type PmDue = { id: string; chain_name: string; hospital_site: string; asset_tag: string; workstation_model: string; next_pm_due: string; days_until: number };
type Backlog = { id: string; chain_name: string; hospital_site: string; finding_category: string; severity: string; sla_hours: number; status: string; assigned_engineer: string };
type Kpis = { total_workstations: number; avg_health_score: number; critical_units: number; fail_calibration: number; pm_due_30d: number; total_remediation_cost_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [chainsRes, criticalRes, vaporizerRes, remediationRes, modelsRes, pmDueRes, backlogRes, kpisRes] = await Promise.all([
    supabase.rpc('founder_r2903_chain_fleet_summary'),
    supabase.rpc('founder_r2903_critical_workstations'),
    supabase.rpc('founder_r2903_vaporizer_calibration_breakdown'),
    supabase.rpc('founder_r2903_remediation_status'),
    supabase.rpc('founder_r2903_model_reliability'),
    supabase.rpc('founder_r2903_pm_due_next_30_days'),
    supabase.rpc('founder_r2903_remediation_backlog'),
    supabase.rpc('founder_r2903_fleet_kpis'),
  ]);

  const chains = (chainsRes.data ?? []) as ChainSummary[];
  const critical = (criticalRes.data ?? []) as CriticalUnit[];
  const vaporizer = (vaporizerRes.data ?? []) as VaporizerBreak[];
  const remediation = (remediationRes.data ?? []) as RemediationStatus[];
  const models = (modelsRes.data ?? []) as ModelReliability[];
  const pmDue = (pmDueRes.data ?? []) as PmDue[];
  const backlog = (backlogRes.data ?? []) as Backlog[];
  const kpis = ((kpisRes.data ?? [])[0] ?? {}) as Kpis;

  const chainCols: Column<ChainSummary>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'workstations_audited', header: 'Audited', render: (r) => r.workstations_audited },
    { key: 'avg_health_score', header: 'Avg Health', render: (r) => r.avg_health_score },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'high_count', header: 'High', render: (r) => r.high_count },
    { key: 'pass_rate_pct', header: 'Pass %', render: (r) => r.pass_rate_pct + '%' },
  ];

  const criticalCols: Column<CriticalUnit>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'workstation_model', header: 'Model', render: (r) => r.workstation_model },
    { key: 'asset_tag', header: 'Asset Tag', render: (r) => r.asset_tag },
    { key: 'overall_health_score', header: 'Health', render: (r) => r.overall_health_score },
    { key: 'downtime_risk', header: 'Risk', render: (r) => r.downtime_risk },
    { key: 'next_pm_due', header: 'Next PM', render: (r) => r.next_pm_due },
  ];

  const vaporizerCols: Column<VaporizerBreak>[] = [
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'count', header: 'Units', render: (r) => r.count },
    { key: 'avg_o2_flush_seconds', header: 'Avg O2 Flush (s)', render: (r) => r.avg_o2_flush_seconds },
    { key: 'avg_leak_ml_per_min', header: 'Avg Leak (mL/min)', render: (r) => r.avg_leak_ml_per_min },
  ];

  const remediationCols: Column<RemediationStatus>[] = [
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'count', header: 'Count', render: (r) => r.count },
    { key: 'total_parts_rupees', header: 'Parts (Rs)', render: (r) => r.total_parts_rupees.toLocaleString('en-IN') },
    { key: 'total_labor_rupees', header: 'Labor (Rs)', render: (r) => r.total_labor_rupees.toLocaleString('en-IN') },
  ];

  const modelsCols: Column<ModelReliability>[] = [
    { key: 'workstation_model', header: 'Model', render: (r) => r.workstation_model },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'avg_health', header: 'Avg Health', render: (r) => r.avg_health },
    { key: 'avg_battery_min', header: 'Avg Battery (min)', render: (r) => r.avg_battery_min },
    { key: 'fail_rate_pct', header: 'Fail %', render: (r) => r.fail_rate_pct + '%' },
  ];

  const pmDueCols: Column<PmDue>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'asset_tag', header: 'Asset Tag', render: (r) => r.asset_tag },
    { key: 'workstation_model', header: 'Model', render: (r) => r.workstation_model },
    { key: 'next_pm_due', header: 'Next PM', render: (r) => r.next_pm_due },
    { key: 'days_until', header: 'Days', render: (r) => r.days_until },
  ];

  const backlogCols: Column<Backlog>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_site', header: 'Site', render: (r) => r.hospital_site },
    { key: 'finding_category', header: 'Finding', render: (r) => r.finding_category },
    { key: 'severity', header: 'Sev', render: (r) => r.severity },
    { key: 'sla_hours', header: 'SLA (h)', render: (r) => r.sla_hours },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'assigned_engineer', header: 'Engineer', render: (r) => r.assigned_engineer },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Quarterly Anesthesia Workstation Fleet Health Audit
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Founder console r2903 — chain-by-chain anesthesia workstation audit covering vaporizer calibration,
        circuit leak tests, O2 flush, AGAS pressure, battery backup &amp; soda-lime hours. Critical units flagged for
        SLA-bound remediation. Pass rate &gt;= 80% is the chain target.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Total Workstations" value={kpis.total_workstations ?? 0} />
        <KpiCard label="Avg Health Score" value={kpis.avg_health_score ?? 0} />
        <KpiCard label="Critical Units" value={kpis.critical_units ?? 0} />
        <KpiCard label="Failed Calibration" value={kpis.fail_calibration ?? 0} />
        <KpiCard label="PM Due (30 days)" value={kpis.pm_due_30d ?? 0} />
        <KpiCard label="Remediation Cost (Rs)" value={(kpis.total_remediation_cost_rupees ?? 0).toLocaleString('en-IN')} />
      </section>

      <Section title="Chain Fleet Summary">
        <DataTable rows={chains} columns={chainCols} emptyMessage="No chains audited" rowKey={(r, i) => String(i)} />
      </Section>

      <Section title="Critical & High-Risk Workstations">
        <DataTable rows={critical} columns={criticalCols} emptyMessage="No critical units" rowKey={(r, i) => String(r.id ?? i)} />
      </Section>

      <Section title="Vaporizer Calibration Breakdown">
        <DataTable rows={vaporizer} columns={vaporizerCols} emptyMessage="No calibration data" rowKey={(r, i) => String(i)} />
      </Section>

      <Section title="Model Reliability">
        <DataTable rows={models} columns={modelsCols} emptyMessage="No model data" rowKey={(r, i) => String(i)} />
      </Section>

      <Section title="PM Due — Next 30 Days">
        <DataTable rows={pmDue} columns={pmDueCols} emptyMessage="No PMs due in window" rowKey={(r, i) => String(r.id ?? i)} />
      </Section>

      <Section title="Remediation Status">
        <DataTable rows={remediation} columns={remediationCols} emptyMessage="No remediation work" rowKey={(r, i) => String(i)} />
      </Section>

      <Section title="Remediation Backlog (open / in-progress)">
        <DataTable rows={backlog} columns={backlogCols} emptyMessage="Backlog clear" rowKey={(r, i) => String(r.id ?? i)} />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 600 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
