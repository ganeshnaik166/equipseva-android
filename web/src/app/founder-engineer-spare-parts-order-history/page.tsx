import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerSparePartsOrderHistoryPage() {
  const sb = await getSupabaseServerClient();

  const [ordersRes, usageRes, spendRes, returnsRes] = await Promise.all([
    sb.rpc('list_engineer_spare_parts_orders_r1728'),
    sb.rpc('list_engineer_spare_parts_usage_r1728'),
    sb.rpc('engineer_spare_parts_spend_summary_r1728'),
    sb.rpc('engineer_spare_parts_returns_audit_r1728'),
  ]);

  const orders: any[] = Array.isArray(ordersRes.data) ? ordersRes.data : [];
  const usage: any[] = Array.isArray(usageRes.data) ? usageRes.data : [];
  const spend: any[] = Array.isArray(spendRes.data) ? spendRes.data : [];
  const returns: any[] = Array.isArray(returnsRes.data) ? returnsRes.data : [];

  const orderCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id?.slice(0, 8)}</span> },
    { key: 'part_name', header: 'Part', render: (r: any) => <span>{r.part_name}</span> },
    { key: 'part_sku', header: 'SKU', render: (r: any) => <span className="font-mono text-xs">{r.part_sku ?? '-'}</span> },
    { key: 'quantity', header: 'Qty', render: (r: any) => <span>{r.quantity}</span> },
    { key: 'unit_cost_rupees', header: 'Unit', render: (r: any) => <span>{'₹'}{Number(r.unit_cost_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'total_cost_rupees', header: 'Total', render: (r: any) => <span>{'₹'}{Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'ordered_at', header: 'Ordered', render: (r: any) => <span>{r.ordered_at ? new Date(r.ordered_at).toLocaleDateString('en-IN') : '-'}</span> },
    { key: 'expected_at', header: 'Expected', render: (r: any) => <span>{r.expected_at ? new Date(r.expected_at).toLocaleDateString('en-IN') : '-'}</span> },
    { key: 'delivered_at', header: 'Delivered', render: (r: any) => <span>{r.delivered_at ? new Date(r.delivered_at).toLocaleDateString('en-IN') : '-'}</span> },
  ];

  const usageCols: Column<any>[] = [
    { key: 'part_name', header: 'Part', render: (r: any) => <span>{r.part_name ?? '-'}</span> },
    { key: 'order_id', header: 'Order', render: (r: any) => <span className="font-mono text-xs">{r.order_id?.slice(0, 8)}</span> },
    { key: 'used_in_repair_job_id', header: 'Repair Job', render: (r: any) => <span className="font-mono text-xs">{r.used_in_repair_job_id?.slice(0, 8) ?? '-'}</span> },
    { key: 'returned_quantity', header: 'Returned Qty', render: (r: any) => <span>{r.returned_quantity ?? 0}</span> },
    { key: 'return_reason', header: 'Return Reason', render: (r: any) => <span>{r.return_reason ?? '-'}</span> },
    { key: 'used_at', header: 'Used At', render: (r: any) => <span>{r.used_at ? new Date(r.used_at).toLocaleString('en-IN') : '-'}</span> },
  ];

  const spendCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id?.slice(0, 8)}</span> },
    { key: 'total_orders', header: 'Orders', render: (r: any) => <span>{r.total_orders}</span> },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r: any) => <span>{'₹'}{Number(r.total_spend_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'delivered_count', header: 'Delivered', render: (r: any) => <span>{r.delivered_count}</span> },
    { key: 'cancelled_count', header: 'Cancelled', render: (r: any) => <span>{r.cancelled_count}</span> },
  ];

  const returnsCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id?.slice(0, 8)}</span> },
    { key: 'part_name', header: 'Part', render: (r: any) => <span>{r.part_name}</span> },
    { key: 'returned_quantity', header: 'Returned Qty', render: (r: any) => <span>{r.returned_quantity}</span> },
    { key: 'return_reason', header: 'Reason', render: (r: any) => <span>{r.return_reason ?? '-'}</span> },
    { key: 'used_at', header: 'Used At', render: (r: any) => <span>{r.used_at ? new Date(r.used_at).toLocaleString('en-IN') : '-'}</span> },
  ];

  const totalSpend = spend.reduce((acc: number, r: any) => acc + Number(r.total_spend_rupees ?? 0), 0);
  const totalOrders = orders.length;
  const totalReturns = returns.length;

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Spare Parts Order History</h1>
        <p className="text-sm text-gray-600">
          Per-engineer parts ordering, delivery, and usage tracking. Surfaces overspend, return patterns, and delivery SLA breaches.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total Orders</div>
          <div className="text-2xl font-semibold">{totalOrders}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total Spend</div>
          <div className="text-2xl font-semibold">{'₹'}{totalSpend.toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Returns Logged</div>
          <div className="text-2xl font-semibold">{totalReturns}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent Orders</h2>
        <DataTable rows={orders} columns={orderCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Per-Engineer Spend Summary</h2>
        <DataTable rows={spend} columns={spendCols} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Usage Log</h2>
        <DataTable rows={usage} columns={usageCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Returns Audit (returned qty &gt; 0)</h2>
        <DataTable rows={returns} columns={returnsCols} rowKey={(r: any, i: number) => String(r.usage_id ?? i)} />
      </section>
    </div>
  );
}
