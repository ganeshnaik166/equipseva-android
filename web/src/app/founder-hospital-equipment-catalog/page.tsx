import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type EquipmentRow = {
  id: string;
  manufacturer_name: string | null;
  equipment_model: string | null;
  equipment_category: string | null;
  typical_service_minutes: number | null;
  parts_availability: string | null;
  status: string | null;
  captured_at: string | null;
};

type ActionRow = {
  id: string;
  equipment_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
  equipment_model: string | null;
  manufacturer_name: string | null;
};

type CategoryRow = {
  equipment_category: string | null;
  total_count: number | null;
  active_count: number | null;
  discontinued_count: number | null;
  avg_service_minutes: number | null;
};

type RecentRow = {
  id: string;
  equipment_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  equipment_model: string | null;
};

export default async function FounderHospitalEquipmentCatalogPage() {
  const sb = await getSupabaseServerClient();

  const [equipmentRes, actionsRes, categoryRes, recentRes] = await Promise.all([
    sb.rpc('list_equipment_r2063'),
    sb.rpc('list_actions_r2063'),
    sb.rpc('by_category_r2063'),
    sb.rpc('recent_actions_r2063'),
  ]);

  const equipment: EquipmentRow[] = (equipmentRes.data as EquipmentRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];

  const equipmentCols: Column<EquipmentRow>[] = [
    { key: 'manufacturer_name', header: 'Manufacturer', render: (r: any) => r.manufacturer_name ?? '—' },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'typical_service_minutes', header: 'Service Min', render: (r: any) => String(r.typical_service_minutes ?? 0) },
    { key: 'parts_availability', header: 'Parts', render: (r: any) => r.parts_availability ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '—' },
  ];

  const actionsCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'manufacturer_name', header: 'Manufacturer', render: (r: any) => r.manufacturer_name ?? '—' },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'discontinued_count', header: 'Discontinued', render: (r: any) => String(r.discontinued_count ?? 0) },
    { key: 'avg_service_minutes', header: 'Avg Service Min', render: (r: any) => String(r.avg_service_minutes ?? 0) },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
  ];

  const totalEquipment = equipment.length;
  const activeEquipment = equipment.filter((e) => e.status === 'active').length;
  const scarcePartsCount = equipment.filter((e) => e.parts_availability === 'scarce').length;
  const recentActionCount = recent.length;

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Hospital Equipment Catalog</h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Master catalog of equipment we service. Track manufacturers, models, service times, and parts availability.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '32px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase' }}>Total Equipment</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{totalEquipment}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase' }}>Active Models</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{activeEquipment}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase' }}>Scarce Parts</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{scarcePartsCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase' }}>Recent Actions</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{recentActionCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Equipment Catalog</h2>
        <DataTable
          rows={equipment}
          columns={equipmentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Category Breakdown</h2>
        <DataTable
          rows={categories}
          columns={categoryCols}
          rowKey={(r: any, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent Actions (30 days)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Full Action Log</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
