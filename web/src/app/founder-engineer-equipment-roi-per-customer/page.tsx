import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RoiRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string;
  equipment_category: string;
  period_start: string;
  period_end: string;
  total_engineer_hours: number;
  total_billed_rupees: number;
  total_repair_cost_rupees: number;
  net_margin_rupees: number;
  roi_pct: number;
  recorded_at: string;
};

type AnomalyRow = {
  id: string;
  roi_id: string;
  hospital_user_id: string;
  hospital_name: string;
  equipment_category: string;
  anomaly_type: string;
  anomaly_text: string;
  founder_action_taken: string | null;
  created_at: string;
};

type TopComboRow = {
  hospital_user_id: string;
  hospital_name: string;
  equipment_category: string;
  avg_roi_pct: number;
  total_margin_rupees: number;
  record_count: number;
};

type RecentAnomalyRow = {
  anomaly_type: string;
  count_total: number;
  count_unresolved: number;
  most_recent: string;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [roisRes, anomaliesRes, topRes, lowRes, recentRes] = await Promise.all([
    sb.rpc('list_rois_r1888', { p_limit: 200 }),
    sb.rpc('list_anomalies_r1888', { p_limit: 200 }),
    sb.rpc('top_roi_combinations_r1888', { p_limit: 20 }),
    sb.rpc('low_roi_combinations_r1888', { p_limit: 20 }),
    sb.rpc('recent_anomalies_r1888', { p_days: 7 }),
  ]);

  const rois = (roisRes.data ?? []) as RoiRow[];
  const anomalies = (anomaliesRes.data ?? []) as AnomalyRow[];
  const topCombos = (topRes.data ?? []) as TopComboRow[];
  const lowCombos = (lowRes.data ?? []) as TopComboRow[];
  const recent = (recentRes.data ?? []) as RecentAnomalyRow[];

  const roiColumns: Column<RoiRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'period_start', header: 'Period Start', render: (r: any) => r.period_start },
    { key: 'period_end', header: 'Period End', render: (r: any) => r.period_end },
    { key: 'total_engineer_hours', header: 'Eng Hrs', render: (r: any) => String(r.total_engineer_hours) },
    { key: 'total_billed_rupees', header: 'Billed', render: (r: any) => rupees(r.total_billed_rupees) },
    { key: 'total_repair_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.total_repair_cost_rupees) },
    { key: 'net_margin_rupees', header: 'Margin', render: (r: any) => rupees(r.net_margin_rupees) },
    { key: 'roi_pct', header: 'ROI %', render: (r: any) => pct(r.roi_pct) },
  ];

  const anomalyColumns: Column<AnomalyRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'anomaly_type', header: 'Type', render: (r: any) => r.anomaly_type },
    { key: 'anomaly_text', header: 'Detail', render: (r: any) => r.anomaly_text },
    { key: 'founder_action_taken', header: 'Action', render: (r: any) => r.founder_action_taken ?? '—' },
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString('en-IN') },
  ];

  const comboColumns: Column<TopComboRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'avg_roi_pct', header: 'Avg ROI %', render: (r: any) => pct(r.avg_roi_pct) },
    { key: 'total_margin_rupees', header: 'Total Margin', render: (r: any) => rupees(r.total_margin_rupees) },
    { key: 'record_count', header: 'Records', render: (r: any) => String(r.record_count) },
  ];

  const recentColumns: Column<RecentAnomalyRow>[] = [
    { key: 'anomaly_type', header: 'Anomaly Type', render: (r: any) => r.anomaly_type },
    { key: 'count_total', header: 'Total (7d)', render: (r: any) => String(r.count_total) },
    { key: 'count_unresolved', header: 'Unresolved', render: (r: any) => String(r.count_unresolved) },
    { key: 'most_recent', header: 'Most Recent', render: (r: any) => new Date(r.most_recent).toLocaleString('en-IN') },
  ];

  const totalRecords = rois.length;
  const avgRoi =
    rois.length > 0
      ? (rois.reduce((s, r) => s + Number(r.roi_pct || 0), 0) / rois.length).toFixed(2)
      : '0.00';
  const lossCount = rois.filter((r) => Number(r.net_margin_rupees) < 0).length;
  const unresolvedAnoms = anomalies.filter((a) => !a.founder_action_taken).length;

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Engineer Equipment ROI Per Customer</h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          r1888 · per-hospital × per-equipment-category service ROI tracking
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Total Records</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{totalRecords}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Avg ROI %</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{avgRoi}%</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Loss Combinations</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: lossCount > 0 ? '#dc2626' : '#16a34a' }}>
            {lossCount}
          </div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase' }}>Unresolved Anomalies</div>
          <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4, color: unresolvedAnoms > 0 ? '#ea580c' : '#16a34a' }}>
            {unresolvedAnoms}
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent ROI Records</h2>
        <DataTable rows={rois} columns={roiColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top ROI Combinations</h2>
        <DataTable rows={topCombos} columns={comboColumns} rowKey={(r: any, i: number) => String((r.hospital_user_id ?? '') + '|' + (r.equipment_category ?? '') + '|' + i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Low ROI Combinations</h2>
        <DataTable rows={lowCombos} columns={comboColumns} rowKey={(r: any, i: number) => String((r.hospital_user_id ?? '') + '|' + (r.equipment_category ?? '') + '|' + i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Anomalies (Last 7 Days)</h2>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String((r.anomaly_type ?? '') + '|' + i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Anomalies</h2>
        <DataTable rows={anomalies} columns={anomalyColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
