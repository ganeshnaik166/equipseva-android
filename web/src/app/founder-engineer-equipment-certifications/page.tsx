import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const certsRes = await sb.rpc('list_certifications_r2124');
  const expiringRes = await sb.rpc('expiring_soon_r2124');
  const actionsRes = await sb.rpc('recent_actions_r2124');

  const certs: any[] = Array.isArray(certsRes.data) ? certsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const certCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'certification_label', header: 'Certification', render: (r: any) => String(r.certification_label ?? '') },
    { key: 'certifying_body', header: 'Body', render: (r: any) => String(r.certifying_body ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'certified_at', header: 'Certified', render: (r: any) => r.certified_at ? new Date(r.certified_at).toLocaleDateString() : '' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : 'none' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'certification_label', header: 'Certification', render: (r: any) => String(r.certification_label ?? '') },
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'certifying_body', header: 'Body', render: (r: any) => String(r.certifying_body ?? '') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'cost_rupees', header: 'Cost (rupees)', render: (r: any) => r.cost_rupees != null ? String(r.cost_rupees) : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600 }}>Engineer Equipment Certifications</h1>
      <p style={{ color: '#666', marginTop: 8 }}>
        Per-equipment certification tracking. Captures who is certified on what, when it expires, and the full action history.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>All Certifications</h2>
        <p style={{ color: '#888', fontSize: 13 }}>Total tracked: {certs.length}</p>
        <DataTable rows={certs} columns={certCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Expiring Soon (next 60 days)</h2>
        <p style={{ color: '#888', fontSize: 13 }}>Renewal queue: {expiring.length}</p>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Recent Action Log</h2>
        <p style={{ color: '#888', fontSize: 13 }}>Recent earned, renewed, expired, revoked, upgraded events.</p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
