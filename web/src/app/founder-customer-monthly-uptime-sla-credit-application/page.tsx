import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return String(s); }
}

export default async function CustomerMonthlyUptimeSlaCreditApplicationPage() {
  const sb = await getSupabaseServerClient();

  const [creditsR, logR, topR, funnelR, trendR, kindR, summaryR] = await Promise.all([
    sb.rpc('list_credits_r2568'),
    sb.rpc('list_payment_log_r2568'),
    sb.rpc('top_credit_hospitals_r2568'),
    sb.rpc('status_funnel_r2568'),
    sb.rpc('monthly_credit_trend_r2568'),
    sb.rpc('action_kind_summary_r2568'),
    sb.rpc('total_owed_summary_r2568'),
  ]);

  const credits = (creditsR.data ?? []) as any[];
  const logs = (logR.data ?? []) as any[];
  const topHospitals = (topR.data ?? []) as any[];
  const funnel = (funnelR.data ?? []) as any[];
  const trend = (trendR.data ?? []) as any[];
  const kinds = (kindR.data ?? []) as any[];
  const summary = ((summaryR.data ?? []) as any[])[0] ?? null;

  const kpis: Kpi[] = [
    { label: 'Total Credits', value: fmtNum(summary?.total_credits) },
    { label: 'Total Owed', value: inr(summary?.total_owed_rupees) },
    { label: 'Total Applied', value: inr(summary?.total_applied_rupees) },
    { label: 'Total Paid', value: inr(summary?.total_paid_rupees) },
    { label: 'Outstanding', value: inr(summary?.outstanding_rupees) },
    { label: 'Pending', value: fmtNum(summary?.pending_count) },
    { label: 'Paid', value: fmtNum(summary?.paid_count) },
    { label: 'Disputed', value: fmtNum(summary?.disputed_count) },
    { label: 'Avg Uptime', value: fmtPct(summary?.avg_uptime_pct) },
    { label: 'Breach Minutes', value: fmtNum(summary?.total_breach_minutes) },
    { label: 'Hospitals', value: fmtNum(topHospitals.length) },
    { label: 'Log Actions', value: fmtNum(logs.length) },
  ];

  const creditCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '-') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'actual_uptime_pct', header: 'Actual', render: (r: any) => fmtPct(r.actual_uptime_pct) },
    { key: 'sla_target_pct', header: 'SLA Target', render: (r: any) => fmtPct(r.sla_target_pct) },
    { key: 'breach_minutes', header: 'Breach min', render: (r: any) => fmtNum(r.breach_minutes) },
    { key: 'credit_owed_rupees', header: 'Owed', render: (r: any) => inr(r.credit_owed_rupees) },
    { key: 'credit_applied_rupees', header: 'Applied', render: (r: any) => inr(r.credit_applied_rupees) },
    { key: 'credit_paid_rupees', header: 'Paid', render: (r: any) => inr(r.credit_paid_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '-') },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmtDate(r.created_at) },
  ];

  const logCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => fmtDate(r.action_at) },
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '-') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'action_kind', header: 'Action', render: (r: any) => String(r.action_kind ?? '-') },
    { key: 'action_summary', header: 'Summary', render: (r: any) => String(r.action_summary ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '-') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '-') },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'credit_count', header: 'Credits', render: (r: any) => fmtNum(r.credit_count) },
    { key: 'total_owed_rupees', header: 'Owed', render: (r: any) => inr(r.total_owed_rupees) },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => inr(r.total_paid_rupees) },
    { key: 'avg_uptime_pct', header: 'Avg Uptime', render: (r: any) => fmtPct(r.avg_uptime_pct) },
    { key: 'total_breach_minutes', header: 'Breach min', render: (r: any) => fmtNum(r.total_breach_minutes) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'cnt', header: 'Count', render: (r: any) => fmtNum(r.cnt) },
    { key: 'total_owed_rupees', header: 'Owed', render: (r: any) => inr(r.total_owed_rupees) },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => inr(r.total_paid_rupees) },
    { key: 'avg_breach_minutes', header: 'Avg Breach min', render: (r: any) => fmtNum(r.avg_breach_minutes) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '-') },
    { key: 'credit_count', header: 'Credits', render: (r: any) => fmtNum(r.credit_count) },
    { key: 'total_owed_rupees', header: 'Owed', render: (r: any) => inr(r.total_owed_rupees) },
    { key: 'total_applied_rupees', header: 'Applied', render: (r: any) => inr(r.total_applied_rupees) },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => inr(r.total_paid_rupees) },
    { key: 'avg_uptime_pct', header: 'Avg Uptime', render: (r: any) => fmtPct(r.avg_uptime_pct) },
    { key: 'total_breach_minutes', header: 'Breach min', render: (r: any) => fmtNum(r.total_breach_minutes) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => String(r.action_kind ?? '-') },
    { key: 'cnt', header: 'Count', render: (r: any) => fmtNum(r.cnt) },
    { key: 'done_count', header: 'Done', render: (r: any) => fmtNum(r.done_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => fmtNum(r.dropped_count) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Customer Monthly Uptime SLA Credit Application</h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Hospital × month × actual uptime vs SLA target & credit owed/applied/paid. Pending &gt; applied &gt; paid funnel keeps refunds on track.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 28 }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Uptime Credits</h2>
        <DataTable
          rows={credits}
          columns={creditCols}
          emptyMessage="No uptime credits logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Payment Log</h2>
        <DataTable
          rows={logs}
          columns={logCols}
          emptyMessage="No payment actions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Credit Hospitals</h2>
        <DataTable
          rows={topHospitals}
          columns={topCols}
          emptyMessage="No hospitals with credits yet."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No monthly data yet."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Action Kind Summary</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          emptyMessage="No action kinds logged yet."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>
    </div>
  );
}
