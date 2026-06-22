import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [servicesRes, overdueRes, actionsRes] = await Promise.all([
    sb.rpc('list_services_r2075', { p_limit: 200 }),
    sb.rpc('overdue_services_r2075', { p_limit: 200 }),
    sb.rpc('recent_actions_r2075', { p_limit: 100 }),
  ]);

  const services = (servicesRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];

  const serviceCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'service_due_date', header: 'Due Date', render: (r: any) => String(r.service_due_date ?? '') },
    { key: 'service_interval_days', header: 'Interval (days)', render: (r: any) => String(r.service_interval_days ?? '') },
    { key: 'last_service_date', header: 'Last Service', render: (r: any) => String(r.last_service_date ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 16) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'service_due_date', header: 'Was Due', render: (r: any) => String(r.service_due_date ?? '') },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => String(r.taken_at ?? '').slice(0, 16) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'service_id', header: 'Service', render: (r: any) => String(r.service_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Equipment Service Calendar</h1>
        <p className="text-sm text-gray-600 mt-1">
          Scheduled equipment services across hospitals. Tracks upcoming, overdue, completed, cancelled, and postponed jobs.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Scheduled Services</h2>
        <p className="text-xs text-gray-500 mb-2">Total: {services.length}</p>
        <DataTable rows={services} columns={serviceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Services</h2>
        <p className="text-xs text-gray-500 mb-2">Items past due date and not yet completed or cancelled. Total: {overdue.length}</p>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Calendar Actions</h2>
        <p className="text-xs text-gray-500 mb-2">Action log entries across all calendar items. Total: {actions.length}</p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
