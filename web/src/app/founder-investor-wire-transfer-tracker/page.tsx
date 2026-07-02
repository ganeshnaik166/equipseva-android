import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorWireTransferTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [transfersRes, unreconciledRes, recentReconRes] = await Promise.all([
    sb.rpc('list_investor_wire_transfers_r1953'),
    sb.rpc('unreconciled_investor_wires_r1953'),
    sb.rpc('recent_investor_wire_reconciliations_r1953'),
  ]);

  const transfers: any[] = Array.isArray(transfersRes.data) ? transfersRes.data : [];
  const unreconciled: any[] = Array.isArray(unreconciledRes.data) ? unreconciledRes.data : [];
  const recentRecon: any[] = Array.isArray(recentReconRes.data) ? recentReconRes.data : [];

  const transferCols: Column<any>[] = [
    { key: 'transfer_date', header: 'Date', render: (r: any) => r.transfer_date ?? '—' },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'amount_rupees', header: 'Amount (INR)', render: (r: any) => (r.amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'purpose', header: 'Purpose', render: (r: any) => r.purpose ?? '—' },
    { key: 'currency', header: 'Currency', render: (r: any) => r.currency ?? 'INR' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'reconciled_at', header: 'Reconciled At', render: (r: any) => r.reconciled_at ? new Date(r.reconciled_at).toLocaleString() : '—' },
    { key: 'reference_md', header: 'Reference', render: (r: any) => r.reference_md ?? '—' },
  ];

  const unreconciledCols: Column<any>[] = [
    { key: 'transfer_date', header: 'Date', render: (r: any) => r.transfer_date ?? '—' },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'amount_rupees', header: 'Amount (INR)', render: (r: any) => (r.amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'purpose', header: 'Purpose', render: (r: any) => r.purpose ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'age_days', header: 'Age (days)', render: (r: any) => String(r.age_days ?? 0) },
  ];

  const reconCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'transfer_id', header: 'Transfer', render: (r: any) => String(r.transfer_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const totalReceived = transfers
    .filter((t) => t.status === 'received' || t.status === 'reconciled')
    .reduce((acc, t) => acc + Number(t.amount_rupees ?? 0), 0);

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Investor Wire Transfer Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track investor wire transfers received. Confirm receipt, reconcile to capital-call intents, flag missing intents, open disputes, and process refunds.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Transfers</div>
          <div className="text-2xl font-semibold">{transfers.length}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Unreconciled (pending, received, disputed)</div>
          <div className="text-2xl font-semibold">{unreconciled.length}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Received Plus Reconciled (INR)</div>
          <div className="text-2xl font-semibold">{totalReceived.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">All Transfers</h2>
        <p className="text-sm text-gray-600 mb-3">
          All wire transfers logged in the tracker, most recent first, capped at 500 rows.
        </p>
        <DataTable
          rows={transfers}
          columns={transferCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Unreconciled Queue</h2>
        <p className="text-sm text-gray-600 mb-3">
          Transfers still in pending, received, or disputed status. Sorted by transfer date ascending so the oldest sit at the top.
        </p>
        <DataTable
          rows={unreconciled}
          columns={unreconciledCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Reconciliation Activity</h2>
        <p className="text-sm text-gray-600 mb-3">
          Most recent reconciliation log entries across all transfers, capped at 100 rows.
        </p>
        <DataTable
          rows={recentRecon}
          columns={reconCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
