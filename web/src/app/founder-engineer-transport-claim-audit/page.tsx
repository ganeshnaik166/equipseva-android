import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    summaryRes,
    pendingRes,
    fraudRes,
    engineerRes,
    modesRes,
    decisionsRes,
  ] = await Promise.all([
    sb.rpc('r2242_transport_claim_summary'),
    sb.rpc('r2242_transport_claim_pending', { p_limit: 100 }),
    sb.rpc('r2242_transport_claim_fraud', { p_limit: 50 }),
    sb.rpc('r2242_transport_claim_by_engineer', { p_limit: 30 }),
    sb.rpc('r2242_transport_claim_modes'),
    sb.rpc('r2242_transport_claim_recent_decisions', { p_limit: 50 }),
  ]);

  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] ?? {} : summaryRes.data ?? {};
  const pending: any[] = pendingRes.data ?? [];
  const fraud: any[] = fraudRes.data ?? [];
  const byEngineer: any[] = engineerRes.data ?? [];
  const modes: any[] = modesRes.data ?? [];
  const decisions: any[] = decisionsRes.data ?? [];

  const pendingCols: Column<any>[] = [
    { key: 'claim_date', header: 'Date', render: (r: any) => String(r.claim_date ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'mode', header: 'Mode', render: (r: any) => String(r.mode ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.amount_rupees ?? 0).toFixed(2)}` },
    { key: 'distance_km', header: 'KM', render: (r: any) => String(r.distance_km ?? '') },
    { key: 'fraud_score', header: 'Fraud', render: (r: any) => String(r.fraud_score ?? 0) },
    { key: 'fraud_flag_count', header: 'Flags', render: (r: any) => String(r.fraud_flag_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const fraudCols: Column<any>[] = [
    { key: 'claim_date', header: 'Date', render: (r: any) => String(r.claim_date ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'mode', header: 'Mode', render: (r: any) => String(r.mode ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.amount_rupees ?? 0).toFixed(2)}` },
    { key: 'distance_km', header: 'KM', render: (r: any) => String(r.distance_km ?? '') },
    { key: 'rupees_per_km', header: 'Rs/KM', render: (r: any) => r.rupees_per_km != null ? String(r.rupees_per_km) : '' },
    { key: 'fraud_score', header: 'Score', render: (r: any) => String(r.fraud_score ?? 0) },
    { key: 'fraud_flags', header: 'Flags', render: (r: any) => Array.isArray(r.fraud_flags) ? r.fraud_flags.join(', ') : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'total_claims', header: 'Claims', render: (r: any) => String(r.total_claims ?? 0) },
    { key: 'submitted_amount', header: 'Submitted', render: (r: any) => `Rs ${Number(r.submitted_amount ?? 0).toFixed(2)}` },
    { key: 'approved_amount', header: 'Approved', render: (r: any) => `Rs ${Number(r.approved_amount ?? 0).toFixed(2)}` },
    { key: 'rejected_count', header: 'Rejected', render: (r: any) => String(r.rejected_count ?? 0) },
    { key: 'avg_fraud_score', header: 'Avg Fraud', render: (r: any) => String(r.avg_fraud_score ?? 0) },
    { key: 'last_claim_at', header: 'Last Claim', render: (r: any) => r.last_claim_at ? new Date(r.last_claim_at).toLocaleString() : '' },
  ];

  const modeCols: Column<any>[] = [
    { key: 'mode', header: 'Mode', render: (r: any) => String(r.mode ?? '') },
    { key: 'claim_count', header: 'Claims', render: (r: any) => String(r.claim_count ?? 0) },
    { key: 'total_amount', header: 'Total', render: (r: any) => `Rs ${Number(r.total_amount ?? 0).toFixed(2)}` },
    { key: 'avg_amount', header: 'Avg', render: (r: any) => `Rs ${Number(r.avg_amount ?? 0).toFixed(2)}` },
    { key: 'approval_rate_pct', header: 'Approval %', render: (r: any) => `${r.approval_rate_pct ?? 0}%` },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'reviewed_at', header: 'When', render: (r: any) => r.reviewed_at ? new Date(r.reviewed_at).toLocaleString() : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => String(r.reviewer_email ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.amount_rupees ?? 0).toFixed(2)}` },
    { key: 'approved_amount_rupees', header: 'Approved', render: (r: any) => r.approved_amount_rupees != null ? `Rs ${Number(r.approved_amount_rupees).toFixed(2)}` : '' },
    { key: 'reviewer_note', header: 'Note', render: (r: any) => String(r.reviewer_note ?? '') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Transport-Claim Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Travel-expense queue with fraud heuristics (high Rs/KM, weekend submissions, duplicate-day pattern).
        Approve, query, or reject. Fraud score &gt;= 60 highlighted.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Card label="Submitted" value={String(summary.submitted_count ?? 0)} hint="awaiting review" />
        <Card label="Queried" value={String(summary.queried_count ?? 0)} hint="info requested" />
        <Card label="Approved" value={String(summary.approved_count ?? 0)} hint="cleared" />
        <Card label="Rejected" value={String(summary.rejected_count ?? 0)} hint="denied" />
        <Card label="Paid" value={String(summary.paid_count ?? 0)} hint="reimbursed" />
        <Card label="Pending Amount" value={`Rs ${Number(summary.submitted_amount_rupees ?? 0).toFixed(0)}`} hint="submitted total" />
        <Card label="Approved Amount" value={`Rs ${Number(summary.approved_amount_rupees ?? 0).toFixed(0)}`} hint="approved + paid" />
        <Card label="High Fraud" value={String(summary.high_fraud_count ?? 0)} hint="score &gt;= 60" />
        <Card label="Avg Claim" value={`Rs ${Number(summary.avg_amount_rupees ?? 0).toFixed(0)}`} hint="all-time mean" />
      </div>

      <Section title="Pending Queue" subtitle="Submitted & queried, ranked by fraud score">
        <DataTable columns={pendingCols} rows={pending} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Fraud-Flagged Claims" subtitle="Score &gt;= 40 (high Rs/KM, weekend, duplicate)">
        <DataTable columns={fraudCols} rows={fraud} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="By Engineer" subtitle="Aggregate per engineer, sorted by submitted amount">
        <DataTable columns={engCols} rows={byEngineer} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Mode Breakdown" subtitle="Spend by transport mode & approval rate">
        <DataTable columns={modeCols} rows={modes} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Recent Decisions" subtitle="Last 50 reviewed claims">
        <DataTable columns={decisionCols} rows={decisions} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function Card({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
      <div style={{ fontSize: 11, color: '#9ca3af', marginTop: 2 }} dangerouslySetInnerHTML={{ __html: hint }} />
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 2 }}>{title}</h2>
      <p style={{ fontSize: 12, color: '#6b7280', marginBottom: 8 }} dangerouslySetInnerHTML={{ __html: subtitle }} />
      {children}
    </div>
  );
}
