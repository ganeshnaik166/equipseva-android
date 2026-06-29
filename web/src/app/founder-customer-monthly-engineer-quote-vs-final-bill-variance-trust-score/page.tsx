import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: string };
type TrustRow = { id: string; engineer_name: string; engineer_tier: string; jobs_completed: number; variance_pct: number; trust_score: number; trust_band: string };
type CustomerRow = { id: string; customer_org_name: string; total_quoted_rupees: number; total_final_billed_rupees: number; variance_rupees: number; variance_pct: number; disputed_jobs: number; refund_issued_rupees: number };
type IncidentRow = { id: string; repair_job_ref: string; customer_org_name: string; engineer_name: string; variance_pct: number; variance_reason: string; severity: string; resolution_status: string };
type RefundRow = { id: string; repair_job_ref: string; engineer_name: string; variance_pct: number; refund_rupees: number; resolved_at: string | null; variance_reason: string };
type MomRow = { id: string; engineer_name: string; may_variance_pct: number; jun_variance_pct: number; delta_pct: number; direction: string };
type ReasonRow = { id: string; variance_reason: string; incident_count: number; total_refund_rupees: number; avg_variance_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpis, trust, customers, incidents, refunds, mom, reasons] = await Promise.all([
    supabase.rpc('rpc_r2916_kpi_summary'),
    supabase.rpc('rpc_r2916_engineer_trust_leaderboard'),
    supabase.rpc('rpc_r2916_customer_variance_view'),
    supabase.rpc('rpc_r2916_open_incidents'),
    supabase.rpc('rpc_r2916_refund_log'),
    supabase.rpc('rpc_r2916_mom_trend'),
    supabase.rpc('rpc_r2916_reason_breakdown'),
  ]);

  const kpiRows = (kpis.data ?? []) as KpiRow[];
  const trustRows = (trust.data ?? []) as TrustRow[];
  const customerRows = (customers.data ?? []) as CustomerRow[];
  const incidentRows = (incidents.data ?? []) as IncidentRow[];
  const refundRows = (refunds.data ?? []) as RefundRow[];
  const momRows = (mom.data ?? []) as MomRow[];
  const reasonRows = (reasons.data ?? []) as ReasonRow[];

  const trustCols: Column<TrustRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
    { key: 'jobs_completed', header: 'Jobs', render: (r) => String(r.jobs_completed) },
    { key: 'variance_pct', header: 'Variance %', render: (r) => `${r.variance_pct}%` },
    { key: 'trust_score', header: 'Trust Score', render: (r) => String(r.trust_score) },
    { key: 'trust_band', header: 'Band', render: (r) => r.trust_band },
  ];

  const customerCols: Column<CustomerRow>[] = [
    { key: 'customer_org_name', header: 'Hospital', render: (r) => r.customer_org_name },
    { key: 'total_quoted_rupees', header: 'Quoted', render: (r) => `Rs ${r.total_quoted_rupees}` },
    { key: 'total_final_billed_rupees', header: 'Billed', render: (r) => `Rs ${r.total_final_billed_rupees}` },
    { key: 'variance_rupees', header: 'Variance', render: (r) => `Rs ${r.variance_rupees}` },
    { key: 'variance_pct', header: 'Variance %', render: (r) => `${r.variance_pct}%` },
    { key: 'disputed_jobs', header: 'Disputes', render: (r) => String(r.disputed_jobs) },
    { key: 'refund_issued_rupees', header: 'Refunds', render: (r) => `Rs ${r.refund_issued_rupees}` },
  ];

  const incidentCols: Column<IncidentRow>[] = [
    { key: 'repair_job_ref', header: 'Job Ref', render: (r) => r.repair_job_ref },
    { key: 'customer_org_name', header: 'Hospital', render: (r) => r.customer_org_name },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'variance_pct', header: 'Variance %', render: (r) => `${r.variance_pct}%` },
    { key: 'variance_reason', header: 'Reason', render: (r) => r.variance_reason },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'resolution_status', header: 'Status', render: (r) => r.resolution_status },
  ];

  const refundCols: Column<RefundRow>[] = [
    { key: 'repair_job_ref', header: 'Job Ref', render: (r) => r.repair_job_ref },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'variance_pct', header: 'Variance %', render: (r) => `${r.variance_pct}%` },
    { key: 'refund_rupees', header: 'Refund', render: (r) => `Rs ${r.refund_rupees}` },
    { key: 'variance_reason', header: 'Reason', render: (r) => r.variance_reason },
    { key: 'resolved_at', header: 'Resolved', render: (r) => r.resolved_at ?? '-' },
  ];

  const momCols: Column<MomRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'may_variance_pct', header: 'May %', render: (r) => `${r.may_variance_pct}%` },
    { key: 'jun_variance_pct', header: 'Jun %', render: (r) => `${r.jun_variance_pct}%` },
    { key: 'delta_pct', header: 'Delta', render: (r) => `${r.delta_pct}` },
    { key: 'direction', header: 'Direction', render: (r) => r.direction },
  ];

  const reasonCols: Column<ReasonRow>[] = [
    { key: 'variance_reason', header: 'Reason', render: (r) => r.variance_reason },
    { key: 'incident_count', header: 'Count', render: (r) => String(r.incident_count) },
    { key: 'total_refund_rupees', header: 'Refunds', render: (r) => `Rs ${r.total_refund_rupees}` },
    { key: 'avg_variance_pct', header: 'Avg Variance %', render: (r) => `${r.avg_variance_pct}%` },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: '1.5rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>
          Customer Monthly Engineer Quote-vs-Final-Bill Variance & Trust Score
        </h1>
        <p style={{ color: '#666', marginTop: '0.5rem' }}>
          Founder console r2916 — monthly per-engineer rollup of quoted vs final billed amounts.
          Variance &gt;= 10% flags trust risk; variance &gt;= 25% triggers refund &amp; founder review.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        {kpiRows.map((k) => (
          <div key={k.metric} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '1rem', background: '#fafafa' }}>
            <div style={{ fontSize: '0.75rem', color: '#666', textTransform: 'uppercase' }}>{k.metric}</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700, marginTop: '0.25rem' }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Engineer Trust Leaderboard</h2>
        <DataTable rows={trustRows} columns={trustCols} emptyMessage="No engineer data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Per-Hospital Variance</h2>
        <DataTable rows={customerRows} columns={customerCols} emptyMessage="No customer rollups" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Open & Investigating Incidents</h2>
        <DataTable rows={incidentRows} columns={incidentCols} emptyMessage="No open incidents" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Refund Log</h2>
        <DataTable rows={refundRows} columns={refundCols} emptyMessage="No refunds issued" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Month-over-Month Trend</h2>
        <DataTable rows={momRows} columns={momCols} emptyMessage="No trend data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Variance Reason Breakdown</h2>
        <DataTable rows={reasonRows} columns={reasonCols} emptyMessage="No reason data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
