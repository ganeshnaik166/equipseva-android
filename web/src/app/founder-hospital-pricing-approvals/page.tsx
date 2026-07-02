import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ApprovalRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  quote_id: string;
  total_quote_rupees: number;
  requires_approvals: string[] | null;
  obtained_approvals: string[] | null;
  status: string;
  decided_at: string | null;
  created_at: string;
};

type TopPendingRow = {
  id: string;
  hospital_user_id: string;
  quote_id: string;
  total_quote_rupees: number;
  status: string;
  created_at: string;
};

type DecisionRow = {
  log_id: string;
  approval_id: string;
  quote_id: string;
  approver_role: string;
  decision: string;
  decided_at: string;
  decision_note: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN');
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [approvalsRes, topPendingRes, recentRes] = await Promise.all([
    sb.rpc('list_pricing_approvals_r1871'),
    sb.rpc('top_pending_pricing_approvals_r1871'),
    sb.rpc('recent_pricing_approval_decisions_r1871'),
  ]);

  const approvals: ApprovalRow[] = (approvalsRes.data as ApprovalRow[]) || [];
  const topPending: TopPendingRow[] = (topPendingRes.data as TopPendingRow[]) || [];
  const recent: DecisionRow[] = (recentRes.data as DecisionRow[]) || [];

  const errs = [approvalsRes.error, topPendingRes.error, recentRes.error]
    .filter(Boolean)
    .map((e) => (e as { message: string }).message);

  const approvalCols: Column<ApprovalRow>[] = [
    { key: 'quote_id', header: 'Quote', render: (r: any) => <span className="font-mono text-xs">{r.quote_id}</span> },
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span>{r.hospital_email ?? r.hospital_user_id}</span> },
    { key: 'total', header: 'Total', render: (r: any) => <span>{fmtRupees(r.total_quote_rupees)}</span> },
    {
      key: 'required',
      header: 'Required',
      render: (r: any) => <span className="text-xs">{(r.requires_approvals ?? []).join(', ') || '-'}</span>,
    },
    {
      key: 'obtained',
      header: 'Obtained',
      render: (r: any) => <span className="text-xs">{(r.obtained_approvals ?? []).join(', ') || '-'}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span>,
    },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span>{fmtDate(r.decided_at)}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{fmtDate(r.created_at)}</span> },
  ];

  const topCols: Column<TopPendingRow>[] = [
    { key: 'quote_id', header: 'Quote', render: (r: any) => <span className="font-mono text-xs">{r.quote_id}</span> },
    { key: 'total', header: 'Value', render: (r: any) => <span className="font-medium">{fmtRupees(r.total_quote_rupees)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{fmtDate(r.created_at)}</span> },
  ];

  const recentCols: Column<DecisionRow>[] = [
    { key: 'quote_id', header: 'Quote', render: (r: any) => <span className="font-mono text-xs">{r.quote_id}</span> },
    { key: 'role', header: 'Role', render: (r: any) => <span>{r.approver_role}</span> },
    {
      key: 'decision',
      header: 'Decision',
      render: (r: any) => (
        <span
          className={
            r.decision === 'approve'
              ? 'rounded bg-green-100 px-2 py-0.5 text-xs text-green-800'
              : r.decision === 'decline'
              ? 'rounded bg-red-100 px-2 py-0.5 text-xs text-red-800'
              : 'rounded bg-yellow-100 px-2 py-0.5 text-xs text-yellow-800'
          }
        >
          {r.decision}
        </span>
      ),
    },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span>{fmtDate(r.decided_at)}</span> },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs text-[var(--color-muted)]">{r.decision_note ?? '-'}</span> },
  ];

  const totalValue = approvals.reduce((s, r) => s + (r.total_quote_rupees || 0), 0);
  const pendingCount = approvals.filter((r) => r.status === 'pending' || r.status === 'in_progress').length;
  const approvedCount = approvals.filter((r) => r.status === 'approved').length;
  const declinedCount = approvals.filter((r) => r.status === 'declined').length;

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Multi-Stakeholder Pricing Approvals</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Round 1871 · quotes needing CFO + CMO + procurement sign-off before contract.
        </p>
      </header>

      {errs.length > 0 && (
        <div className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">
          {errs.map((m, i) => (
            <div key={i}>{m}</div>
          ))}
        </div>
      )}

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="text-xs uppercase text-[var(--color-muted)]">Total Pipeline</div>
          <div className="mt-1 text-xl font-semibold">{fmtRupees(totalValue)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="text-xs uppercase text-[var(--color-muted)]">Pending</div>
          <div className="mt-1 text-xl font-semibold">{pendingCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="text-xs uppercase text-[var(--color-muted)]">Approved</div>
          <div className="mt-1 text-xl font-semibold text-green-700">{approvedCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="text-xs uppercase text-[var(--color-muted)]">Declined</div>
          <div className="mt-1 text-xl font-semibold text-red-700">{declinedCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All approval requests</h2>
        <DataTable<ApprovalRow>
          rows={approvals}
          columns={approvalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No pricing approval requests yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top pending by quote value</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Highest-value quotes still awaiting at least one stakeholder sign-off.
        </p>
        <DataTable<TopPendingRow>
          rows={topPending}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No pending high-value quotes."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent stakeholder decisions</h2>
        <DataTable<DecisionRow>
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.log_id ?? i)}
          emptyMessage="No decisions logged yet."
        />
      </section>
    </main>
  );
}
