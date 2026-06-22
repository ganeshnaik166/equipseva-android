import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [equipmentRes, attentionRes, recentRes] = await Promise.all([
    sb.rpc('list_equipment_r1940'),
    sb.rpc('equipment_needing_attention_r1940'),
    sb.rpc('recent_actions_r1940'),
  ]);

  const equipment: any[] = Array.isArray(equipmentRes.data) ? equipmentRes.data : [];
  const attention: any[] = Array.isArray(attentionRes.data) ? attentionRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalEquipment = equipment.length;
  const flagged = attention.length;
  const decommissioned = equipment.filter((e) => e.status === 'decommissioned').length;
  const avgCondition = totalEquipment > 0
    ? (equipment.reduce((acc, e) => acc + Number(e.condition_score || 0), 0) / totalEquipment).toFixed(1)
    : '0.0';

  const equipmentColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'condition_score', header: 'Condition (1-10)', render: (r: any) => String(r.condition_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_inspected_at', header: 'Last inspected', render: (r: any) => r.last_inspected_at ? new Date(r.last_inspected_at).toLocaleDateString() : 'never' },
    { key: 'issued_at', header: 'Issued', render: (r: any) => r.issued_at ? new Date(r.issued_at).toLocaleDateString() : '' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
  ];

  const attentionColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'condition_score', header: 'Condition', render: (r: any) => String(r.condition_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_inspected_at', header: 'Last inspected', render: (r: any) => r.last_inspected_at ? new Date(r.last_inspected_at).toLocaleDateString() : 'never' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'cost_rupees', header: 'Cost (rupees)', render: (r: any) => Number(r.cost_rupees ?? 0).toLocaleString('en-IN') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Equipment Wear Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track wear, inspection, and action history for engineer-issued kit. Items with condition score 4 or lower, or status needs_repair/needs_replacement, surface for attention.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total equipment</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalEquipment}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Needs attention</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: flagged > 0 ? '#b91c1c' : '#16a34a' }}>{flagged}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Decommissioned</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{decommissioned}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg condition</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgCondition}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Equipment needing attention</h2>
        <DataTable rows={attention} columns={attentionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All equipment</h2>
        <DataTable rows={equipment} columns={equipmentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
