import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rightsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_co_sale_rights_r2089'),
    sb.rpc('co_sale_expiring_soon_r2089'),
    sb.rpc('recent_co_sale_actions_r2089'),
  ]);

  const rights: any[] = (rightsRes.data as any[]) ?? [];
  const expiring: any[] = (expiringRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const totalActive = rights.filter((r) => r.status === 'active').length;
  const totalExercised = rights.filter((r) => r.status === 'exercised').length;
  const totalWaived = rights.filter((r) => r.status === 'waived').length;

  const rightsColumns: Column<any>[] = [
    { key: 'co_sale_label', header: 'Label', render: (r: any) => String(r.co_sale_label ?? '') },
    { key: 'max_co_sale_shares', header: 'Max Shares', render: (r: any) => Number(r.max_co_sale_shares ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => (r.expires_at ? new Date(r.expires_at).toLocaleDateString('en-IN') : 'no expiry') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleDateString('en-IN') : '') },
  ];

  const expiringColumns: Column<any>[] = [
    { key: 'co_sale_label', header: 'Label', render: (r: any) => String(r.co_sale_label ?? '') },
    { key: 'max_co_sale_shares', header: 'Max Shares', render: (r: any) => Number(r.max_co_sale_shares ?? 0).toLocaleString('en-IN') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => (r.expires_at ? new Date(r.expires_at).toLocaleDateString('en-IN') : '') },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => String(r.days_remaining ?? 0) },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'co_sale_label', header: 'Label', render: (r: any) => String(r.co_sale_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'shares_co_sold', header: 'Shares Co-Sold', render: (r: any) => Number(r.shares_co_sold ?? 0).toLocaleString('en-IN') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Co-Sale Right Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track investor co-sale (tag-along) rights, exercise status, and expiry timelines.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Active Rights</div>
          <div className="text-2xl font-semibold">{totalActive}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Exercised</div>
          <div className="text-2xl font-semibold">{totalExercised}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Waived</div>
          <div className="text-2xl font-semibold">{totalWaived}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Co-Sale Rights</h2>
        <DataTable
          rows={rights}
          columns={rightsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Expiring Within 30 Days</h2>
        <DataTable
          rows={expiring}
          columns={expiringColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
