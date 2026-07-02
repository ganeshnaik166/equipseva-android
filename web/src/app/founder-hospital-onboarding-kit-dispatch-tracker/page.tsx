import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, kits, delayed, receipt, couriers, components, events] = await Promise.all([
    sb.rpc('r2275_kit_dispatch_summary'),
    sb.rpc('r2275_kit_list'),
    sb.rpc('r2275_delayed_kits'),
    sb.rpc('r2275_receipt_pending'),
    sb.rpc('r2275_courier_breakdown'),
    sb.rpc('r2275_component_coverage'),
    sb.rpc('r2275_recent_events'),
  ]);

  const s = (summary.data?.[0] ?? {}) as Record<string, unknown>;

  const kitCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'kit_tier', header: 'Tier', render: (r) => r.kit_tier },
    { key: 'total_components_count', header: 'Items', render: (r) => r.total_components_count },
    { key: 'dispatch_status', header: 'Status', render: (r) => r.dispatch_status },
    { key: 'courier_partner', header: 'Courier', render: (r) => r.courier_partner ?? '—' },
    { key: 'tracking_number', header: 'Tracking', render: (r) => r.tracking_number ?? '—' },
    { key: 'dispatched_at', header: 'Dispatched', render: (r) => r.dispatched_at ? new Date(r.dispatched_at).toLocaleDateString() : '—' },
    { key: 'delivered_at', header: 'Delivered', render: (r) => r.delivered_at ? new Date(r.delivered_at).toLocaleDateString() : '—' },
    { key: 'delay_hours', header: 'Delay (h)', render: (r) => r.delay_hours },
    { key: 'kit_value_rupees', header: 'Value', render: (r) => `₹${(r.kit_value_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const delayedCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'courier_partner', header: 'Courier', render: (r) => r.courier_partner ?? '—' },
    { key: 'tracking_number', header: 'Tracking', render: (r) => r.tracking_number ?? '—' },
    { key: 'estimated_delivery_at', header: 'ETA', render: (r) => r.estimated_delivery_at ? new Date(r.estimated_delivery_at).toLocaleDateString() : '—' },
    { key: 'delay_hours', header: 'Delay (h)', render: (r) => r.delay_hours },
    { key: 'delay_reason', header: 'Reason', render: (r) => r.delay_reason ?? '—' },
  ];

  const receiptCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'delivered_at', header: 'Delivered', render: (r) => r.delivered_at ? new Date(r.delivered_at).toLocaleDateString() : '—' },
    { key: 'days_since_delivery', header: 'Days since', render: (r) => r.days_since_delivery },
  ];

  const courierCols: Column<any>[] = [
    { key: 'courier_partner', header: 'Courier', render: (r) => r.courier_partner },
    { key: 'kit_count', header: 'Kits', render: (r) => r.kit_count },
    { key: 'delivered_count', header: 'Delivered', render: (r) => r.delivered_count },
    { key: 'delayed_count', header: 'Delayed', render: (r) => r.delayed_count },
    { key: 'avg_delay_hours', header: 'Avg delay (h)', render: (r) => Number(r.avg_delay_hours ?? 0).toFixed(1) },
  ];

  const componentCols: Column<any>[] = [
    { key: 'kit_tier', header: 'Tier', render: (r) => r.kit_tier },
    { key: 'kit_count', header: 'Kits', render: (r) => r.kit_count },
    { key: 'total_components', header: 'Total items', render: (r) => r.total_components },
    { key: 'total_value_rupees', header: 'Total value', render: (r) => `₹${(r.total_value_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_at', header: 'When', render: (r) => new Date(r.event_at).toLocaleString() },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'location', header: 'Location', render: (r) => r.location ?? '—' },
    { key: 'actor_email', header: 'Actor', render: (r) => r.actor_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Hospital Onboarding Kit Dispatch Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track kit components, dispatch status, receipt confirmations & delays for newly signed hospitals.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 32 }}>
        <KPI label="Total kits" value={String(s.total_kits ?? 0)} />
        <KPI label="Pending" value={String(s.pending_count ?? 0)} />
        <KPI label="In transit" value={String(s.in_transit_count ?? 0)} />
        <KPI label="Delivered" value={String(s.delivered_count ?? 0)} />
        <KPI label="Receipt confirmed" value={String(s.receipt_confirmed_count ?? 0)} />
        <KPI label="Delayed" value={String(s.delayed_count ?? 0)} />
        <KPI label="Lost" value={String(s.lost_count ?? 0)} />
        <KPI label="Total kit value" value={`₹${Number(s.total_kit_value_rupees ?? 0).toLocaleString('en-IN')}`} />
      </div>

      <Section title="All kits">
        <DataTable columns={kitCols} rows={(kits.data ?? []) as any[]} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Delayed kits — needs escalation">
        <DataTable columns={delayedCols} rows={(delayed.data ?? []) as any[]} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Receipt pending — delivered but unconfirmed">
        <DataTable columns={receiptCols} rows={(receipt.data ?? []) as any[]} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Courier breakdown">
        <DataTable columns={courierCols} rows={(couriers.data ?? []) as any[]} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Component coverage by tier">
        <DataTable columns={componentCols} rows={(components.data ?? []) as any[]} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Recent dispatch events">
        <DataTable columns={eventCols} rows={(events.data ?? []) as any[]} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600, color: '#111827' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
