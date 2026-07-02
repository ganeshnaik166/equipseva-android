import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ClaimRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  claim_date: string | null;
  expense_type: string | null;
  amount_rupees: number | null;
  receipt_url: string | null;
  repair_job_id: string | null;
  status: string | null;
  decided_at: string | null;
  created_at: string | null;
};

type ReviewRow = {
  id: string;
  claim_id: string;
  reviewer_email: string | null;
  decision: string | null;
  decision_note: string | null;
  decided_at: string | null;
};

type SummaryRow = {
  status: string | null;
  claim_count: number | null;
  total_amount_rupees: number | null;
};

type TopRow = {
  engineer_user_id: string | null;
  engineer_email: string | null;
  claim_count: number | null;
  approved_count: number | null;
  total_rupees: number | null;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined) {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return String(d);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [claimsRes, summaryRes, topRes, reviewsRes] = await Promise.all([
    sb.rpc('list_engineer_expense_claims_r1812'),
    sb.rpc('pending_engineer_expense_summary_r1812'),
    sb.rpc('top_engineer_expense_claimers_r1812'),
    sb.rpc('list_engineer_expense_reviews_r1812', { p_claim_id: null }),
  ]);

  const claims: ClaimRow[] = (claimsRes.data as ClaimRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const reviews: ReviewRow[] = (reviewsRes.data as ReviewRow[] | null) ?? [];

  const claimColumns: Column<ClaimRow>[] = [
    { key: 'claim_date', header: 'Claim date', render: (r: any) => r.claim_date ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'expense_type', header: 'Type', render: (r: any) => r.expense_type ?? '-' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'repair_job_id', header: 'Repair job', render: (r: any) => (r.repair_job_id ? String(r.repair_job_id).slice(0, 8) : '-') },
    { key: 'receipt_url', header: 'Receipt', render: (r: any) => (r.receipt_url ? 'attached' : '-') },
    { key: 'decided_at', header: 'Decided', render: (r: any) => fmtDate(r.decided_at) },
    { key: 'created_at', header: 'Submitted', render: (r: any) => fmtDate(r.created_at) },
  ];

  const summaryColumns: Column<SummaryRow>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'claim_count', header: 'Claims', render: (r: any) => String(r.claim_count ?? 0) },
    { key: 'total_amount_rupees', header: 'Total amount', render: (r: any) => fmtRupees(r.total_amount_rupees) },
  ];

  const topColumns: Column<TopRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'claim_count', header: 'Total claims', render: (r: any) => String(r.claim_count ?? 0) },
    { key: 'approved_count', header: 'Approved/paid', render: (r: any) => String(r.approved_count ?? 0) },
    { key: 'total_rupees', header: 'Reimbursed', render: (r: any) => fmtRupees(r.total_rupees) },
  ];

  const reviewColumns: Column<ReviewRow>[] = [
    { key: 'decided_at', header: 'When', render: (r: any) => fmtDate(r.decided_at) },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email ?? '-' },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '-' },
    { key: 'claim_id', header: 'Claim', render: (r: any) => (r.claim_id ? String(r.claim_id).slice(0, 8) : '-') },
    { key: 'decision_note', header: 'Note', render: (r: any) => r.decision_note ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        Engineer Expense Reimbursement
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Engineer-submitted reimbursement claims, founder review trail, and payout queue. Approve & pay flow gates spend.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending claims summary</h2>
        <DataTable
          rows={summary}
          columns={summaryColumns}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent claims</h2>
        <DataTable
          rows={claims}
          columns={claimColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top claimers</h2>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Review log</h2>
        <DataTable
          rows={reviews}
          columns={reviewColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
