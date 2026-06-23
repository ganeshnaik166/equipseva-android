import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerEquipmentAcceptanceHandoverRunbookPage() {
  const supabase = await getSupabaseServerClient();

  const [runs, checklist, overdue, funnel, trend, kinds, owners] = await Promise.all([
    supabase.rpc('list_handover_runs_r2508'),
    supabase.rpc('list_checklist_r2508'),
    supabase.rpc('top_overdue_handovers_r2508'),
    supabase.rpc('status_funnel_r2508'),
    supabase.rpc('monthly_revenue_release_trend_r2508'),
    supabase.rpc('equipment_kind_summary_r2508'),
    supabase.rpc('owner_load_r2508'),
  ]);

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');
  const fmtDT = (v: any) => (v ? new Date(v).toLocaleString() : '-');
  const fmtRs = (v: any) => Number(v ?? 0).toLocaleString();

  const runCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model },
    { key: 'delivery_at', header: 'Delivery', render: (r: any) => fmtDate(r.delivery_at) },
    { key: 'installation_at', header: 'Installed', render: (r: any) => fmtDate(r.installation_at) },
    { key: 'uat_started_at', header: 'UAT Start', render: (r: any) => fmtDate(r.uat_started_at) },
    { key: 'uat_completed_at', header: 'UAT Done', render: (r: any) => fmtDate(r.uat_completed_at) },
    { key: 'signoff_at', header: 'Signoff', render: (r: any) => fmtDate(r.signoff_at) },
    { key: 'signoff_owner_email', header: 'Owner', render: (r: any) => r.signoff_owner_email ?? '-' },
    { key: 'revenue_release_at', header: 'Revenue Released', render: (r: any) => fmtDate(r.revenue_release_at) },
    { key: 'revenue_amount_rupees', header: 'Revenue (Rs)', render: (r: any) => fmtRs(r.revenue_amount_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const checklistCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'checklist_item', header: 'Item', render: (r: any) => r.checklist_item },
    { key: 'completed', header: 'Done?', render: (r: any) => (r.completed ? 'yes' : 'no') },
    { key: 'completed_at', header: 'Done At', render: (r: any) => fmtDT(r.completed_at) },
    { key: 'completed_by_email', header: 'By', render: (r: any) => r.completed_by_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'delivery_at', header: 'Delivery', render: (r: any) => fmtDate(r.delivery_at) },
    { key: 'days_since_delivery', header: 'Days Since Delivery', render: (r: any) => String(r.days_since_delivery ?? 0) },
    { key: 'revenue_amount_rupees', header: 'Revenue (Rs)', render: (r: any) => fmtRs(r.revenue_amount_rupees) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'run_count', header: 'Runs', render: (r: any) => String(r.run_count) },
    { key: 'revenue_sum_rupees', header: 'Revenue (Rs)', render: (r: any) => fmtRs(r.revenue_sum_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'signed_off_count', header: 'Signed Off', render: (r: any) => String(r.signed_off_count) },
    { key: 'revenue_released_rupees', header: 'Revenue Released (Rs)', render: (r: any) => fmtRs(r.revenue_released_rupees) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model },
    { key: 'run_count', header: 'Runs', render: (r: any) => String(r.run_count) },
    { key: 'signed_off_count', header: 'Signed Off', render: (r: any) => String(r.signed_off_count) },
    { key: 'avg_days_delivery_to_signoff', header: 'Avg Days Delivery -> Signoff', render: (r: any) => r.avg_days_delivery_to_signoff != null ? Number(r.avg_days_delivery_to_signoff).toFixed(2) : '-' },
    { key: 'revenue_sum_rupees', header: 'Revenue (Rs)', render: (r: any) => fmtRs(r.revenue_sum_rupees) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'signoff_owner_email', header: 'Signoff Owner', render: (r: any) => r.signoff_owner_email },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
    { key: 'signed_off_count', header: 'Signed Off', render: (r: any) => String(r.signed_off_count) },
    { key: 'pending_revenue_rupees', header: 'Pending Revenue (Rs)', render: (r: any) => fmtRs(r.pending_revenue_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Equipment Acceptance & Handover Runbook</h1>
        <p className="text-sm text-gray-600">Equipment > delivery > installation > UAT > signoff > revenue release — runbook view.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Overdue Handovers</h2>
        <DataTable
          rows={overdue.data ?? []}
          columns={overdueCols}
          emptyMessage="No overdue handovers."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={owners.data ?? []}
          columns={ownerCols}
          emptyMessage="No signoff owners assigned."
          rowKey={(r: any, i: number) => String(r.signoff_owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={funnel.data ?? []}
          columns={funnelCols}
          emptyMessage="No handover runs."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Revenue Release Trend</h2>
        <DataTable
          rows={trend.data ?? []}
          columns={trendCols}
          emptyMessage="No revenue releases recorded."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Equipment Kind Summary</h2>
        <DataTable
          rows={kinds.data ?? []}
          columns={kindCols}
          emptyMessage="No equipment data."
          rowKey={(r: any, i: number) => String(r.equipment_model ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Handover Runs</h2>
        <DataTable
          rows={runs.data ?? []}
          columns={runCols}
          emptyMessage="No handover runs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Acceptance Signoff Checklist</h2>
        <DataTable
          rows={checklist.data ?? []}
          columns={checklistCols}
          emptyMessage="No checklist items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
