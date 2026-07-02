import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerToolKitInventoryPage() {
  const supabase = await getSupabaseServerClient();

  const [
    inventoryRes,
    auditsRes,
    topCostRes,
    expiredRes,
    missingRes,
    statusRes,
    trendRes,
  ] = await Promise.all([
    supabase.rpc('list_inventory_r2434'),
    supabase.rpc('list_audits_r2434'),
    supabase.rpc('top_replacement_cost_engineers_r2434'),
    supabase.rpc('expired_calibration_focus_r2434'),
    supabase.rpc('missing_breakdown_r2434'),
    supabase.rpc('audit_status_summary_r2434'),
    supabase.rpc('weekly_audit_trend_r2434'),
  ]);

  const inventory = (inventoryRes.data ?? []) as any[];
  const audits = (auditsRes.data ?? []) as any[];
  const topCost = (topCostRes.data ?? []) as any[];
  const expired = (expiredRes.data ?? []) as any[];
  const missing = (missingRes.data ?? []) as any[];
  const statusSummary = (statusRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const fmtDate = (s: string | null) => (s ? new Date(s).toLocaleDateString() : '—');
  const fmtDT = (s: string | null) => (s ? new Date(s).toLocaleString() : '—');
  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '—' : '₹' + Number(n).toLocaleString('en-IN');

  const inventoryCols: Column<any>[] = [
    { key: 'engineer_label', header: 'Engineer', render: (r: any) => r.engineer_label ?? '—' },
    { key: 'tool_name', header: 'Tool', render: (r: any) => r.tool_name },
    { key: 'tool_kind', header: 'Kind', render: (r: any) => r.tool_kind },
    { key: 'serial_no', header: 'Serial', render: (r: any) => r.serial_no ?? '—' },
    { key: 'condition', header: 'Condition', render: (r: any) => r.condition },
    { key: 'last_used_at', header: 'Last used', render: (r: any) => fmtDT(r.last_used_at) },
    { key: 'last_calibrated_at', header: 'Last calibrated', render: (r: any) => fmtDT(r.last_calibrated_at) },
    { key: 'next_calibration_due_at', header: 'Next due', render: (r: any) => fmtDT(r.next_calibration_due_at) },
    { key: 'calibration_authority', header: 'Authority', render: (r: any) => r.calibration_authority ?? '—' },
    { key: 'replacement_cost_rupees', header: 'Replace cost', render: (r: any) => fmtRupees(r.replacement_cost_rupees) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const auditsCols: Column<any>[] = [
    { key: 'engineer_label', header: 'Engineer', render: (r: any) => r.engineer_label ?? '—' },
    { key: 'audit_date', header: 'Audit date', render: (r: any) => fmtDate(r.audit_date) },
    { key: 'total_tools', header: 'Total', render: (r: any) => r.total_tools },
    { key: 'missing_tools', header: 'Missing', render: (r: any) => r.missing_tools },
    { key: 'broken_tools', header: 'Broken', render: (r: any) => r.broken_tools },
    { key: 'expired_calibration', header: 'Expired calib', render: (r: any) => r.expired_calibration },
    { key: 'audit_status', header: 'Status', render: (r: any) => r.audit_status },
    { key: 'corrective_action', header: 'Corrective action', render: (r: any) => r.corrective_action ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDT(r.closed_at) },
    { key: 'closed_by_email', header: 'Closed by', render: (r: any) => r.closed_by_email ?? '—' },
  ];

  const topCostCols: Column<any>[] = [
    { key: 'engineer_label', header: 'Engineer', render: (r: any) => r.engineer_label ?? '—' },
    { key: 'tool_count', header: 'Tools', render: (r: any) => r.tool_count },
    { key: 'total_replacement_cost_rupees', header: 'Total replace cost', render: (r: any) => fmtRupees(r.total_replacement_cost_rupees) },
    { key: 'broken_or_missing', header: 'Broken/missing', render: (r: any) => r.broken_or_missing },
  ];

  const expiredCols: Column<any>[] = [
    { key: 'engineer_label', header: 'Engineer', render: (r: any) => r.engineer_label ?? '—' },
    { key: 'tool_name', header: 'Tool', render: (r: any) => r.tool_name },
    { key: 'tool_kind', header: 'Kind', render: (r: any) => r.tool_kind },
    { key: 'next_calibration_due_at', header: 'Due', render: (r: any) => fmtDT(r.next_calibration_due_at) },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => r.days_overdue },
    { key: 'calibration_authority', header: 'Authority', render: (r: any) => r.calibration_authority ?? '—' },
    { key: 'replacement_cost_rupees', header: 'Replace cost', render: (r: any) => fmtRupees(r.replacement_cost_rupees) },
  ];

  const missingCols: Column<any>[] = [
    { key: 'tool_kind', header: 'Kind', render: (r: any) => r.tool_kind },
    { key: 'total_tools', header: 'Total', render: (r: any) => r.total_tools },
    { key: 'missing_count', header: 'Missing', render: (r: any) => r.missing_count },
    { key: 'broken_count', header: 'Broken', render: (r: any) => r.broken_count },
    { key: 'worn_count', header: 'Worn', render: (r: any) => r.worn_count },
    { key: 'total_replacement_cost_rupees', header: 'At-risk replace cost', render: (r: any) => fmtRupees(r.total_replacement_cost_rupees) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'audit_status', header: 'Status', render: (r: any) => r.audit_status },
    { key: 'audit_count', header: 'Audits', render: (r: any) => r.audit_count },
    { key: 'total_missing', header: 'Missing', render: (r: any) => r.total_missing },
    { key: 'total_broken', header: 'Broken', render: (r: any) => r.total_broken },
    { key: 'total_expired_calibration', header: 'Expired calib', render: (r: any) => r.total_expired_calibration },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'audit_count', header: 'Audits', render: (r: any) => r.audit_count },
    { key: 'closed_count', header: 'Closed', render: (r: any) => r.closed_count },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => r.escalated_count },
    { key: 'total_missing', header: 'Missing', render: (r: any) => r.total_missing },
    { key: 'total_broken', header: 'Broken', render: (r: any) => r.total_broken },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Tool Kit Inventory</h1>
        <p className="text-sm text-gray-600">
          Per-engineer tool kit & condition & calibration status & replacement-cost exposure. Round r2434.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tool inventory</h2>
        <DataTable
          rows={inventory}
          columns={inventoryCols}
          emptyMessage="No tools in inventory yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tool kit audits</h2>
        <DataTable
          rows={audits}
          columns={auditsCols}
          emptyMessage="No audits recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top replacement-cost engineers</h2>
        <DataTable
          rows={topCost}
          columns={topCostCols}
          emptyMessage="No engineers with tools yet."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Expired calibration focus</h2>
        <DataTable
          rows={expired}
          columns={expiredCols}
          emptyMessage="No expired calibrations — all current."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Missing/broken breakdown by kind</h2>
        <DataTable
          rows={missing}
          columns={missingCols}
          emptyMessage="No tools to break down."
          rowKey={(r: any, i: number) => String(r.tool_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit status summary</h2>
        <DataTable
          rows={statusSummary}
          columns={statusCols}
          emptyMessage="No audits yet."
          rowKey={(r: any, i: number) => String(r.audit_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly audit trend (90 days)</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No audit activity in the last 90 days."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>
    </div>
  );
}
