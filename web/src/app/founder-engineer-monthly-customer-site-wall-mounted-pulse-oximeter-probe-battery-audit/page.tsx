import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ProbeOverview = { audit_status: string; total: number; avg_spo2: number; drift_count: number; replace_count: number };
type BatteryOverview = { battery_status: string; total: number; avg_capacity: number; avg_runtime: number; replace_count: number };
type HospProbeRisk = { hospital_name: string; probes_audited: number; fail_count: number; warn_count: number; avg_accuracy: number };
type BatteryCritical = { hospital_name: string; device_serial: string; battery_type: string; battery_age_months: number; capacity_pct: number; swelling_detected: boolean; battery_status: string };
type EngThroughput = { engineer_name: string; probes_audited: number; batteries_audited: number; replace_recs: number };
type MonthlyTrend = { audit_month: string; probes: number; batteries: number; probe_fails: number; battery_criticals: number };
type ProbeTypeDist = { probe_type: string; total: number; worn_or_worse: number; avg_pulse_accuracy: number };
type ReplacementPri = { hospital_name: string; device_serial: string; issue: string; severity: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [a, b, c, d, e, f, g, h] = await Promise.all([
    sb.rpc('founder_r3018_probe_overview'),
    sb.rpc('founder_r3018_battery_overview'),
    sb.rpc('founder_r3018_hospital_probe_risk'),
    sb.rpc('founder_r3018_battery_critical_devices'),
    sb.rpc('founder_r3018_engineer_throughput'),
    sb.rpc('founder_r3018_monthly_trend'),
    sb.rpc('founder_r3018_probe_type_distribution'),
    sb.rpc('founder_r3018_replacement_priority_list'),
  ]);

  const probeOv = (a.data ?? []) as ProbeOverview[];
  const battOv = (b.data ?? []) as BatteryOverview[];
  const risk = (c.data ?? []) as HospProbeRisk[];
  const crit = (d.data ?? []) as BatteryCritical[];
  const eng = (e.data ?? []) as EngThroughput[];
  const trend = (f.data ?? []) as MonthlyTrend[];
  const dist = (g.data ?? []) as ProbeTypeDist[];
  const pri = (h.data ?? []) as ReplacementPri[];

  const probeOvCols: Column<ProbeOverview>[] = [
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Avg SpO2 %', accessor: (r) => r.avg_spo2 },
    { header: 'Drift', accessor: (r) => r.drift_count },
    { header: 'Replace Recs', accessor: (r) => r.replace_count },
  ];
  const battOvCols: Column<BatteryOverview>[] = [
    { header: 'Status', accessor: (r) => r.battery_status },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Avg Capacity %', accessor: (r) => r.avg_capacity },
    { header: 'Avg Runtime (h)', accessor: (r) => r.avg_runtime },
    { header: 'Replace Recs', accessor: (r) => r.replace_count },
  ];
  const riskCols: Column<HospProbeRisk>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Probes Audited', accessor: (r) => r.probes_audited },
    { header: 'Fails', accessor: (r) => r.fail_count },
    { header: 'Warns', accessor: (r) => r.warn_count },
    { header: 'Avg Accuracy %', accessor: (r) => r.avg_accuracy },
  ];
  const critCols: Column<BatteryCritical>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Device', accessor: (r) => r.device_serial },
    { header: 'Type', accessor: (r) => r.battery_type },
    { header: 'Age (mo)', accessor: (r) => r.battery_age_months },
    { header: 'Capacity %', accessor: (r) => r.capacity_pct },
    { header: 'Swelling', accessor: (r) => (r.swelling_detected ? 'yes' : 'no') },
    { header: 'Status', accessor: (r) => r.battery_status },
  ];
  const engCols: Column<EngThroughput>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Probes', accessor: (r) => r.probes_audited },
    { header: 'Batteries', accessor: (r) => r.batteries_audited },
    { header: 'Replace Recs', accessor: (r) => r.replace_recs },
  ];
  const trendCols: Column<MonthlyTrend>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Probes', accessor: (r) => r.probes },
    { header: 'Batteries', accessor: (r) => r.batteries },
    { header: 'Probe Fails', accessor: (r) => r.probe_fails },
    { header: 'Battery Criticals', accessor: (r) => r.battery_criticals },
  ];
  const distCols: Column<ProbeTypeDist>[] = [
    { header: 'Probe Type', accessor: (r) => r.probe_type },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Worn or Worse', accessor: (r) => r.worn_or_worse },
    { header: 'Avg Pulse Accuracy %', accessor: (r) => r.avg_pulse_accuracy },
  ];
  const priCols: Column<ReplacementPri>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Device', accessor: (r) => r.device_serial },
    { header: 'Issue', accessor: (r) => r.issue },
    { header: 'Severity', accessor: (r) => r.severity },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 600 }}>r3018 — Engineer Monthly Pulse-Oximeter Probe & Battery Audit</h1>
      <p style={{ color: '#666', marginTop: 4, marginBottom: 20 }}>
        Wall-mounted SpO2 site audits across customer hospitals. Tracks probe wear, cable integrity, SpO2 accuracy
        drift, battery capacity & swelling. Replacement priority list flags devices needing engineer dispatch.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Probe Audit Overview</h2>
        <DataTable rows={probeOv} columns={probeOvCols} emptyMessage="No probe audits" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Battery Audit Overview</h2>
        <DataTable rows={battOv} columns={battOvCols} emptyMessage="No battery audits" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Hospital Probe Risk Ranking</h2>
        <DataTable rows={risk} columns={riskCols} emptyMessage="No risk data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Battery Critical Devices (capacity &lt; threshold)</h2>
        <DataTable rows={crit} columns={critCols} emptyMessage="No critical batteries" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Throughput</h2>
        <DataTable rows={eng} columns={engCols} emptyMessage="No engineer data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Probe Type Distribution</h2>
        <DataTable rows={dist} columns={distCols} emptyMessage="No distribution data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Replacement Priority List</h2>
        <DataTable rows={pri} columns={priCols} emptyMessage="No replacements pending" rowKey={(r, i) => String(i)} />
      </section>
    </main>
  );
}
