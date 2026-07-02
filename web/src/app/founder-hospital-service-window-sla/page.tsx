import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalServiceWindowSlaPage() {
  const sb = await getSupabaseServerClient();

  const [slasRes, breachesRes, summaryRes, atRiskRes] = await Promise.all([
    sb.rpc('list_slas_r1771'),
    sb.rpc('list_breaches_r1771'),
    sb.rpc('breach_summary_r1771'),
    sb.rpc('sla_at_risk_r1771'),
  ]);

  const slas: any[] = Array.isArray(slasRes.data) ? slasRes.data : [];
  const breaches: any[] = Array.isArray(breachesRes.data) ? breachesRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const atRisk: any[] = Array.isArray(atRiskRes.data) ? atRiskRes.data : [];

  const slaCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'sla_type', header: 'SLA Type', render: (r: any) => r.sla_type ?? '—' },
    { key: 'target_minutes', header: 'Target (min)', render: (r: any) => r.target_minutes ?? '—' },
    { key: 'breach_count', header: 'Breaches', render: (r: any) => r.breach_count ?? 0 },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'last_breach_at', header: 'Last Breach', render: (r: any) => r.last_breach_at ? new Date(r.last_breach_at).toLocaleString() : '—' },
  ];

  const breachCols: Column<any>[] = [
    { key: 'breach_event_at', header: 'When', render: (r: any) => r.breach_event_at ? new Date(r.breach_event_at).toLocaleString() : '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'sla_type', header: 'Type', render: (r: any) => r.sla_type ?? '—' },
    { key: 'actual_minutes', header: 'Actual (min)', render: (r: any) => r.actual_minutes ?? '—' },
    { key: 'target_minutes', header: 'Target (min)', render: (r: any) => r.target_minutes ?? '—' },
    { key: 'breach_reason', header: 'Reason', render: (r: any) => r.breach_reason ?? '—' },
    { key: 'customer_credit_rupees', header: 'Credit Rs', render: (r: any) => r.customer_credit_rupees ?? 0 },
    { key: 'credited_at', header: 'Credited', render: (r: any) => r.credited_at ? new Date(r.credited_at).toLocaleString() : 'pending' },
  ];

  const sumCols: Column<any>[] = [
    { key: 'sla_type', header: 'SLA Type', render: (r: any) => r.sla_type ?? '—' },
    { key: 'total_breaches', header: 'Total Breaches', render: (r: any) => r.total_breaches ?? 0 },
    { key: 'total_credits_rupees', header: 'Total Credits Rs', render: (r: any) => r.total_credits_rupees ?? 0 },
    { key: 'avg_actual_minutes', header: 'Avg Actual (min)', render: (r: any) => r.avg_actual_minutes ?? '—' },
    { key: 'pending_credit_count', header: 'Pending Credits', render: (r: any) => r.pending_credit_count ?? 0 },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'sla_type', header: 'SLA Type', render: (r: any) => r.sla_type ?? '—' },
    { key: 'target_minutes', header: 'Target (min)', render: (r: any) => r.target_minutes ?? '—' },
    { key: 'breach_count', header: 'Breaches', render: (r: any) => r.breach_count ?? 0 },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'last_breach_at', header: 'Last Breach', render: (r: any) => r.last_breach_at ? new Date(r.last_breach_at).toLocaleString() : '—' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Service Window SLA
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Per-hospital response, resolution, uptime & escalation SLA tracking with breach credits.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          At Risk / Breach ({atRisk.length})
        </h2>
        <p style={{ color: '#666', marginBottom: '8px', fontSize: '13px' }}>
          SLAs flagged at_risk (breach_count &gt;= 2) or breach (&gt;= 5). Needs founder intervention.
        </p>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Breach Summary by Type
        </h2>
        <DataTable
          rows={summary}
          columns={sumCols}
          rowKey={(r: any, i: number) => String(r.sla_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          All SLAs ({slas.length})
        </h2>
        <p style={{ color: '#666', marginBottom: '8px', fontSize: '13px' }}>
          Status thresholds: on_track (&lt; 2 breaches), at_risk (2 &lt;= breaches &lt; 5), breach (&gt;= 5).
        </p>
        <DataTable
          rows={slas}
          columns={slaCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Recent Breach Log ({breaches.length})
        </h2>
        <DataTable
          rows={breaches}
          columns={breachCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
