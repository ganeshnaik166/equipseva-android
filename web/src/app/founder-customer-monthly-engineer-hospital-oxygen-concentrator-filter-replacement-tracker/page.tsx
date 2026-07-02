import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type DeviceRow = { hospital_name: string; city: string; device_serial: string; device_model: string; filter_status: string; service_tier: string; assigned_engineer: string; next_filter_due_date: string; filter_health_pct: number };
type StatusRow = { filter_status: string; device_count: number; avg_health_pct: number; overdue_pct: number };
type EngRow = { engineer_name: string; replacements: number; success_count: number; success_pct: number; avg_rating: number; total_revenue_rupees: number };
type TypeRow = { filter_type: string; replacement_count: number; avg_parts_cost: number; avg_downtime_min: number };
type OverdueRow = { hospital_name: string; city: string; device_serial: string; next_filter_due_date: string; filter_health_pct: number; assigned_engineer: string; days_overdue: number };
type CityRow = { city: string; total_devices: number; critical_devices: number; amc_active_pct: number; avg_runtime_hours: number };
type ReplRow = { replacement_date: string; hospital_name: string; engineer_name: string; filter_type: string; outcome: string; parts_cost_rupees: number; customer_rating: number | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [devices, status, eng, types, overdue, city, recent] = await Promise.all([
    supabase.rpc('rpc_r3056_device_overview'),
    supabase.rpc('rpc_r3056_status_breakdown'),
    supabase.rpc('rpc_r3056_engineer_performance'),
    supabase.rpc('rpc_r3056_filter_type_mix'),
    supabase.rpc('rpc_r3056_overdue_devices'),
    supabase.rpc('rpc_r3056_city_rollup'),
    supabase.rpc('rpc_r3056_recent_replacements'),
  ]);

  const deviceRows = (devices.data ?? []) as DeviceRow[];
  const statusRows = (status.data ?? []) as StatusRow[];
  const engRows = (eng.data ?? []) as EngRow[];
  const typeRows = (types.data ?? []) as TypeRow[];
  const overdueRows = (overdue.data ?? []) as OverdueRow[];
  const cityRows = (city.data ?? []) as CityRow[];
  const recentRows = (recent.data ?? []) as ReplRow[];

  const deviceCols: Column<DeviceRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Serial', accessor: (r) => r.device_serial },
    { header: 'Model', accessor: (r) => r.device_model },
    { header: 'Status', accessor: (r) => r.filter_status },
    { header: 'Tier', accessor: (r) => r.service_tier },
    { header: 'Engineer', accessor: (r) => r.assigned_engineer },
    { header: 'Next Due', accessor: (r) => r.next_filter_due_date },
    { header: 'Health %', accessor: (r) => r.filter_health_pct },
  ];

  const statusCols: Column<StatusRow>[] = [
    { header: 'Status', accessor: (r) => r.filter_status },
    { header: 'Devices', accessor: (r) => r.device_count },
    { header: 'Avg Health %', accessor: (r) => r.avg_health_pct },
    { header: 'Overdue %', accessor: (r) => r.overdue_pct },
  ];

  const engCols: Column<EngRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Replacements', accessor: (r) => r.replacements },
    { header: 'Success', accessor: (r) => r.success_count },
    { header: 'Success %', accessor: (r) => r.success_pct },
    { header: 'Avg Rating', accessor: (r) => r.avg_rating },
    { header: 'Revenue', accessor: (r) => '₹' + r.total_revenue_rupees.toLocaleString('en-IN') },
  ];

  const typeCols: Column<TypeRow>[] = [
    { header: 'Filter Type', accessor: (r) => r.filter_type },
    { header: 'Count', accessor: (r) => r.replacement_count },
    { header: 'Avg Parts ₹', accessor: (r) => r.avg_parts_cost },
    { header: 'Avg Downtime (min)', accessor: (r) => r.avg_downtime_min },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Serial', accessor: (r) => r.device_serial },
    { header: 'Due Date', accessor: (r) => r.next_filter_due_date },
    { header: 'Health %', accessor: (r) => r.filter_health_pct },
    { header: 'Engineer', accessor: (r) => r.assigned_engineer },
    { header: 'Days Overdue', accessor: (r) => r.days_overdue },
  ];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Total Devices', accessor: (r) => r.total_devices },
    { header: 'Critical', accessor: (r) => r.critical_devices },
    { header: 'AMC Active %', accessor: (r) => r.amc_active_pct },
    { header: 'Avg Runtime (h)', accessor: (r) => r.avg_runtime_hours },
  ];

  const recentCols: Column<ReplRow>[] = [
    { header: 'Date', accessor: (r) => r.replacement_date },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Filter', accessor: (r) => r.filter_type },
    { header: 'Outcome', accessor: (r) => r.outcome },
    { header: 'Parts ₹', accessor: (r) => r.parts_cost_rupees },
    { header: 'Rating', accessor: (r) => r.customer_rating ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Oxygen Concentrator Filter Replacement Tracker</h1>
        <p className="text-sm text-gray-600">Round r3056 — monthly engineer-led filter replacements across hospital oxygen concentrators.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Device Overview</h2>
        <DataTable rows={deviceRows} columns={deviceCols} emptyMessage="No devices tracked." rowKey={(r, i) => String((r as DeviceRow).device_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Breakdown</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No status data." rowKey={(r, i) => String((r as StatusRow).filter_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Performance</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineer data." rowKey={(r, i) => String((r as EngRow).engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Filter Type Mix</h2>
        <DataTable rows={typeRows} columns={typeCols} emptyMessage="No filter type data." rowKey={(r, i) => String((r as TypeRow).filter_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Devices</h2>
        <DataTable rows={overdueRows} columns={overdueCols} emptyMessage="No overdue devices." rowKey={(r, i) => String((r as OverdueRow).device_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Rollup</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No city data." rowKey={(r, i) => String((r as CityRow).city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Replacements</h2>
        <DataTable rows={recentRows} columns={recentCols} emptyMessage="No replacements logged." rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
