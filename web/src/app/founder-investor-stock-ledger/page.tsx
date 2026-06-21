import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [ledgerRes, txRes, perClassRes, topRes] = await Promise.all([
    sb.rpc('list_ledger_r1797'),
    sb.rpc('list_transactions_r1797', { p_ledger_id: null }),
    sb.rpc('total_outstanding_per_class_r1797'),
    sb.rpc('top_holders_r1797', { p_limit: 10 }),
  ]);

  const ledger: any[] = Array.isArray(ledgerRes.data) ? ledgerRes.data : [];
  const txs: any[] = Array.isArray(txRes.data) ? txRes.data : [];
  const perClass: any[] = Array.isArray(perClassRes.data) ? perClassRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];

  const totalOutstanding = perClass.reduce((s, r) => s + Number(r.total_outstanding || 0), 0);
  const activeHolders = ledger.filter((r) => r.status === 'active').length;

  const ledgerCols: Column<any>[] = [
    { key: 'holder_name', header: 'Holder', render: (r: any) => <span className="font-medium">{r.holder_name}</span> },
    { key: 'holder_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.holder_type}</span> },
    { key: 'share_class', header: 'Class', render: (r: any) => <span className="text-xs uppercase">{r.share_class}</span> },
    { key: 'shares_held', header: 'Issued', render: (r: any) => <span className="tabular-nums">{Number(r.shares_held || 0).toLocaleString()}</span> },
    { key: 'current_balance', header: 'Balance', render: (r: any) => <span className="tabular-nums font-semibold">{Number(r.current_balance || 0).toLocaleString()}</span> },
    { key: 'certificate_number', header: 'Cert#', render: (r: any) => <span className="text-xs">{r.certificate_number || '—'}</span> },
    { key: 'issued_date', header: 'Issued', render: (r: any) => <span className="text-xs">{r.issued_date || '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs uppercase">{r.status}</span> },
  ];

  const txCols: Column<any>[] = [
    { key: 'transaction_date', header: 'Date', render: (r: any) => <span className="text-xs">{r.transaction_date || '—'}</span> },
    { key: 'holder_name', header: 'Holder', render: (r: any) => <span>{r.holder_name}</span> },
    { key: 'transaction_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.transaction_type}</span> },
    { key: 'shares_delta', header: 'Delta', render: (r: any) => {
        const v = Number(r.shares_delta || 0);
        return <span className={`tabular-nums ${v >= 0 ? 'text-green-700' : 'text-red-700'}`}>{v >= 0 ? '+' : ''}{v.toLocaleString()}</span>;
      } },
    { key: 'counterparty_holder', header: 'Counterparty', render: (r: any) => <span className="text-xs">{r.counterparty_holder || '—'}</span> },
    { key: 'transaction_note', header: 'Note', render: (r: any) => <span className="text-xs text-gray-600">{r.transaction_note || '—'}</span> },
  ];

  const perClassCols: Column<any>[] = [
    { key: 'share_class', header: 'Share Class', render: (r: any) => <span className="font-medium uppercase">{r.share_class}</span> },
    { key: 'total_outstanding', header: 'Outstanding', render: (r: any) => <span className="tabular-nums font-semibold">{Number(r.total_outstanding || 0).toLocaleString()}</span> },
    { key: 'holder_count', header: 'Active Holders', render: (r: any) => <span className="tabular-nums">{r.holder_count}</span> },
  ];

  const topCols: Column<any>[] = [
    { key: 'holder_name', header: 'Holder', render: (r: any) => <span className="font-medium">{r.holder_name}</span> },
    { key: 'holder_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.holder_type}</span> },
    { key: 'share_class', header: 'Class', render: (r: any) => <span className="text-xs uppercase">{r.share_class}</span> },
    { key: 'current_balance', header: 'Balance', render: (r: any) => <span className="tabular-nums">{Number(r.current_balance || 0).toLocaleString()}</span> },
    { key: 'pct_of_total', header: '% of Total', render: (r: any) => <span className="tabular-nums">{Number(r.pct_of_total || 0).toFixed(2)}%</span> },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Investor Stock Ledger</h1>
        <p className="text-sm text-gray-600 mt-1">
          Authoritative cap-table source of truth. Every issuance, transfer & exercise logged.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Total Outstanding</div>
          <div className="text-2xl font-bold tabular-nums mt-1">{totalOutstanding.toLocaleString()}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Active Holders</div>
          <div className="text-2xl font-bold tabular-nums mt-1">{activeHolders}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Share Classes</div>
          <div className="text-2xl font-bold tabular-nums mt-1">{perClass.length}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Transactions Logged</div>
          <div className="text-2xl font-bold tabular-nums mt-1">{txs.length}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-3">Outstanding by Share Class</h2>
        <DataTable rows={perClass} columns={perClassCols} rowKey={(r: any, i: number) => String(r.share_class ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top 10 Holders</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Full Ledger ({ledger.length})</h2>
        <DataTable rows={ledger} columns={ledgerCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Transactions ({txs.length})</h2>
        <DataTable rows={txs} columns={txCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <div className="text-xs text-gray-500 border-t pt-4">
        Legal source of truth. Balance = issued shares + sum of non-issuance deltas. Use recompute_balance_r1797 to reconcile.
      </div>
    </div>
  );
}
