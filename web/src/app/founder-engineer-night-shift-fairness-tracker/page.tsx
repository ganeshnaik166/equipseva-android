import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [shiftsRes, metricsRes, overQuotaRes, refusalRes, trendRes, distRes, topRefusedRes] = await Promise.all([
    sb.rpc('list_shifts_r2442'),
    sb.rpc('list_metrics_r2442'),
    sb.rpc('top_over_quota_engineers_r2442'),
    sb.rpc('refusal_breakdown_r2442'),
    sb.rpc('weekly_premium_trend_r2442'),
    sb.rpc('fairness_distribution_r2442'),
    sb.rpc('top_refused_engineers_r2442'),
  ]);

  const shifts = (shiftsRes.data ?? []) as any[];
  const metrics = (metricsRes.data ?? []) as any[];
  const overQuota = (overQuotaRes.data ?? []) as any[];
  const refusals = (refusalRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const dist = (distRes.data ?? []) as any[];
  const topRefused = (topRefusedRes.data ?? []) as any[];

  const totalShifts = shifts.length;
  const consentedShifts = shifts.filter((s) => s.consent_given === true).length;
  const totalPremium = shifts.reduce((acc, s) => acc + Number(s.premium_rupees ?? 0), 0);
  const totalRefusals = shifts.filter((s) => String(s.refusal_kind ?? 'none') !== 'none').length;

  const shiftCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'shift_start_at', header: 'Start', render: (r: any) => r.shift_start_at ? new Date(r.shift_start_at).toLocaleString() : '' },
    { key: 'shift_end_at', header: 'End', render: (r: any) => r.shift_end_at ? new Date(r.shift_end_at).toLocaleString() : '' },
    { key: 'shift_kind', header: 'Kind', render: (r: any) => String(r.shift_kind ?? '') },
    { key: 'consent_given', header: 'Consent', render: (r: any) => r.consent_given ? 'yes' : 'no' },
    { key: 'premium_rupees', header: 'Premium', render: (r: any) => '₹' + String(r.premium_rupees ?? 0) },
    { key: 'refusal_kind', header: 'Refusal', render: (r: any) => String(r.refusal_kind ?? 'none') },
    { key: 'refusal_reason', header: 'Reason', render: (r: any) => String(r.refusal_reason ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const metricCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'period_start', header: 'From', render: (r: any) => String(r.period_start ?? '') },
    { key: 'period_end', header: 'To', render: (r: any) => String(r.period_end ?? '') },
    { key: 'total_night_shifts', header: 'Shifts', render: (r: any) => String(r.total_night_shifts ?? 0) },
    { key: 'fairness_target', header: 'Target', render: (r: any) => String(r.fairness_target ?? 0) },
    { key: 'fairness_delta', header: 'Delta', render: (r: any) => String(r.fairness_delta ?? 0) },
    { key: 'total_premium_rupees', header: 'Premium', render: (r: any) => '₹' + String(r.total_premium_rupees ?? 0) },
    { key: 'refusal_count', header: 'Refusals', render: (r: any) => String(r.refusal_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const overQuotaCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_night_shifts', header: 'Shifts', render: (r: any) => String(r.total_night_shifts ?? 0) },
    { key: 'fairness_target', header: 'Target', render: (r: any) => String(r.fairness_target ?? 0) },
    { key: 'fairness_delta', header: 'Over by', render: (r: any) => '+' + String(r.fairness_delta ?? 0) },
    { key: 'total_premium_rupees', header: 'Premium', render: (r: any) => '₹' + String(r.total_premium_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const refusalCols: Column<any>[] = [
    { key: 'refusal_kind', header: 'Kind', render: (r: any) => String(r.refusal_kind ?? '') },
    { key: 'refusal_count', header: 'Count', render: (r: any) => String(r.refusal_count ?? 0) },
    { key: 'pct_of_total', header: 'Pct', render: (r: any) => String(r.pct_of_total ?? 0) + '%' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week start', render: (r: any) => String(r.week_start ?? '') },
    { key: 'shift_count', header: 'Shifts', render: (r: any) => String(r.shift_count ?? 0) },
    { key: 'total_premium_rupees', header: 'Premium', render: (r: any) => '₹' + String(r.total_premium_rupees ?? 0) },
  ];

  const distCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => String(r.engineer_count ?? 0) },
    { key: 'avg_delta', header: 'Avg delta', render: (r: any) => String(r.avg_delta ?? 0) },
    { key: 'total_premium_rupees', header: 'Premium total', render: (r: any) => '₹' + String(r.total_premium_rupees ?? 0) },
  ];

  const topRefusedCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'refusal_count', header: 'Refusals', render: (r: any) => String(r.refusal_count ?? 0) },
    { key: 'total_night_shifts', header: 'Shifts done', render: (r: any) => String(r.total_night_shifts ?? 0) },
    { key: 'fairness_delta', header: 'Delta', render: (r: any) => String(r.fairness_delta ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>Engineer Night-Shift Fairness Tracker</h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Night & weekend & holiday shift assignments &gt; fairness rotation deltas &gt; premium pay earned &gt; consent & refusal log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Stat label="Total shifts" value={String(totalShifts)} />
        <Stat label="Consented" value={String(consentedShifts)} />
        <Stat label="Refusals" value={String(totalRefusals)} />
        <Stat label="Premium paid" value={'₹' + String(totalPremium)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Fairness distribution</h2>
        <DataTable columns={distCols} rows={dist} emptyMessage="No fairness data yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top over-quota engineers (rotate them out)</h2>
        <DataTable columns={overQuotaCols} rows={overQuota} emptyMessage="Nobody over quota — fair rotation" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top refused engineers (HR check-in)</h2>
        <DataTable columns={topRefusedCols} rows={topRefused} emptyMessage="No repeat refusers" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Refusal breakdown</h2>
        <DataTable columns={refusalCols} rows={refusals} emptyMessage="No refusals logged" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly premium trend</h2>
        <DataTable columns={trendCols} rows={trend} emptyMessage="No weekly data yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Per-engineer fairness metrics</h2>
        <DataTable columns={metricCols} rows={metrics} emptyMessage="No metrics computed yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent shifts & refusals</h2>
        <DataTable columns={shiftCols} rows={shifts} emptyMessage="No shifts logged" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}
