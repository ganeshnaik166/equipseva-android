import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [vendorsRes, preferredRes, recentRes] = await Promise.all([
    sb.rpc('r2111_list_vendors'),
    sb.rpc('r2111_preferred_vendors'),
    sb.rpc('r2111_recent_actions'),
  ]);

  const vendors = (vendorsRes.data ?? []) as any[];
  const preferred = (preferredRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const vendorCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name ?? '' },
    { key: 'vendor_specialty', header: 'Specialty', render: (r: any) => String(r.vendor_specialty ?? '') },
    { key: 'reliability_score', header: 'Reliability', render: (r: any) => String(r.reliability_score ?? '') },
    { key: 'lead_time_days', header: 'Lead time (days)', render: (r: any) => String(r.lead_time_days ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const preferredCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name ?? '' },
    { key: 'vendor_specialty', header: 'Specialty', render: (r: any) => String(r.vendor_specialty ?? '') },
    { key: 'reliability_score', header: 'Reliability', render: (r: any) => String(r.reliability_score ?? '') },
    { key: 'lead_time_days', header: 'Lead time (days)', render: (r: any) => String(r.lead_time_days ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => r.vendor_name ?? '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Equipment Sourcing Vendor Map</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track imaging suppliers, parts suppliers, consumables, diagnostics, and full lifecycle vendors. Mark preferred and log actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All vendors</h2>
        <DataTable
          rows={vendors}
          columns={vendorCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Preferred vendors</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Top reliability, sorted by score.</p>
        <DataTable
          rows={preferred}
          columns={preferredCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions (last 30 days)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
