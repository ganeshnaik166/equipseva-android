import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerUniformPpeIssuanceTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [issuances, audits, dueSoon, suppliers, costTrend, scoreSummary, lostItems] = await Promise.all([
    supabase.rpc('list_issuances_r2462'),
    supabase.rpc('list_audits_r2462'),
    supabase.rpc('top_replacement_due_r2462'),
    supabase.rpc('supplier_breakdown_r2462'),
    supabase.rpc('monthly_cost_trend_r2462'),
    supabase.rpc('compliance_score_summary_r2462'),
    supabase.rpc('lost_items_focus_r2462'),
  ]);

  const issuancesRows: any[] = issuances.data ?? [];
  const auditsRows: any[] = audits.data ?? [];
  const dueSoonRows: any[] = dueSoon.data ?? [];
  const suppliersRows: any[] = suppliers.data ?? [];
  const costTrendRows: any[] = costTrend.data ?? [];
  const scoreSummaryRows: any[] = scoreSummary.data ?? [];
  const lostItemsRows: any[] = lostItems.data ?? [];

  const issuancesCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'item_kind', header: 'Item', render: (r: any) => r.item_kind },
    { key: 'size_label', header: 'Size', render: (r: any) => r.size_label ?? '—' },
    { key: 'replacement_cycle_months', header: 'Cycle (mo)', render: (r: any) => String(r.replacement_cycle_months ?? 0) },
    { key: 'cost_rupees', header: 'Cost (Rs)', render: (r: any) => String(r.cost_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'issued_at', header: 'Issued', render: (r: any) => r.issued_at ? new Date(r.issued_at).toLocaleDateString() : '—' },
    { key: 'next_replacement_due_at', header: 'Next Due', render: (r: any) => r.next_replacement_due_at ? new Date(r.next_replacement_due_at).toLocaleDateString() : '—' },
  ];

  const auditsCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'audit_date', header: 'Audit Date', render: (r: any) => r.audit_date ?? '—' },
    { key: 'total_items', header: 'Total', render: (r: any) => String(r.total_items ?? 0) },
    { key: 'missing_items', header: 'Missing', render: (r: any) => String(r.missing_items ?? 0) },
    { key: 'expired_items', header: 'Expired', render: (r: any) => String(r.expired_items ?? 0) },
    { key: 'compliance_score', header: 'Score', render: (r: any) => String(r.compliance_score ?? 0) },
    { key: 'audit_status', header: 'Status', render: (r: any) => r.audit_status },
    { key: 'closed_at', header: 'Closed', render: (r: any) => r.closed_at ? new Date(r.closed_at).toLocaleDateString() : 'Open' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const dueSoonCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'item_kind', header: 'Item', render: (r: any) => r.item_kind },
    { key: 'size_label', header: 'Size', render: (r: any) => r.size_label ?? '—' },
    { key: 'next_replacement_due_at', header: 'Due At', render: (r: any) => r.next_replacement_due_at ? new Date(r.next_replacement_due_at).toLocaleDateString() : '—' },
    { key: 'days_until_due', header: 'Days', render: (r: any) => String(r.days_until_due ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const suppliersCols: Column<any>[] = [
    { key: 'supplier_name', header: 'Supplier', render: (r: any) => r.supplier_name ?? '—' },
    { key: 'issuance_count', header: 'Issues', render: (r: any) => String(r.issuance_count ?? 0) },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => String(r.total_cost_rupees ?? 0) },
    { key: 'avg_cost_rupees', header: 'Avg Cost', render: (r: any) => r.avg_cost_rupees != null ? String(r.avg_cost_rupees) : '—' },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count ?? 0) },
  ];

  const costTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'issuance_count', header: 'Issues', render: (r: any) => String(r.issuance_count ?? 0) },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => String(r.total_cost_rupees ?? 0) },
    { key: 'avg_cost_rupees', header: 'Avg Cost', render: (r: any) => r.avg_cost_rupees != null ? String(r.avg_cost_rupees) : '—' },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count ?? 0) },
  ];

  const scoreCols: Column<any>[] = [
    { key: 'audit_status', header: 'Status', render: (r: any) => r.audit_status },
    { key: 'audit_count', header: 'Audits', render: (r: any) => String(r.audit_count ?? 0) },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score != null ? String(r.avg_score) : '—' },
    { key: 'avg_missing', header: 'Avg Missing', render: (r: any) => r.avg_missing != null ? String(r.avg_missing) : '—' },
    { key: 'avg_expired', header: 'Avg Expired', render: (r: any) => r.avg_expired != null ? String(r.avg_expired) : '—' },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
  ];

  const lostCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'item_kind', header: 'Item', render: (r: any) => r.item_kind },
    { key: 'size_label', header: 'Size', render: (r: any) => r.size_label ?? '—' },
    { key: 'cost_rupees', header: 'Cost', render: (r: any) => String(r.cost_rupees ?? 0) },
    { key: 'issued_at', header: 'Issued', render: (r: any) => r.issued_at ? new Date(r.issued_at).toLocaleDateString() : '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  return (
    <div className="space-y-8 p-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Uniform & PPE Issuance Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Engineer => PPE item => size => replacement cycle => compliance audit => supplier => cost (r2462)
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Compliance Score Summary</h2>
        <DataTable
          rows={scoreSummaryRows}
          columns={scoreCols}
          emptyMessage="No audits yet"
          rowKey={(r: any, i: number) => String(r.audit_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replacement Due Soon</h2>
        <DataTable
          rows={dueSoonRows}
          columns={dueSoonCols}
          emptyMessage="Nothing due"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lost Items Focus</h2>
        <DataTable
          rows={lostItemsRows}
          columns={lostCols}
          emptyMessage="No lost items"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Supplier Breakdown</h2>
        <DataTable
          rows={suppliersRows}
          columns={suppliersCols}
          emptyMessage="No supplier data"
          rowKey={(r: any, i: number) => String(r.supplier_org_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Cost Trend</h2>
        <DataTable
          rows={costTrendRows}
          columns={costTrendCols}
          emptyMessage="No cost trend yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All PPE Issuances</h2>
        <DataTable
          rows={issuancesRows}
          columns={issuancesCols}
          emptyMessage="No issuances yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Compliance Audits</h2>
        <DataTable
          rows={auditsRows}
          columns={auditsCols}
          emptyMessage="No audits yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
