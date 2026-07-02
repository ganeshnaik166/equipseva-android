import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reimbsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_reimbursements_r1932', { p_limit: 100 }),
    sb.rpc('top_engineers_by_amount_r1932', { p_limit: 20 }),
    sb.rpc('recent_actions_r1932', { p_limit: 50 }),
  ]);

  const reimbs: any[] = Array.isArray(reimbsRes.data) ? reimbsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const reimbCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id ?? '').slice(0, 8)}</span> },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'expense_category', header: 'Category', render: (r: any) => <span>{String(r.expense_category ?? '')}</span> },
    { key: 'claimed_amount_rupees', header: 'Claimed', render: (r: any) => <span>₹{Number(r.claimed_amount_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'approved_amount_rupees', header: 'Approved', render: (r: any) => <span>₹{Number(r.approved_amount_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs font-semibold">{String(r.status ?? '')}</span> },
    { key: 'claimed_at', header: 'Claimed At', render: (r: any) => <span>{r.claimed_at ? new Date(r.claimed_at).toLocaleString('en-IN') : ''}</span> },
    { key: 'paid_at', header: 'Paid At', render: (r: any) => <span>{r.paid_at ? new Date(r.paid_at).toLocaleString('en-IN') : 'pending'}</span> },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'total_claimed', header: 'Total Claimed', render: (r: any) => <span>₹{Number(r.total_claimed ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'total_approved', header: 'Total Approved', render: (r: any) => <span>₹{Number(r.total_approved ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'claim_count', header: 'Claims', render: (r: any) => <span>{Number(r.claim_count ?? 0)}</span> },
  ];

  const actionCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id ?? '').slice(0, 8)}</span> },
    { key: 'reimbursement_id', header: 'Reimb', render: (r: any) => <span className="font-mono text-xs">{String(r.reimbursement_id ?? '').slice(0, 8)}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span className="uppercase text-xs font-semibold">{String(r.action_type ?? '')}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{String(r.by_email ?? '')}</span> },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : ''}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs">{String(r.notes_md ?? '').slice(0, 80)}</span> },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Travel Reimbursement Ledger</h1>
        <p className="text-sm text-gray-600 mt-1">Founder console — track engineer travel reimbursement claims, approvals, and payouts.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reimbursement Claims (last 100)</h2>
        <DataTable rows={reimbs} columns={reimbCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Engineers by Claimed Amount</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions (last 50)</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
