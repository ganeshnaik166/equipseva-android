import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FleetOverview = {
  total_vehicles: number;
  active_vehicles: number;
  in_service_vehicles: number;
  accident_vehicles: number;
  total_fleet_km: number;
  vehicles_due_30d: number;
};

type CostSummary = {
  total_logs: number;
  total_parts_cost: number;
  total_labour_cost: number;
  total_cost: number;
  avg_cost_per_service: number;
  insurance_claims_cost: number;
  company_paid_cost: number;
};

type VehicleRow = {
  id: string;
  engineer_name: string;
  engineer_code: string;
  vehicle_reg_no: string;
  vehicle_type: string;
  make_model: string;
  current_km: number;
  next_service_due_km: number;
  km_to_next: number;
  next_service_due_date: string;
  days_to_next: number;
  status: string;
  region: string;
};

type LogRow = {
  id: string;
  service_date: string;
  engineer_name: string;
  vehicle_reg_no: string;
  service_type: string;
  km_reading: number;
  repair_description: string;
  total_cost_rupees: number;
  vendor_name: string;
  downtime_hours: number;
  approval_status: string;
  paid_by: string;
};

type CostByType = {
  service_type: string;
  log_count: number;
  total_cost: number;
  avg_cost: number;
  total_downtime_hours: number;
};

type TopSpend = {
  vehicle_reg_no: string;
  engineer_name: string;
  total_logs: number;
  total_spend: number;
  total_downtime_hours: number;
};

type Pending = {
  id: string;
  service_date: string;
  engineer_name: string;
  vehicle_reg_no: string;
  service_type: string;
  repair_description: string;
  total_cost_rupees: number;
  vendor_name: string;
};

type Compliance = {
  vehicle_reg_no: string;
  engineer_name: string;
  insurance_expiry: string;
  fitness_expiry: string;
  days_to_insurance: number;
  days_to_fitness: number;
  alert_level: string;
};

function fmtINR(n: number | null | undefined): string {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function KpiCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 700, marginTop: 6 }}>{value}</div>
      {hint ? <div style={{ fontSize: 12, color: '#9ca3af', marginTop: 4 }}>{hint}</div> : null}
    </div>
  );
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, costRes, vehiclesRes, logsRes, byTypeRes, topRes, pendingRes, complianceRes] = await Promise.all([
    supabase.rpc('r2710_fleet_overview'),
    supabase.rpc('r2710_monthly_cost_summary'),
    supabase.rpc('r2710_vehicles_list'),
    supabase.rpc('r2710_recent_maintenance_logs'),
    supabase.rpc('r2710_cost_by_service_type'),
    supabase.rpc('r2710_top_spend_vehicles'),
    supabase.rpc('r2710_pending_approvals'),
    supabase.rpc('r2710_compliance_alerts'),
  ]);

  const overview: FleetOverview | null = (overviewRes.data?.[0] as FleetOverview) ?? null;
  const cost: CostSummary | null = (costRes.data?.[0] as CostSummary) ?? null;
  const vehicles: VehicleRow[] = (vehiclesRes.data as VehicleRow[]) ?? [];
  const logs: LogRow[] = (logsRes.data as LogRow[]) ?? [];
  const byType: CostByType[] = (byTypeRes.data as CostByType[]) ?? [];
  const top: TopSpend[] = (topRes.data as TopSpend[]) ?? [];
  const pending: Pending[] = (pendingRes.data as Pending[]) ?? [];
  const compliance: Compliance[] = (complianceRes.data as Compliance[]) ?? [];

  return (
    <main style={{ padding: 24, background: '#f9fafb', minHeight: '100vh' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 800, margin: 0 }}>Engineer Monthly Vehicle Maintenance Log</h1>
        <p style={{ color: '#6b7280', marginTop: 6 }}>
          Round r2710 · engineer × vehicle × km × service × repair × cost × next due
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Fleet Total" value={String(overview?.total_vehicles ?? 0)} hint={`active ${overview?.active_vehicles ?? 0}`} />
        <KpiCard label="In Service" value={String(overview?.in_service_vehicles ?? 0)} hint="currently down" />
        <KpiCard label="Accidents" value={String(overview?.accident_vehicles ?? 0)} hint="active claims" />
        <KpiCard label="Fleet KM" value={(overview?.total_fleet_km ?? 0).toLocaleString('en-IN')} hint="lifetime odometer" />
        <KpiCard label="Due in 30d" value={String(overview?.vehicles_due_30d ?? 0)} hint="next service" />
        <KpiCard label="Monthly Spend" value={fmtINR(cost?.total_cost)} hint={`${cost?.total_logs ?? 0} logs`} />
        <KpiCard label="Parts Cost" value={fmtINR(cost?.total_parts_cost)} hint="parts only" />
        <KpiCard label="Avg per Service" value={fmtINR(cost?.avg_cost_per_service)} hint="all logs" />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Vehicle Fleet (next service due)</h2>
        <DataTable
          rows={vehicles}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: VehicleRow) => <span>{r.engineer_name} <small style={{ color: '#9ca3af' }}>{r.engineer_code}</small></span> },
            { key: 'vehicle_reg_no', header: 'Reg No', render: (r: VehicleRow) => <strong>{r.vehicle_reg_no}</strong> },
            { key: 'vehicle_type', header: 'Type', render: (r: VehicleRow) => <span>{r.vehicle_type}</span> },
            { key: 'make_model', header: 'Make / Model', render: (r: VehicleRow) => <span>{r.make_model}</span> },
            { key: 'current_km', header: 'Current KM', render: (r: VehicleRow) => <span>{r.current_km.toLocaleString('en-IN')}</span> },
            { key: 'km_to_next', header: 'KM to Next', render: (r: VehicleRow) => <span style={{ color: r.km_to_next <= 500 ? '#dc2626' : '#111' }}>{r.km_to_next.toLocaleString('en-IN')}</span> },
            { key: 'next_service_due_date', header: 'Due Date', render: (r: VehicleRow) => <span>{r.next_service_due_date}</span> },
            { key: 'days_to_next', header: 'Days', render: (r: VehicleRow) => <span style={{ color: r.days_to_next <= 14 ? '#dc2626' : '#111' }}>{r.days_to_next}</span> },
            { key: 'status', header: 'Status', render: (r: VehicleRow) => <span>{r.status}</span> },
            { key: 'region', header: 'Region', render: (r: VehicleRow) => <span>{r.region}</span> },
          ]}
          emptyMessage="No vehicles"
          rowKey={(r: VehicleRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Recent Maintenance Logs</h2>
        <DataTable
          rows={logs}
          columns={[
            { key: 'service_date', header: 'Date', render: (r: LogRow) => <span>{r.service_date}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: LogRow) => <span>{r.engineer_name}</span> },
            { key: 'vehicle_reg_no', header: 'Vehicle', render: (r: LogRow) => <strong>{r.vehicle_reg_no}</strong> },
            { key: 'service_type', header: 'Type', render: (r: LogRow) => <span>{r.service_type}</span> },
            { key: 'km_reading', header: 'KM', render: (r: LogRow) => <span>{r.km_reading.toLocaleString('en-IN')}</span> },
            { key: 'repair_description', header: 'Repair', render: (r: LogRow) => <span>{r.repair_description}</span> },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: LogRow) => <span>{fmtINR(r.total_cost_rupees)}</span> },
            { key: 'vendor_name', header: 'Vendor', render: (r: LogRow) => <span>{r.vendor_name}</span> },
            { key: 'downtime_hours', header: 'Downtime hrs', render: (r: LogRow) => <span>{r.downtime_hours}</span> },
            { key: 'approval_status', header: 'Approval', render: (r: LogRow) => <span style={{ color: r.approval_status === 'pending' ? '#d97706' : '#059669' }}>{r.approval_status}</span> },
            { key: 'paid_by', header: 'Paid By', render: (r: LogRow) => <span>{r.paid_by}</span> },
          ]}
          emptyMessage="No logs"
          rowKey={(r: LogRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 24 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Cost by Service Type</h2>
          <DataTable
            rows={byType}
            columns={[
              { key: 'service_type', header: 'Type', render: (r: CostByType) => <span>{r.service_type}</span> },
              { key: 'log_count', header: 'Logs', render: (r: CostByType) => <span>{r.log_count}</span> },
              { key: 'total_cost', header: 'Total Spend', render: (r: CostByType) => <strong>{fmtINR(r.total_cost)}</strong> },
              { key: 'avg_cost', header: 'Avg', render: (r: CostByType) => <span>{fmtINR(r.avg_cost)}</span> },
              { key: 'total_downtime_hours', header: 'Downtime hrs', render: (r: CostByType) => <span>{r.total_downtime_hours}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: CostByType, i: number) => String(r.service_type ?? i)}
          />
        </div>

        <div>
          <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Top Spend Vehicles</h2>
          <DataTable
            rows={top}
            columns={[
              { key: 'vehicle_reg_no', header: 'Vehicle', render: (r: TopSpend) => <strong>{r.vehicle_reg_no}</strong> },
              { key: 'engineer_name', header: 'Engineer', render: (r: TopSpend) => <span>{r.engineer_name}</span> },
              { key: 'total_logs', header: 'Logs', render: (r: TopSpend) => <span>{r.total_logs}</span> },
              { key: 'total_spend', header: 'Spend', render: (r: TopSpend) => <strong>{fmtINR(r.total_spend)}</strong> },
              { key: 'total_downtime_hours', header: 'Downtime hrs', render: (r: TopSpend) => <span>{r.total_downtime_hours}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: TopSpend, i: number) => String(r.vehicle_reg_no ?? i)}
          />
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Pending Approvals</h2>
        <DataTable
          rows={pending}
          columns={[
            { key: 'service_date', header: 'Date', render: (r: Pending) => <span>{r.service_date}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: Pending) => <span>{r.engineer_name}</span> },
            { key: 'vehicle_reg_no', header: 'Vehicle', render: (r: Pending) => <strong>{r.vehicle_reg_no}</strong> },
            { key: 'service_type', header: 'Type', render: (r: Pending) => <span>{r.service_type}</span> },
            { key: 'repair_description', header: 'Repair', render: (r: Pending) => <span>{r.repair_description}</span> },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: Pending) => <strong>{fmtINR(r.total_cost_rupees)}</strong> },
            { key: 'vendor_name', header: 'Vendor', render: (r: Pending) => <span>{r.vendor_name}</span> },
          ]}
          emptyMessage="No pending approvals"
          rowKey={(r: Pending, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>Compliance Alerts (Insurance & Fitness)</h2>
        <DataTable
          rows={compliance}
          columns={[
            { key: 'vehicle_reg_no', header: 'Vehicle', render: (r: Compliance) => <strong>{r.vehicle_reg_no}</strong> },
            { key: 'engineer_name', header: 'Engineer', render: (r: Compliance) => <span>{r.engineer_name}</span> },
            { key: 'insurance_expiry', header: 'Insurance Expiry', render: (r: Compliance) => <span>{r.insurance_expiry}</span> },
            { key: 'days_to_insurance', header: 'Days', render: (r: Compliance) => <span style={{ color: r.days_to_insurance <= 30 ? '#dc2626' : '#111' }}>{r.days_to_insurance}</span> },
            { key: 'fitness_expiry', header: 'Fitness Expiry', render: (r: Compliance) => <span>{r.fitness_expiry}</span> },
            { key: 'days_to_fitness', header: 'Days', render: (r: Compliance) => <span style={{ color: r.days_to_fitness <= 30 ? '#dc2626' : '#111' }}>{r.days_to_fitness}</span> },
            { key: 'alert_level', header: 'Alert', render: (r: Compliance) => <span style={{ color: r.alert_level === 'red' ? '#dc2626' : r.alert_level === 'amber' ? '#d97706' : '#059669', fontWeight: 700 }}>{r.alert_level.toUpperCase()}</span> },
          ]}
          emptyMessage="No alerts"
          rowKey={(r: Compliance, i: number) => String(r.vehicle_reg_no ?? i)}
        />
      </section>
    </main>
  );
}
