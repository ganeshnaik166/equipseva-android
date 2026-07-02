import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerYearlyEquipmentAgingReplacementBudgetPage() {
  const supabase = await getSupabaseServerClient();

  const [budgetRes, proposalRes, priorityRes, bucketRes, decisionRes, monthlyRes, totalRes] =
    await Promise.all([
      supabase.rpc('list_yearly_budget_r2596'),
      supabase.rpc('list_proposal_log_r2596'),
      supabase.rpc('top_priority_focus_r2596'),
      supabase.rpc('budget_bucket_distribution_r2596'),
      supabase.rpc('decision_kind_summary_r2596'),
      supabase.rpc('monthly_proposal_trend_r2596'),
      supabase.rpc('total_replacement_value_summary_r2596'),
    ]);

  const budgets = (budgetRes.data ?? []) as any[];
  const proposals = (proposalRes.data ?? []) as any[];
  const priorities = (priorityRes.data ?? []) as any[];
  const buckets = (bucketRes.data ?? []) as any[];
  const decisions = (decisionRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];
  const totals = (totalRes.data ?? []) as any[];

  const budgetCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => r.fiscal_year },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_age_years', header: 'Age (yrs)', render: (r: any) => (r.equipment_age_years ?? '-') },
    { key: 'budget_bucket_kind', header: 'Bucket', render: (r: any) => r.budget_bucket_kind },
    { key: 'replacement_priority_kind', header: 'Priority', render: (r: any) => r.replacement_priority_kind },
    { key: 'proposed_replacement_value_rupees', header: 'Value (Rs)', render: (r: any) => (r.proposed_replacement_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const proposalCols: Column<any>[] = [
    { key: 'proposed_at', header: 'When', render: (r: any) => new Date(r.proposed_at).toLocaleString() },
    { key: 'proposal_kind', header: 'Kind', render: (r: any) => r.proposal_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const priorityCols: Column<any>[] = [
    { key: 'replacement_priority_kind', header: 'Priority', render: (r: any) => r.replacement_priority_kind },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => (r.total_value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const bucketCols: Column<any>[] = [
    { key: 'budget_bucket_kind', header: 'Bucket', render: (r: any) => r.budget_bucket_kind },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => (r.total_value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => (r.total_value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'n', header: 'Proposals', render: (r: any) => r.n },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
  ];

  const totalCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => r.fiscal_year },
    { key: 'total_value_rupees', header: 'Total (Rs)', render: (r: any) => (r.total_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    { key: 'avg_age_years', header: 'Avg age (yrs)', render: (r: any) => r.avg_age_years },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer yearly equipment aging & replacement budget</h1>
        <p className="text-sm text-gray-600">
          Hospital & equipment age & budget bucket & replacement priority & proposal & decision.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Yearly replacement budget</h2>
        <DataTable
          rows={budgets}
          columns={budgetCols}
          emptyMessage="No budget rows yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replacement proposal log</h2>
        <DataTable
          rows={proposals}
          columns={proposalCols}
          emptyMessage="No proposals yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Total replacement value by FY</h2>
        <DataTable
          rows={totals}
          columns={totalCols}
          emptyMessage="No totals yet"
          rowKey={(r: any, i: number) => String(r.fiscal_year ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top priority focus</h2>
        <DataTable
          rows={priorities}
          columns={priorityCols}
          emptyMessage="No priority data"
          rowKey={(r: any, i: number) => String(r.replacement_priority_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Budget bucket distribution</h2>
        <DataTable
          rows={buckets}
          columns={bucketCols}
          emptyMessage="No bucket data"
          rowKey={(r: any, i: number) => String(r.budget_bucket_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision kind summary</h2>
        <DataTable
          rows={decisions}
          columns={decisionCols}
          emptyMessage="No decision data"
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly proposal trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No proposals yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
