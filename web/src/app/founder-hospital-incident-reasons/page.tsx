import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (Number.isNaN(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiRow: any = {};
  let reasons: any[] = [];
  let frequency: any[] = [];
  let clusters: any[] = [];
  let hospitals: any[] = [];
  let recent: any[] = [];
  let trend: any[] = [];

  try {
    const r = await sb.rpc('founder_hospital_incident_kpi_v2');
    kpiRow = (r.data && r.data[0]) || {};
  } catch (_e) { kpiRow = {}; }

  try {
    const r = await sb.rpc('founder_hospital_incident_reason_list_v2');
    reasons = r.data || [];
  } catch (_e) { reasons = []; }

  try {
    const r = await sb.rpc('founder_hospital_incident_frequency_v2');
    frequency = r.data || [];
  } catch (_e) { frequency = []; }

  try {
    const r = await sb.rpc('founder_hospital_incident_clusters_v2');
    clusters = r.data || [];
  } catch (_e) { clusters = []; }

  try {
    const r = await sb.rpc('founder_hospital_incident_by_hospital_v2');
    hospitals = r.data || [];
  } catch (_e) { hospitals = []; }

  try {
    const r = await sb.rpc('founder_hospital_incident_recent_v2');
    recent = r.data || [];
  } catch (_e) { recent = []; }

  try {
    const r = await sb.rpc('founder_hospital_incident_trend_v2');
    trend = r.data || [];
  } catch (_e) { trend = []; }

  const kpis: Kpi[] = [
    { label: 'Total incidents', value: fmtNum(kpiRow.total_incidents) },
    { label: 'Open', value: fmtNum(kpiRow.open_incidents) },
    { label: 'Closed', value: fmtNum(kpiRow.closed_incidents) },
    { label: 'P0', value: fmtNum(kpiRow.p0_count) },
    { label: 'P1', value: fmtNum(kpiRow.p1_count) },
    { label: 'P2', value: fmtNum(kpiRow.p2_count) },
    { label: 'P3', value: fmtNum(kpiRow.p3_count) },
    { label: 'Hospitals affected', value: fmtNum(kpiRow.unique_hospitals) },
    { label: 'Reasons used', value: fmtNum(kpiRow.unique_reasons) },
    { label: 'Active taxonomy', value: fmtNum(kpiRow.active_reasons) },
    { label: 'Inactive taxonomy', value: fmtNum(kpiRow.inactive_reasons) },
    { label: 'Last 7d', value: fmtNum(kpiRow.last_7d) },
    { label: 'Last 30d', value: fmtNum(kpiRow.last_30d) },
    { label: 'Last 90d', value: fmtNum(kpiRow.last_90d) },
    { label: 'Avg close (hrs)', value: fmtNum(kpiRow.avg_resolution_hours) },
    { label: 'Top cluster', value: kpiRow.top_cluster ?? '—' },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'reason_code', header: 'Code', render: (r: any) => r.reason_code ?? '—' },
    { key: 'reason_label', header: 'Label', render: (r: any) => r.reason_label ?? '—' },
    { key: 'cluster', header: 'Cluster', render: (r: any) => r.cluster ?? '—' },
    { key: 'severity_default', header: 'Default sev', render: (r: any) => r.severity_default ?? '—' },
    { key: 'is_active', header: 'Active', render: (r: any) => (r.is_active ? 'yes' : 'no') },
    { key: 'use_count', header: 'Used', render: (r: any) => fmtNum(r.use_count) },
    { key: 'last_used_at', header: 'Last used', render: (r: any) => fmtDate(r.last_used_at) },
  ];

  const freqCols: Column<any>[] = [
    { key: 'reason_code', header: 'Reason', render: (r: any) => r.reason_code ?? '—' },
    { key: 'cluster', header: 'Cluster', render: (r: any) => r.cluster ?? '—' },
    { key: 'freq_7d', header: '7d', render: (r: any) => fmtNum(r.freq_7d) },
    { key: 'freq_30d', header: '30d', render: (r: any) => fmtNum(r.freq_30d) },
    { key: 'freq_90d', header: '90d', render: (r: any) => fmtNum(r.freq_90d) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'avg_hours_to_close', header: 'Avg hrs to close', render: (r: any) => fmtNum(r.avg_hours_to_close) },
  ];

  const clusterCols: Column<any>[] = [
    { key: 'cluster', header: 'Cluster', render: (r: any) => r.cluster ?? '—' },
    { key: 'reason_count', header: 'Reasons', render: (r: any) => fmtNum(r.reason_count) },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => fmtNum(r.incident_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'p0p1_count', header: 'P0/P1', render: (r: any) => fmtNum(r.p0p1_count) },
    { key: 'unique_hospitals', header: 'Hospitals', render: (r: any) => fmtNum(r.unique_hospitals) },
    { key: 'avg_hours_to_close', header: 'Avg hrs to close', render: (r: any) => fmtNum(r.avg_hours_to_close) },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => fmtNum(r.incident_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'p0p1_count', header: 'P0/P1', render: (r: any) => fmtNum(r.p0p1_count) },
    { key: 'distinct_reasons', header: 'Reasons', render: (r: any) => fmtNum(r.distinct_reasons) },
    { key: 'last_incident_at', header: 'Last', render: (r: any) => fmtDate(r.last_incident_at) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmtDate(r.opened_at) },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'reason_code', header: 'Reason', render: (r: any) => r.reason_code ?? '—' },
    { key: 'cluster', header: 'Cluster', render: (r: any) => r.cluster ?? '—' },
    { key: 'incident_kind', header: 'Kind', render: (r: any) => r.incident_kind ?? '—' },
    { key: 'severity', header: 'Sev', render: (r: any) => r.severity ?? '—' },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => fmtDate(r.resolved_at) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Incident Reasons</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Taxonomy-tagged hospital incidents {"—"} per-reason frequency {">"} root-cause clusters {"<"} weekly trend.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 16, marginBottom: 8 }}>Root-cause clusters</h2>
      <DataTable rows={clusters} columns={clusterCols} rowKey={(r: any) => r.cluster} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Per-reason frequency</h2>
      <DataTable rows={frequency} columns={freqCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Reason taxonomy</h2>
      <DataTable rows={reasons} columns={reasonCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Top hospitals by incident volume</h2>
      <DataTable rows={hospitals} columns={hospitalCols} rowKey={(r: any) => r.hospital_org_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Recent incidents</h2>
      <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />

      <p style={{ marginTop: 24, fontSize: 12, color: '#888' }}>
        Weekly trend rows loaded: {fmtNum(trend.length)}. Cluster distribution refresh window {">"} 12 weeks.
      </p>
    </main>
  );
}
