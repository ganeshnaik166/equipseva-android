import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalEquipmentReplacementPlanPage() {
  const sb = await getSupabaseServerClient();

  const [plansRes, dueRes, actionsRes] = await Promise.all([
    sb.rpc('list_replacement_plans_r2047'),
    sb.rpc('due_replacements_r2047'),
    sb.rpc('recent_replacement_actions_r2047'),
  ]);

  const plans: any[] = Array.isArray(plansRes.data) ? plansRes.data : [];
  const due: any[] = Array.isArray(dueRes.data) ? dueRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const totalPlanned = plans.reduce((s, r) => s + Number(r.replacement_cost_rupees || 0), 0);
  const approvedCount = plans.filter((r) => r.status === 'approved').length;
  const replacedCount = plans.filter((r) => r.status === 'replaced').length;

  const planCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email || r.hospital_id?.slice(0, 8) || 'unknown' },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label || '-' },
    { key: 'equipment_age_years', header: 'Age (yrs)', render: (r: any) => String(r.equipment_age_years ?? 0) },
    { key: 'planned_replacement_date', header: 'Planned date', render: (r: any) => r.planned_replacement_date ? String(r.planned_replacement_date).slice(0, 10) : '-' },
    { key: 'replacement_cost_rupees', header: 'Cost (rupees)', render: (r: any) => Number(r.replacement_cost_rupees || 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => r.status || 'planned' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '-' },
  ];

  const dueCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email || r.hospital_id?.slice(0, 8) || 'unknown' },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label || '-' },
    { key: 'planned_replacement_date', header: 'Date', render: (r: any) => r.planned_replacement_date ? String(r.planned_replacement_date).slice(0, 10) : '-' },
    { key: 'days_until', header: 'Days until', render: (r: any) => String(r.days_until ?? 0) },
    { key: 'replacement_cost_rupees', header: 'Cost (rupees)', render: (r: any) => Number(r.replacement_cost_rupees || 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => r.status || 'planned' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label || '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type || '-' },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto', fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Hospital Equipment Replacement Plan</h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Track aging equipment and planned replacement windows per hospital. Log quote, approval, and replacement actions.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', background: '#f6f7f9', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total plans</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{plans.length}</div>
        </div>
        <div style={{ padding: '16px', background: '#f6f7f9', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Approved</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{approvedCount}</div>
        </div>
        <div style={{ padding: '16px', background: '#f6f7f9', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Replaced</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{replacedCount}</div>
        </div>
        <div style={{ padding: '16px', background: '#f6f7f9', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Planned cost (rupees)</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalPlanned.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Due within 180 days</h2>
        <DataTable rows={due} columns={dueCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>All replacement plans</h2>
        <DataTable rows={plans} columns={planCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
