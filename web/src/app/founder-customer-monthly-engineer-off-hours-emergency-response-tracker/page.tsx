import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type HospitalRow = {
  hospital_name: string;
  total_calls: number;
  p0_calls: number;
  avg_response_minutes: number;
  avg_resolution_minutes: number;
  surcharge_rupees: number;
  escalations: number;
};

type EngineerRow = {
  engineer_name: string;
  engineer_tier: string;
  calls_handled: number;
  avg_response_minutes: number;
  p0_calls: number;
  avg_csat: number;
  surcharge_earned_rupees: number;
};

type SlaRow = {
  hospital_name: string;
  retention_risk: string;
  actual_calls: number;
  breached_calls: number;
  penalty_rupees: number;
  contract_value_rupees: number;
  notes: string;
};

type WindowRow = {
  on_call_window: string;
  calls: number;
  avg_response_minutes: number;
  surcharge_rupees: number;
  p0_share_pct: number;
};

type ImpactRow = {
  patient_impact: string;
  calls: number;
  avg_response_minutes: number;
  surcharge_rupees: number;
};

type DeviceRow = {
  device_category: string;
  calls: number;
  avg_response_minutes: number;
  avg_resolution_minutes: number;
  unresolved: number;
};

type KpiRow = {
  total_calls: number;
  avg_response_minutes: number;
  avg_csat: number;
  total_surcharge_rupees: number;
  red_accounts: number;
  arr_at_risk_rupees: number;
  unresolved_calls: number;
};

function inr(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [hospitals, engineers, sla, windows, impact, devices, kpi] = await Promise.all([
    sb.rpc('fn_r2896_hospital_response_rollup'),
    sb.rpc('fn_r2896_engineer_oncall_leaderboard'),
    sb.rpc('fn_r2896_sla_breach_watchlist'),
    sb.rpc('fn_r2896_oncall_window_mix'),
    sb.rpc('fn_r2896_patient_impact_ledger'),
    sb.rpc('fn_r2896_device_category_response'),
    sb.rpc('fn_r2896_monthly_kpi_summary'),
  ]);

  const hospitalRows = (hospitals.data ?? []) as HospitalRow[];
  const engineerRows = (engineers.data ?? []) as EngineerRow[];
  const slaRows = (sla.data ?? []) as SlaRow[];
  const windowRows = (windows.data ?? []) as WindowRow[];
  const impactRows = (impact.data ?? []) as ImpactRow[];
  const deviceRows = (devices.data ?? []) as DeviceRow[];
  const kpiRow = ((kpi.data ?? [])[0] ?? null) as KpiRow | null;

  const hospitalCols: Column<HospitalRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'total_calls', header: 'Calls', render: (r) => r.total_calls },
    { key: 'p0_calls', header: 'P0', render: (r) => r.p0_calls },
    { key: 'avg_response_minutes', header: 'Avg response (min)', render: (r) => r.avg_response_minutes },
    { key: 'avg_resolution_minutes', header: 'Avg resolution (min)', render: (r) => r.avg_resolution_minutes ?? '-' },
    { key: 'escalations', header: 'Escalated out', render: (r) => r.escalations },
    { key: 'surcharge_rupees', header: 'Surcharge', render: (r) => inr(r.surcharge_rupees) },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'calls_handled', header: 'Calls', render: (r) => r.calls_handled },
    { key: 'avg_response_minutes', header: 'Avg response (min)', render: (r) => r.avg_response_minutes },
    { key: 'p0_calls', header: 'P0', render: (r) => r.p0_calls },
    { key: 'avg_csat', header: 'CSAT', render: (r) => r.avg_csat ?? '-' },
    { key: 'surcharge_earned_rupees', header: 'Surcharge earned', render: (r) => inr(r.surcharge_earned_rupees) },
  ];

  const slaCols: Column<SlaRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'retention_risk', header: 'Risk', render: (r) => r.retention_risk.toUpperCase() },
    { key: 'actual_calls', header: 'Calls', render: (r) => r.actual_calls },
    { key: 'breached_calls', header: 'Breached', render: (r) => r.breached_calls },
    { key: 'penalty_rupees', header: 'Penalty', render: (r) => inr(r.penalty_rupees) },
    { key: 'contract_value_rupees', header: 'Contract ARR', render: (r) => inr(r.contract_value_rupees) },
    { key: 'notes', header: 'Notes', render: (r) => r.notes },
  ];

  const windowCols: Column<WindowRow>[] = [
    { key: 'on_call_window', header: 'Window', render: (r) => r.on_call_window },
    { key: 'calls', header: 'Calls', render: (r) => r.calls },
    { key: 'avg_response_minutes', header: 'Avg response (min)', render: (r) => r.avg_response_minutes },
    { key: 'p0_share_pct', header: 'P0 share %', render: (r) => r.p0_share_pct },
    { key: 'surcharge_rupees', header: 'Surcharge', render: (r) => inr(r.surcharge_rupees) },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'patient_impact', header: 'Patient impact', render: (r) => r.patient_impact.replaceAll('_', ' ') },
    { key: 'calls', header: 'Calls', render: (r) => r.calls },
    { key: 'avg_response_minutes', header: 'Avg response (min)', render: (r) => r.avg_response_minutes },
    { key: 'surcharge_rupees', header: 'Surcharge', render: (r) => inr(r.surcharge_rupees) },
  ];

  const deviceCols: Column<DeviceRow>[] = [
    { key: 'device_category', header: 'Device', render: (r) => r.device_category },
    { key: 'calls', header: 'Calls', render: (r) => r.calls },
    { key: 'avg_response_minutes', header: 'Avg response (min)', render: (r) => r.avg_response_minutes },
    { key: 'avg_resolution_minutes', header: 'Avg resolution (min)', render: (r) => r.avg_resolution_minutes ?? '-' },
    { key: 'unresolved', header: 'Unresolved', render: (r) => r.unresolved },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>
        Customer Monthly Engineer Off-Hours Emergency Response Tracker
      </h1>
      <p style={{ color: '#555', marginTop: 6, marginBottom: 24 }}>
        Hospital-by-hospital view of night, weekend &amp; holiday emergency calls. Track engineer response,
        SLA breaches and ARR-at-risk so we save retention before contract renewal. Patient impact &gt;= delayed_procedure
        is the leading churn signal.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Off-hours calls" value={kpiRow?.total_calls ?? 0} />
        <KpiCard label="Avg response (min)" value={kpiRow?.avg_response_minutes ?? 0} />
        <KpiCard label="Avg CSAT" value={kpiRow?.avg_csat ?? 0} />
        <KpiCard label="Surcharge billed" value={inr(kpiRow?.total_surcharge_rupees ?? 0)} />
        <KpiCard label="RED accounts" value={kpiRow?.red_accounts ?? 0} />
        <KpiCard label="ARR at risk" value={inr(kpiRow?.arr_at_risk_rupees ?? 0)} />
        <KpiCard label="Unresolved" value={kpiRow?.unresolved_calls ?? 0} />
      </section>

      <Section title="Hospital response roll-up" subtitle="Per-hospital off-hours load and response performance.">
        <DataTable
          rows={hospitalRows}
          columns={hospitalCols}
          emptyMessage="No hospital calls this month."
          rowKey={(r, i) => String((r as HospitalRow).hospital_name ?? i)}
        />
      </Section>

      <Section title="SLA breach watchlist" subtitle="RED + AMBER accounts ranked by contract ARR — call before renewal.">
        <DataTable
          rows={slaRows}
          columns={slaCols}
          emptyMessage="No SLA tracking rows."
          rowKey={(r, i) => String((r as SlaRow).hospital_name ?? i)}
        />
      </Section>

      <Section title="Engineer on-call leaderboard" subtitle="Who shows up at 2am — surcharge earned drives retention of platinum engineers.">
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer activity."
          rowKey={(r, i) => String((r as EngineerRow).engineer_name ?? i)}
        />
      </Section>

      <Section title="On-call window mix" subtitle="Night vs weekend vs holiday vs dawn distribution.">
        <DataTable
          rows={windowRows}
          columns={windowCols}
          emptyMessage="No window data."
          rowKey={(r, i) => String((r as WindowRow).on_call_window ?? i)}
        />
      </Section>

      <Section title="Patient impact ledger" subtitle="Outcomes downstream of response time — escalated_to_other_hospital is the kill signal.">
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rows."
          rowKey={(r, i) => String((r as ImpactRow).patient_impact ?? i)}
        />
      </Section>

      <Section title="Device category response" subtitle="Which device classes are eating off-hours bandwidth.">
        <DataTable
          rows={deviceRows}
          columns={deviceCols}
          emptyMessage="No device rows."
          rowKey={(r, i) => String((r as DeviceRow).device_category ?? i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 14, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: 2 }}>{title}</h2>
      <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>{subtitle}</p>
      {children}
    </section>
  );
}
