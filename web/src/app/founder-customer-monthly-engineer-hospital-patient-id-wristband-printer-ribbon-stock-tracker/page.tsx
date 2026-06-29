import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type FleetSummary = {
  total_printers: number;
  operational_count: number;
  degraded_count: number;
  offline_count: number;
  servicing_count: number;
  retired_count: number;
  avg_print_health: number;
  total_monthly_volume: number;
  avg_ribbon_remaining: number;
};

type LowRibbon = {
  hospital_code: string;
  hospital_name: string;
  printer_model: string;
  serial_number: string;
  ribbon_remaining_pct: number;
  monthly_print_volume: number;
  printer_status: string;
  assigned_engineer: string | null;
};

type EngineerWorkload = {
  engineer_name: string;
  printers_assigned: number;
  operational_count: number;
  degraded_count: number;
  total_volume: number;
  avg_health: number;
};

type SpendByHospital = {
  hospital_code: string;
  total_rolls: number;
  total_spend_rupees: number;
  movements_count: number;
  pending_approvals: number;
};

type ReorderRow = {
  hospital_code: string;
  printer_serial: string;
  movement_on: string;
  rolls_count: number;
  ribbon_sku: string;
  total_cost_rupees: number;
  approval_status: string;
  reorder_trigger: string | null;
  remarks: string | null;
};

type ServiceDue = {
  hospital_code: string;
  hospital_name: string;
  printer_model: string;
  serial_number: string;
  last_service_on: string | null;
  next_service_due: string | null;
  days_overdue: number;
  printer_status: string;
};

type SkuBreakdown = {
  ribbon_sku: string;
  total_rolls: number;
  total_spend: number;
  hospitals_using: number;
  avg_unit_cost: number;
};

type MovementStat = {
  movement_type: string;
  movements_count: number;
  total_rolls: number;
  total_value: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    fleetRes,
    lowRibbonRes,
    workloadRes,
    spendRes,
    reorderRes,
    serviceDueRes,
    skuRes,
    movementRes,
  ] = await Promise.all([
    supabase.rpc('r3036_printer_fleet_summary'),
    supabase.rpc('r3036_low_ribbon_printers'),
    supabase.rpc('r3036_engineer_workload'),
    supabase.rpc('r3036_ribbon_spend_by_hospital'),
    supabase.rpc('r3036_reorder_queue'),
    supabase.rpc('r3036_service_due_printers'),
    supabase.rpc('r3036_ribbon_sku_breakdown'),
    supabase.rpc('r3036_movement_type_stats'),
  ]);

  const fleet: FleetSummary | null = (fleetRes.data?.[0] ?? null) as FleetSummary | null;
  const lowRibbon: LowRibbon[] = (lowRibbonRes.data ?? []) as LowRibbon[];
  const workload: EngineerWorkload[] = (workloadRes.data ?? []) as EngineerWorkload[];
  const spend: SpendByHospital[] = (spendRes.data ?? []) as SpendByHospital[];
  const reorder: ReorderRow[] = (reorderRes.data ?? []) as ReorderRow[];
  const serviceDue: ServiceDue[] = (serviceDueRes.data ?? []) as ServiceDue[];
  const sku: SkuBreakdown[] = (skuRes.data ?? []) as SkuBreakdown[];
  const movement: MovementStat[] = (movementRes.data ?? []) as MovementStat[];

  const lowRibbonCols: Column<LowRibbon>[] = [
    { key: 'hospital_code', header: 'Hospital' },
    { key: 'hospital_name', header: 'Name' },
    { key: 'printer_model', header: 'Model' },
    { key: 'serial_number', header: 'Serial' },
    { key: 'ribbon_remaining_pct', header: 'Ribbon %' },
    { key: 'monthly_print_volume', header: 'Monthly Vol' },
    { key: 'printer_status', header: 'Status' },
    { key: 'assigned_engineer', header: 'Engineer' },
  ];

  const workloadCols: Column<EngineerWorkload>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'printers_assigned', header: 'Printers' },
    { key: 'operational_count', header: 'Operational' },
    { key: 'degraded_count', header: 'Degraded' },
    { key: 'total_volume', header: 'Total Volume' },
    { key: 'avg_health', header: 'Avg Health %' },
  ];

  const spendCols: Column<SpendByHospital>[] = [
    { key: 'hospital_code', header: 'Hospital' },
    { key: 'total_rolls', header: 'Rolls' },
    { key: 'total_spend_rupees', header: 'Spend (Rs)' },
    { key: 'movements_count', header: 'Movements' },
    { key: 'pending_approvals', header: 'Pending' },
  ];

  const reorderCols: Column<ReorderRow>[] = [
    { key: 'hospital_code', header: 'Hospital' },
    { key: 'printer_serial', header: 'Serial' },
    { key: 'movement_on', header: 'Date' },
    { key: 'rolls_count', header: 'Rolls' },
    { key: 'ribbon_sku', header: 'SKU' },
    { key: 'total_cost_rupees', header: 'Cost (Rs)' },
    { key: 'approval_status', header: 'Approval' },
    { key: 'reorder_trigger', header: 'Trigger' },
    { key: 'remarks', header: 'Remarks' },
  ];

  const serviceDueCols: Column<ServiceDue>[] = [
    { key: 'hospital_code', header: 'Hospital' },
    { key: 'hospital_name', header: 'Name' },
    { key: 'printer_model', header: 'Model' },
    { key: 'serial_number', header: 'Serial' },
    { key: 'last_service_on', header: 'Last Service' },
    { key: 'next_service_due', header: 'Next Due' },
    { key: 'days_overdue', header: 'Days Overdue' },
    { key: 'printer_status', header: 'Status' },
  ];

  const skuCols: Column<SkuBreakdown>[] = [
    { key: 'ribbon_sku', header: 'SKU' },
    { key: 'total_rolls', header: 'Rolls' },
    { key: 'total_spend', header: 'Spend (Rs)' },
    { key: 'hospitals_using', header: 'Hospitals' },
    { key: 'avg_unit_cost', header: 'Avg Cost' },
  ];

  const movementCols: Column<MovementStat>[] = [
    { key: 'movement_type', header: 'Type' },
    { key: 'movements_count', header: 'Count' },
    { key: 'total_rolls', header: 'Rolls' },
    { key: 'total_value', header: 'Value (Rs)' },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.5rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Round 3036 — Patient ID Wristband Printer & Ribbon Stock Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '1.5rem' }}>
        Monthly engineer-managed wristband printer fleet across hospital customers; ribbon stock movements, reorder queue & service-due alerts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Fleet Summary</h2>
        {fleet ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '0.75rem' }}>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Total Printers</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{fleet.total_printers}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Operational</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700, color: '#0a7' }}>{fleet.operational_count}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Degraded</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700, color: '#d80' }}>{fleet.degraded_count}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Offline</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700, color: '#c33' }}>{fleet.offline_count}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Servicing</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{fleet.servicing_count}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Retired</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700, color: '#888' }}>{fleet.retired_count}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Avg Health %</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{fleet.avg_print_health}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Total Monthly Vol</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{fleet.total_monthly_volume}</div>
            </div>
            <div style={{ padding: '0.75rem', border: '1px solid #e5e5e5', borderRadius: 8 }}>
              <div style={{ fontSize: '0.75rem', color: '#777' }}>Avg Ribbon %</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{fleet.avg_ribbon_remaining}</div>
            </div>
          </div>
        ) : (
          <p style={{ color: '#888' }}>No summary available.</p>
        )}
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Low Ribbon Printers (&lt; 30%)
        </h2>
        <DataTable
          rows={lowRibbon}
          columns={lowRibbonCols}
          emptyMessage="No printers with low ribbon."
          rowKey={(r, i) => String(r.serial_number ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Engineer Workload</h2>
        <DataTable
          rows={workload}
          columns={workloadCols}
          emptyMessage="No engineers assigned."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Ribbon Spend by Hospital</h2>
        <DataTable
          rows={spend}
          columns={spendCols}
          emptyMessage="No spend data."
          rowKey={(r, i) => String(r.hospital_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Reorder Queue</h2>
        <DataTable
          rows={reorder}
          columns={reorderCols}
          emptyMessage="No reorders pending."
          rowKey={(r, i) => String(`${r.hospital_code}-${r.movement_on}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Service Due Printers</h2>
        <DataTable
          rows={serviceDue}
          columns={serviceDueCols}
          emptyMessage="No service-due printers."
          rowKey={(r, i) => String(r.serial_number ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Ribbon SKU Breakdown</h2>
        <DataTable
          rows={sku}
          columns={skuCols}
          emptyMessage="No SKU data."
          rowKey={(r, i) => String(r.ribbon_sku ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Movement Type Stats</h2>
        <DataTable
          rows={movement}
          columns={movementCols}
          emptyMessage="No movement data."
          rowKey={(r, i) => String(r.movement_type ?? i)}
        />
      </section>
    </main>
  );
}
