import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerEquipmentLoanOutPage() {
  const sb = await getSupabaseServerClient();

  const [loansRes, returnsRes, overdueRes, topBorrowersRes] = await Promise.all([
    sb.rpc('list_loans_r1736'),
    sb.rpc('list_returns_r1736'),
    sb.rpc('overdue_loans_r1736'),
    sb.rpc('top_borrowers_r1736'),
  ]);

  const loans: any[] = Array.isArray(loansRes.data) ? loansRes.data : [];
  const returns: any[] = Array.isArray(returnsRes.data) ? returnsRes.data : [];
  const overdue: any[] = Array.isArray(overdueRes.data) ? overdueRes.data : [];
  const topBorrowers: any[] = Array.isArray(topBorrowersRes.data) ? topBorrowersRes.data : [];

  const totalLoans = loans.length;
  const activeLoans = loans.filter((l) => l.status === 'active').length;
  const overdueCount = overdue.length;
  const lostLoans = loans.filter((l) => l.status === 'lost').length;

  const loanColumns: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => <span className="font-medium">{r.equipment_name ?? '—'}</span> },
    { key: 'lender_email', header: 'Lender', render: (r: any) => <span className="text-sm">{r.lender_email ?? '—'}</span> },
    { key: 'borrower_email', header: 'Borrower', render: (r: any) => <span className="text-sm">{r.borrower_email ?? '—'}</span> },
    { key: 'loaned_at', header: 'Loaned At', render: (r: any) => <span className="text-xs text-gray-600">{r.loaned_at ? new Date(r.loaned_at).toLocaleDateString() : '—'}</span> },
    { key: 'expected_return_at', header: 'Expected Return', render: (r: any) => <span className="text-xs text-gray-600">{r.expected_return_at ? new Date(r.expected_return_at).toLocaleDateString() : '—'}</span> },
    { key: 'days_outstanding', header: 'Days Out', render: (r: any) => <span className="font-mono text-sm">{r.days_outstanding ?? 0}</span> },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => {
        const cls =
          r.status === 'active' ? 'bg-blue-100 text-blue-800'
          : r.status === 'returned' ? 'bg-green-100 text-green-800'
          : r.status === 'overdue' ? 'bg-amber-100 text-amber-800'
          : r.status === 'lost' ? 'bg-red-100 text-red-800'
          : 'bg-gray-100 text-gray-800';
        return <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${cls}`}>{r.status ?? '—'}</span>;
      },
    },
    { key: 'founder_note', header: 'Note', render: (r: any) => <span className="text-xs text-gray-500">{r.founder_note ?? '—'}</span> },
  ];

  const returnColumns: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => <span className="font-medium">{r.equipment_name ?? '—'}</span> },
    { key: 'borrower_email', header: 'Borrower', render: (r: any) => <span className="text-sm">{r.borrower_email ?? '—'}</span> },
    {
      key: 'returned_condition',
      header: 'Condition',
      render: (r: any) => {
        const cls =
          r.returned_condition === 'pristine' ? 'bg-green-100 text-green-800'
          : r.returned_condition === 'wear' ? 'bg-blue-100 text-blue-800'
          : r.returned_condition === 'damaged' ? 'bg-amber-100 text-amber-800'
          : r.returned_condition === 'lost' ? 'bg-red-100 text-red-800'
          : 'bg-gray-100 text-gray-800';
        return <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${cls}`}>{r.returned_condition ?? '—'}</span>;
      },
    },
    { key: 'returned_at', header: 'Returned At', render: (r: any) => <span className="text-xs text-gray-600">{r.returned_at ? new Date(r.returned_at).toLocaleString() : '—'}</span> },
    { key: 'dispute_reason', header: 'Dispute', render: (r: any) => <span className="text-xs text-gray-500">{r.dispute_reason ?? '—'}</span> },
  ];

  const overdueColumns: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => <span className="font-medium">{r.equipment_name ?? '—'}</span> },
    { key: 'borrower_email', header: 'Borrower', render: (r: any) => <span className="text-sm">{r.borrower_email ?? '—'}</span> },
    { key: 'lender_email', header: 'Lender', render: (r: any) => <span className="text-sm">{r.lender_email ?? '—'}</span> },
    { key: 'expected_return_at', header: 'Expected', render: (r: any) => <span className="text-xs text-gray-600">{r.expected_return_at ? new Date(r.expected_return_at).toLocaleDateString() : '—'}</span> },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => <span className="font-mono text-sm text-red-700">{r.days_overdue ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status ?? '—'}</span> },
  ];

  const borrowerColumns: Column<any>[] = [
    { key: 'borrower_email', header: 'Borrower', render: (r: any) => <span className="font-medium">{r.borrower_email ?? '—'}</span> },
    { key: 'total_loans', header: 'Total', render: (r: any) => <span className="font-mono text-sm">{r.total_loans ?? 0}</span> },
    { key: 'active_loans', header: 'Active', render: (r: any) => <span className="font-mono text-sm text-blue-700">{r.active_loans ?? 0}</span> },
    { key: 'overdue_loans', header: 'Overdue', render: (r: any) => <span className="font-mono text-sm text-amber-700">{r.overdue_loans ?? 0}</span> },
    { key: 'lost_loans', header: 'Lost', render: (r: any) => <span className="font-mono text-sm text-red-700">{r.lost_loans ?? 0}</span> },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Equipment Loan Out</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track tools and diagnostics loaned engineer-to-engineer. Monitor active, overdue & lost equipment.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Total Loans</div>
          <div className="text-2xl font-bold mt-1">{totalLoans}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Active</div>
          <div className="text-2xl font-bold text-blue-700 mt-1">{activeLoans}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Overdue</div>
          <div className="text-2xl font-bold text-amber-700 mt-1">{overdueCount}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Lost</div>
          <div className="text-2xl font-bold text-red-700 mt-1">{lostLoans}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Loans</h2>
        <p className="text-xs text-gray-500 mb-2">Days outstanding &gt;= expected return triggers overdue review.</p>
        <DataTable rows={loans} columns={loanColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Overdue Loans</h2>
        <p className="text-xs text-gray-500 mb-2">Loans past expected return date & not yet returned.</p>
        <DataTable rows={overdue} columns={overdueColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Return Log</h2>
        <p className="text-xs text-gray-500 mb-2">Recorded returns with condition assessment.</p>
        <DataTable rows={returns} columns={returnColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Borrowers</h2>
        <p className="text-xs text-gray-500 mb-2">Engineers who borrow most frequently — watch for lost-loan patterns.</p>
        <DataTable rows={topBorrowers} columns={borrowerColumns} rowKey={(r: any, i: number) => String(r.borrower_user_id ?? i)} />
      </section>
    </div>
  );
}
