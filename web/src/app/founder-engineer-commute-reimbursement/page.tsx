import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

export default async function FounderEngineerCommuteReimbursementPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: Record<string, any> = {};
  let pending: any[] = [];
  let outliers: any[] = [];
  let engineerSummary: any[] = [];
  let recentDecisions: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_commute_kpis');
    kpis = (r.data as any) ?? {};
  } catch {
    kpis = {};
  }
  try {
    const r = await sb.rpc('rpc_founder_commute_pending_claims');
    pending = (r.data as any[]) ?? [];
  } catch {
    pending = [];
  }
  try {
    const r = await sb.rpc('rpc_founder_commute_outliers');
    outliers = (r.data as any[]) ?? [];
  } catch {
    outliers = [];
  }
  try {
    const r = await sb.rpc('rpc_founder_commute_engineer_summary');
    engineerSummary = (r.data as any[]) ?? [];
  } catch {
    engineerSummary = [];
  }
  try {
    const r = await sb.rpc('rpc_founder_commute_recent_decisions');
    recentDecisions = (r.data as any[]) ?? [];
  } catch {
    recentDecisions = [];
  }

  const fmtMoney = (n: any) => `₹${Number(n ?? 0).toLocaleString('en-IN')}`;
  const fmtNum = (n: any) => Number(n ?? 0).toLocaleString('en-IN');
  const fmtDate = (s: any) => (s ? new Date(s).toLocaleString('en-IN') : '—');

  const kpiCards: Kpi[] = [
    { label: 'Claims MTD', value: fmtNum(kpis.total_claims_mtd) },
    { label: 'Total Amount MTD', value: fmtMoney(kpis.total_amount_mtd_rupees) },
    { label: 'Pending Submitted', value: fmtNum(kpis.pending_submitted) },
    { label: 'Pending Team Lead', value: fmtNum(kpis.pending_team_lead) },
    { label: 'Pending Ops', value: fmtNum(kpis.pending_ops) },
    { label: 'Rejected MTD', value: fmtNum(kpis.rejected_mtd) },
    { label: 'Paid MTD', value: fmtNum(kpis.paid_mtd) },
    { label: 'Paid Amount MTD', value: fmtMoney(kpis.paid_amount_mtd_rupees) },
    { label: 'Flagged Outliers', value: fmtNum(kpis.flagged_outliers) },
    { label: 'Engineers Claimed MTD', value: fmtNum(kpis.engineers_with_claims_mtd) },
    { label: 'Engineers Over Cap', value: fmtNum(kpis.engineers_over_cap) },
    { label: 'Avg Claim Amount', value: fmtMoney(kpis.avg_claim_amount_rupees) },
    { label: 'Avg Distance (km)', value: fmtNum(kpis.avg_distance_km) },
    { label: 'Max Single Claim', value: fmtMoney(kpis.max_single_claim_rupees) },
    { label: '2-Wheeler Share %', value: `${kpis.two_wheeler_share_pct ?? 0}%` },
    { label: 'Founder Reviews Needed', value: fmtNum(kpis.founder_reviews_needed) },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => String(r.engineer_id ?? '—').slice(0, 8) },
    { key: 'vehicle_type', header: 'Vehicle', render: (r: any) => r.vehicle_type ?? '—' },
    { key: 'distance_km', header: 'Distance (km)', render: (r: any) => fmtNum(r.distance_km) },
    { key: 'per_km_rate_rupees', header: 'Rate/km', render: (r: any) => fmtMoney(r.per_km_rate_rupees) },
    { key: 'computed_amount_rupees', header: 'Amount', render: (r: any) => fmtMoney(r.computed_amount_rupees) },
    { key: 'approval_state', header: 'State', render: (r: any) => r.approval_state ?? '—' },
    { key: 'flagged_outlier', header: 'Outlier?', render: (r: any) => (r.flagged_outlier ? 'YES' : 'no') },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => fmtDate(r.submitted_at) },
  ];

  const outlierCols: Column<any>[] = [
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => String(r.engineer_id ?? '—').slice(0, 8) },
    { key: 'distance_km', header: 'Distance (km)', render: (r: any) => fmtNum(r.distance_km) },
    { key: 'computed_amount_rupees', header: 'Amount', render: (r: any) => fmtMoney(r.computed_amount_rupees) },
    { key: 'outlier_reason', header: 'Reason', render: (r: any) => r.outlier_reason ?? '—' },
    { key: 'approval_state', header: 'State', render: (r: any) => r.approval_state ?? '—' },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => fmtDate(r.submitted_at) },
  ];

  const engineerCols: Column<any>[] = [
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => String(r.engineer_id ?? '—').slice(0, 8) },
    { key: 'claims_count', header: 'Claims', render: (r: any) => fmtNum(r.claims_count) },
    { key: 'total_amount_rupees', header: 'Total Amount', render: (r: any) => fmtMoney(r.total_amount_rupees) },
    { key: 'total_distance_km', header: 'Total km', render: (r: any) => fmtNum(r.total_distance_km) },
    { key: 'cap_amount_rupees', header: 'Cap', render: (r: any) => fmtMoney(r.cap_amount_rupees) },
    { key: 'used_amount_rupees', header: 'Used', render: (r: any) => fmtMoney(r.used_amount_rupees) },
    { key: 'over_cap', header: 'Over Cap?', render: (r: any) => (r.over_cap ? 'YES' : 'no') },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => String(r.engineer_id ?? '—').slice(0, 8) },
    { key: 'approval_state', header: 'State', render: (r: any) => r.approval_state ?? '—' },
    { key: 'computed_amount_rupees', header: 'Amount', render: (r: any) => fmtMoney(r.computed_amount_rupees) },
    { key: 'founder_reviewed_at', header: 'Reviewed', render: (r: any) => fmtDate(r.founder_reviewed_at) },
    { key: 'paid_at', header: 'Paid', render: (r: any) => fmtDate(r.paid_at) },
    { key: 'rejection_reason', header: 'Reject Reason', render: (r: any) => r.rejection_reason ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Commute Reimbursement</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Per-job commute claims {">"} approval ladder {">"} per-engineer monthly cap {">"} founder review for outliers.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpiCards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending Claims (awaiting approval)</h2>
        <DataTable columns={pendingCols} rows={pending} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Flagged Outliers (founder review)</h2>
        <DataTable columns={outlierCols} rows={outliers} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Per-Engineer Summary (MTD vs Cap)</h2>
        <DataTable columns={engineerCols} rows={engineerSummary} rowKey={(r: any) => r.engineer_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Decisions</h2>
        <DataTable columns={decisionCols} rows={recentDecisions} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
