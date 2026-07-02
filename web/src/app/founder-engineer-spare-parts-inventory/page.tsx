import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [inv, low, recent] = await Promise.all([
    sb.rpc('list_inventory_r2156'),
    sb.rpc('critical_low_r2156'),
    sb.rpc('recent_actions_r2156'),
  ]);

  const inventoryRows: any[] = Array.isArray(inv.data) ? inv.data : [];
  const lowRows: any[] = Array.isArray(low.data) ? low.data : [];
  const recentRows: any[] = Array.isArray(recent.data) ? recent.data : [];

  const inventoryCols: Column<any>[] = [
    { key: 'part_label', header: 'Part', render: (r: any) => String(r.part_label ?? '') },
    { key: 'part_category', header: 'Category', render: (r: any) => String(r.part_category ?? '') },
    { key: 'quantity_on_hand', header: 'On hand', render: (r: any) => String(r.quantity_on_hand ?? 0) },
    { key: 'par_level', header: 'Par level', render: (r: any) => String(r.par_level ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const lowCols: Column<any>[] = [
    { key: 'part_label', header: 'Part', render: (r: any) => String(r.part_label ?? '') },
    { key: 'part_category', header: 'Category', render: (r: any) => String(r.part_category ?? '') },
    { key: 'quantity_on_hand', header: 'On hand', render: (r: any) => String(r.quantity_on_hand ?? 0) },
    { key: 'par_level', header: 'Par level', render: (r: any) => String(r.par_level ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'quantity_change', header: 'Qty change', render: (r: any) => String(r.quantity_change ?? 0) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Spare Parts Inventory</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track parts engineers carry in the field. Watch par levels and reorder before critical use.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Full inventory</h2>
        <DataTable rows={inventoryRows} columns={inventoryCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical and low stock</h2>
        <DataTable rows={lowRows} columns={lowCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent action log</h2>
        <DataTable rows={recentRows} columns={actionsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
