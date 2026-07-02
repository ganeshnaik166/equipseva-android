import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalEquipmentWarrantyExpiryPage() {
  const sb = await getSupabaseServerClient();

  const [warrantiesRes, expiringRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_warranties_r1903'),
    sb.rpc('expiring_within_30d_r1903'),
    sb.rpc('recent_renewal_actions_r1903'),
  ]);

  const warranties: any[] = Array.isArray(warrantiesRes.data) ? warrantiesRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const totalCount = warranties.length;
  const expiringCount = expiring.length;
  const expiredCount = warranties.filter((w) => w.status === 'expired').length;
  const renewedCount = warranties.filter((w) => w.status === 'renewed').length;
  const escalatedCount = warranties.filter((w) => w.status === 'escalated').length;

  const warrantyColumns: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '-') },
    { key: 'purchase_date', header: 'Purchased', render: (r: any) => r.purchase_date ? String(r.purchase_date) : '-' },
    { key: 'warranty_expires_on', header: 'Expires', render: (r: any) => String(r.warranty_expires_on ?? '') },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => r.days_remaining === null || r.days_remaining === undefined ? '-' : String(r.days_remaining) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '-' },
  ];

  const expiringColumns: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '-') },
    { key: 'warranty_expires_on', header: 'Expires On', render: (r: any) => String(r.warranty_expires_on ?? '') },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => String(r.days_remaining ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
  ];

  const actionsColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'cost_estimate_rupees', header: 'Cost (Rs)', render: (r: any) => r.cost_estimate_rupees ? Number(r.cost_estimate_rupees).toLocaleString('en-IN') : '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Hospital Equipment Warranty Expiry</h1>
        <p style={{ color: '#666', marginTop: 4, fontSize: 14 }}>
          Track equipment warranties & expiry alerts across hospital fleet. Expiring within 30 days is flagged for action.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Warranties</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #fde68a', borderRadius: 8, background: '#fffbeb' }}>
          <div style={{ fontSize: 12, color: '#92400e' }}>Expiring &lt;= 30d</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{expiringCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #fecaca', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#991b1b' }}>Expired</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{expiredCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #bbf7d0', borderRadius: 8, background: '#f0fdf4' }}>
          <div style={{ fontSize: 12, color: '#166534' }}>Renewed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{renewedCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd6fe', borderRadius: 8, background: '#f5f3ff' }}>
          <div style={{ fontSize: 12, color: '#5b21b6' }}>Escalated</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{escalatedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiring within 30 days</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Equipment with warranties expiring soon — renewal quote required.
        </p>
        <DataTable rows={expiring} columns={expiringColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Warranties</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Full warranty registry sorted by expiry date. Days left &lt; 0 means expired.
        </p>
        <DataTable rows={warranties} columns={warrantyColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Renewal Actions</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Latest renewal activity — quote requests, renewals, escalations.
        </p>
        <DataTable rows={recentActions} columns={actionsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
