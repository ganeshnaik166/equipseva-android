import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [losses, vendors, causes, kpi, recoveries] = await Promise.all([
    sb.rpc('r2227_list_losses', { p_status: null }),
    sb.rpc('r2227_vendor_leaderboard'),
    sb.rpc('r2227_root_cause_breakdown'),
    sb.rpc('r2227_kpi_summary'),
    sb.rpc('r2227_list_recoveries', { p_loss_id: null }),
  ]);

  const lossRows: any[] = losses.data ?? [];
  const vendorRows: any[] = vendors.data ?? [];
  const causeRows: any[] = causes.data ?? [];
  const kpiRow: any = (kpi.data ?? [])[0] ?? {};
  const recoveryRows: any[] = recoveries.data ?? [];

  const lossCols: Column<any>[] = [
    { key: 'claim_ref', header: 'Claim', render: (r: any) => String(r.claim_ref ?? '') },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '') },
    { key: 'parts_cost_rupees', header: 'Parts Rs', render: (r: any) => String(r.parts_cost_rupees ?? 0) },
    { key: 'labour_cost_rupees', header: 'Labour Rs', render: (r: any) => String(r.labour_cost_rupees ?? 0) },
    { key: 'service_revenue_rupees', header: 'Service Rev Rs', render: (r: any) => String(r.service_revenue_rupees ?? 0) },
    { key: 'loss_rupees', header: 'Loss Rs', render: (r: any) => String(r.loss_rupees ?? 0) },
    { key: 'root_cause', header: 'Root Cause', render: (r: any) => String(r.root_cause ?? '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const vendorCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '') },
    { key: 'claim_count', header: 'Claims', render: (r: any) => String(r.claim_count ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'total_loss_rupees', header: 'Total Loss Rs', render: (r: any) => String(r.total_loss_rupees ?? 0) },
    { key: 'total_recovered_rupees', header: 'Recovered Rs', render: (r: any) => String(r.total_recovered_rupees ?? 0) },
    { key: 'net_loss_rupees', header: 'Net Loss Rs', render: (r: any) => String(r.net_loss_rupees ?? 0) },
  ];

  const causeCols: Column<any>[] = [
    { key: 'root_cause', header: 'Root Cause', render: (r: any) => String(r.root_cause ?? '') },
    { key: 'claim_count', header: 'Claims', render: (r: any) => String(r.claim_count ?? 0) },
    { key: 'total_loss_rupees', header: 'Total Loss Rs', render: (r: any) => String(r.total_loss_rupees ?? 0) },
    { key: 'avg_loss_rupees', header: 'Avg Loss Rs', render: (r: any) => String(Number(r.avg_loss_rupees ?? 0).toFixed(2)) },
  ];

  const recoveryCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r: any) => String(r.vendor_name ?? '') },
    { key: 'recovery_action', header: 'Action', render: (r: any) => String(r.recovery_action ?? '') },
    { key: 'amount_claimed_rupees', header: 'Claimed Rs', render: (r: any) => String(r.amount_claimed_rupees ?? 0) },
    { key: 'amount_recovered_rupees', header: 'Recovered Rs', render: (r: any) => String(r.amount_recovered_rupees ?? 0) },
    { key: 'recovery_status', header: 'Status', render: (r: any) => String(r.recovery_status ?? '') },
    { key: 'contact_email', header: 'Contact', render: (r: any) => String(r.contact_email ?? '') },
    { key: 'logged_at', header: 'Logged', render: (r: any) => String(r.logged_at ?? '').slice(0, 19) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Warranty Claim Loss Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Warranty claims where parts cost &gt; service revenue. Track root cause &amp; vendor recovery.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="border rounded p-3 bg-white">
          <div className="text-xs text-gray-500">Total Claims</div>
          <div className="text-xl font-semibold">{String(kpiRow.total_claims ?? 0)}</div>
        </div>
        <div className="border rounded p-3 bg-white">
          <div className="text-xs text-gray-500">Open Claims</div>
          <div className="text-xl font-semibold">{String(kpiRow.open_claims ?? 0)}</div>
        </div>
        <div className="border rounded p-3 bg-white">
          <div className="text-xs text-gray-500">Total Loss Rs</div>
          <div className="text-xl font-semibold">{String(kpiRow.total_loss_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-3 bg-white">
          <div className="text-xs text-gray-500">Recovered Rs</div>
          <div className="text-xl font-semibold">{String(kpiRow.total_recovered_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-3 bg-white">
          <div className="text-xs text-gray-500">Net Outstanding Rs</div>
          <div className="text-xl font-semibold">{String(kpiRow.net_outstanding_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-3 bg-white">
          <div className="text-xs text-gray-500">Critical Open</div>
          <div className="text-xl font-semibold">{String(kpiRow.critical_open ?? 0)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Loss Claims (parts &gt; revenue)</h2>
        <DataTable columns={lossCols} rows={lossRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor Leaderboard</h2>
        <DataTable columns={vendorCols} rows={vendorRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Root Cause Breakdown</h2>
        <DataTable columns={causeCols} rows={causeRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor Recovery Log</h2>
        <DataTable columns={recoveryCols} rows={recoveryRows} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
