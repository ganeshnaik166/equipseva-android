import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Allocation = {
  id: string;
  period_label: string;
  total_allocated_rupees: number;
  growth_rupees: number;
  ops_rupees: number;
  hires_rupees: number;
  marketing_rupees: number;
  reserves_rupees: number;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  allocation_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  amount_rupees: number;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [allocsRes, currentRes, actionsRes] = await Promise.all([
    sb.rpc('list_allocations_r2102'),
    sb.rpc('current_allocation_r2102'),
    sb.rpc('recent_actions_r2102'),
  ]);

  const allocations: Allocation[] = (allocsRes.data ?? []) as Allocation[];
  const currentRows: Allocation[] = (currentRes.data ?? []) as Allocation[];
  const current = currentRows[0] ?? null;
  const actions: ActionRow[] = (actionsRes.data ?? []) as ActionRow[];

  const fmtRupees = (n: number) =>
    new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n || 0);
  const fmtDate = (s: string) => (s ? new Date(s).toLocaleString('en-IN') : '');

  const allocColumns: Column<Allocation>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label },
    { key: 'total_allocated_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_allocated_rupees) },
    { key: 'growth_rupees', header: 'Growth', render: (r: any) => fmtRupees(r.growth_rupees) },
    { key: 'ops_rupees', header: 'Ops', render: (r: any) => fmtRupees(r.ops_rupees) },
    { key: 'hires_rupees', header: 'Hires', render: (r: any) => fmtRupees(r.hires_rupees) },
    { key: 'marketing_rupees', header: 'Marketing', render: (r: any) => fmtRupees(r.marketing_rupees) },
    { key: 'reserves_rupees', header: 'Reserves', render: (r: any) => fmtRupees(r.reserves_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Type', render: (r: any) => r.action_type },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'allocation_id', header: 'Allocation', render: (r: any) => String(r.allocation_id).slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Capital Allocation Strategy</h1>
        <p className="text-sm text-gray-600">
          Track capital allocation across growth, ops, hires, marketing, and reserves. Founder only.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Current Active Allocation</h2>
        {current ? (
          <div className="rounded border p-4 grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <div className="text-gray-500">Period</div>
              <div className="font-medium">{current.period_label}</div>
            </div>
            <div>
              <div className="text-gray-500">Status</div>
              <div className="font-medium">{current.status}</div>
            </div>
            <div>
              <div className="text-gray-500">Total</div>
              <div className="font-medium">{fmtRupees(current.total_allocated_rupees)}</div>
            </div>
            <div>
              <div className="text-gray-500">Growth</div>
              <div className="font-medium">{fmtRupees(current.growth_rupees)}</div>
            </div>
            <div>
              <div className="text-gray-500">Ops</div>
              <div className="font-medium">{fmtRupees(current.ops_rupees)}</div>
            </div>
            <div>
              <div className="text-gray-500">Hires</div>
              <div className="font-medium">{fmtRupees(current.hires_rupees)}</div>
            </div>
            <div>
              <div className="text-gray-500">Marketing</div>
              <div className="font-medium">{fmtRupees(current.marketing_rupees)}</div>
            </div>
            <div>
              <div className="text-gray-500">Reserves</div>
              <div className="font-medium">{fmtRupees(current.reserves_rupees)}</div>
            </div>
          </div>
        ) : (
          <div className="text-sm text-gray-500">No active allocation captured yet.</div>
        )}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Allocations</h2>
        <DataTable
          rows={allocations}
          columns={allocColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
