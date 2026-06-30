import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { audit_status: string; audits: number; avg_risk: number | null; avg_vibration: number | null };
type TrendRow = { audit_month: string; audits: number; urgent_count: number; avg_risk: number | null; avg_vibration: number | null };
type VendorRow = { refrigerator_make: string; units: number; avg_risk: number | null; urgent_units: number; bearing_wear_units: number };
type HotlistRow = { audit_code: string; hospital_name: string; unit_location: string; refrigerator_make: string; vibration_rms_mm_s: number; failure_risk_score: number; iso_10816_zone: string; audit_status: string };
type QueueRow = { ticket_code: string; action_type: string; priority: string; estimated_cost_rupees: number; resolution_status: string; sla_due_date: string; downtime_risk_hours: number; hospital_acknowledged: boolean };
type EngRow = { engineer_name: string; audits: number; avg_risk: number | null; urgent_finds: number; watch_finds: number; passed_finds: number };
type LocRow = { unit_location: string; audits: number; avg_vibration: number | null; avg_risk: number | null; urgent_count: number };
type IsoRow = { iso_10816_zone: string; audits: number; avg_vibration: number | null; bearing_wear_count: number };
type CostRow = { priority: string; tickets: number; total_cost_rupees: number; total_downtime_hours: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [status, trend, vendor, hotlist, queue, engineer, location, iso, cost] = await Promise.all([
    supabase.rpc('rpc_r3094_status_summary'),
    supabase.rpc('rpc_r3094_monthly_trend'),
    supabase.rpc('rpc_r3094_vendor_breakdown'),
    supabase.rpc('rpc_r3094_risk_hotlist'),
    supabase.rpc('rpc_r3094_corrective_queue'),
    supabase.rpc('rpc_r3094_engineer_scorecard'),
    supabase.rpc('rpc_r3094_location_heatmap'),
    supabase.rpc('rpc_r3094_iso_zone_distribution'),
    supabase.rpc('rpc_r3094_cost_exposure'),
  ]);

  const statusRows = (status.data ?? []) as StatusRow[];
  const trendRows = (trend.data ?? []) as TrendRow[];
  const vendorRows = (vendor.data ?? []) as VendorRow[];
  const hotlistRows = (hotlist.data ?? []) as HotlistRow[];
  const queueRows = (queue.data ?? []) as QueueRow[];
  const engineerRows = (engineer.data ?? []) as EngRow[];
  const locationRows = (location.data ?? []) as LocRow[];
  const isoRows = (iso.data ?? []) as IsoRow[];
  const costRows = (cost.data ?? []) as CostRow[];

  const statusCols: Column<StatusRow>[] = [
    { key: 'audit_status', header: 'Status' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_risk', header: 'Avg Risk' },
    { key: 'avg_vibration', header: 'Avg Vibration mm/s' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_month', header: 'Month' },
    { key: 'audits', header: 'Audits' },
    { key: 'urgent_count', header: 'Urgent' },
    { key: 'avg_risk', header: 'Avg Risk' },
    { key: 'avg_vibration', header: 'Avg Vibration' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'refrigerator_make', header: 'Make' },
    { key: 'units', header: 'Units' },
    { key: 'avg_risk', header: 'Avg Risk' },
    { key: 'urgent_units', header: 'Urgent Units' },
    { key: 'bearing_wear_units', header: 'Bearing Wear' },
  ];

  const hotlistCols: Column<HotlistRow>[] = [
    { key: 'audit_code', header: 'Audit' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'unit_location', header: 'Location' },
    { key: 'refrigerator_make', header: 'Make' },
    { key: 'vibration_rms_mm_s', header: 'RMS mm/s' },
    { key: 'failure_risk_score', header: 'Risk' },
    { key: 'iso_10816_zone', header: 'ISO Zone' },
    { key: 'audit_status', header: 'Status' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'action_type', header: 'Action' },
    { key: 'priority', header: 'Priority' },
    { key: 'estimated_cost_rupees', header: 'Cost (Rs)' },
    { key: 'resolution_status', header: 'Resolution' },
    { key: 'sla_due_date', header: 'SLA Due' },
    { key: 'downtime_risk_hours', header: 'Downtime hrs' },
    { key: 'hospital_acknowledged', header: 'Ack?', render: (r) => (r.hospital_acknowledged ? 'Yes' : 'No') },
  ];

  const engineerCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_risk', header: 'Avg Risk' },
    { key: 'urgent_finds', header: 'Urgent Found' },
    { key: 'watch_finds', header: 'Watch Found' },
    { key: 'passed_finds', header: 'Passed' },
  ];

  const locationCols: Column<LocRow>[] = [
    { key: 'unit_location', header: 'Unit Location' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_vibration', header: 'Avg Vibration' },
    { key: 'avg_risk', header: 'Avg Risk' },
    { key: 'urgent_count', header: 'Urgent' },
  ];

  const isoCols: Column<IsoRow>[] = [
    { key: 'iso_10816_zone', header: 'ISO 10816 Zone' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_vibration', header: 'Avg Vibration' },
    { key: 'bearing_wear_count', header: 'Bearing Wear' },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'priority', header: 'Priority' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'total_cost_rupees', header: 'Total Cost (Rs)' },
    { key: 'total_downtime_hours', header: 'Downtime hrs' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Pharmacy Cold-Chain Compressor Vibration Audit</h1>
        <p className="text-sm text-gray-600 mt-1">
          Round r3094 &mdash; monthly engineer compressor vibration audits for pharmacy &amp; blood-bank refrigerators.
          ISO 10816 zones A&ndash;D, bearing wear flag, failure-risk score, corrective-action queue.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status summary</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No audits found"
          rowKey={(r, i) => String(r.audit_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r, i) => String(r.audit_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor breakdown</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor data"
          rowKey={(r, i) => String(r.refrigerator_make ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Risk hotlist (score &gt;= 30)</h2>
        <DataTable
          rows={hotlistRows}
          columns={hotlistCols}
          emptyMessage="No high-risk audits"
          rowKey={(r, i) => String(r.audit_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Corrective action queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="Queue empty"
          rowKey={(r, i) => String(r.ticket_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer data"
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Unit-location heatmap</h2>
        <DataTable
          rows={locationRows}
          columns={locationCols}
          emptyMessage="No location data"
          rowKey={(r, i) => String(r.unit_location ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">ISO 10816 zone distribution</h2>
        <DataTable
          rows={isoRows}
          columns={isoCols}
          emptyMessage="No ISO data"
          rowKey={(r, i) => String(r.iso_10816_zone ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cost &amp; downtime exposure</h2>
        <DataTable
          rows={costRows}
          columns={costCols}
          emptyMessage="No cost data"
          rowKey={(r, i) => String(r.priority ?? i)}
        />
      </section>
    </main>
  );
}
