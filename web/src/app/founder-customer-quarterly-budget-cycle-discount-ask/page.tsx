import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerQuarterlyBudgetCycleDiscountAskPage() {
  const supabase = await getSupabaseServerClient();

  const [asksRes, logRes, topArrRes, tighteningRes, decisionRes, trendRes, approvalRes] = await Promise.all([
    supabase.rpc('list_asks_r2556'),
    supabase.rpc('list_decision_log_r2556'),
    supabase.rpc('top_arr_impact_focus_r2556'),
    supabase.rpc('budget_tightening_breakdown_r2556'),
    supabase.rpc('decision_kind_summary_r2556'),
    supabase.rpc('quarterly_ask_trend_r2556'),
    supabase.rpc('founder_approval_pipeline_r2556'),
  ]);

  const asks = (asksRes.data ?? []) as any[];
  const log = (logRes.data ?? []) as any[];
  const topArr = (topArrRes.data ?? []) as any[];
  const tightening = (tighteningRes.data ?? []) as any[];
  const decision = (decisionRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const approval = (approvalRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

  const asksCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'budget_tightening_kind', header: 'Tightening', render: (r: any) => r.budget_tightening_kind ?? '-' },
    { key: 'discount_asked_pct', header: 'Asked %', render: (r: any) => (r.discount_asked_pct ?? 0) + '%' },
    { key: 'discount_given_pct', header: 'Given %', render: (r: any) => (r.discount_given_pct ?? 0) + '%' },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind ?? '-' },
    { key: 'arr_impact_rupees', header: 'ARR Impact', render: (r: any) => fmtRupees(r.arr_impact_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const logCols: Column<any>[] = [
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '-' },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind ?? '-' },
    { key: 'founder_approval_required', header: 'Approval Req?', render: (r: any) => r.founder_approval_required ? 'yes' : 'no' },
    { key: 'founder_approved', header: 'Approved?', render: (r: any) => r.founder_approved ? 'yes' : 'no' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'summary_md', header: 'Summary', render: (r: any) => r.summary_md ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topArrCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'budget_tightening_kind', header: 'Tightening', render: (r: any) => r.budget_tightening_kind ?? '-' },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind ?? '-' },
    { key: 'arr_impact_rupees', header: 'ARR Impact', render: (r: any) => fmtRupees(r.arr_impact_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const tighteningCols: Column<any>[] = [
    { key: 'budget_tightening_kind', header: 'Tightening Kind', render: (r: any) => r.budget_tightening_kind ?? '-' },
    { key: 'ask_count', header: 'Asks', render: (r: any) => r.ask_count ?? 0 },
    { key: 'avg_discount_asked_pct', header: 'Avg Asked %', render: (r: any) => (r.avg_discount_asked_pct ?? 0) + '%' },
    { key: 'avg_discount_given_pct', header: 'Avg Given %', render: (r: any) => (r.avg_discount_given_pct ?? 0) + '%' },
    { key: 'total_arr_impact_rupees', header: 'Total ARR Impact', render: (r: any) => fmtRupees(r.total_arr_impact_rupees) },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision_kind', header: 'Decision Kind', render: (r: any) => r.decision_kind ?? '-' },
    { key: 'ask_count', header: 'Asks', render: (r: any) => r.ask_count ?? 0 },
    { key: 'total_arr_impact_rupees', header: 'Total ARR Impact', render: (r: any) => fmtRupees(r.total_arr_impact_rupees) },
    { key: 'avg_discount_given_pct', header: 'Avg Given %', render: (r: any) => (r.avg_discount_given_pct ?? 0) + '%' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'ask_count', header: 'Asks', render: (r: any) => r.ask_count ?? 0 },
    { key: 'avg_discount_asked_pct', header: 'Avg Asked %', render: (r: any) => (r.avg_discount_asked_pct ?? 0) + '%' },
    { key: 'avg_discount_given_pct', header: 'Avg Given %', render: (r: any) => (r.avg_discount_given_pct ?? 0) + '%' },
    { key: 'total_arr_impact_rupees', header: 'Total ARR Impact', render: (r: any) => fmtRupees(r.total_arr_impact_rupees) },
  ];

  const approvalCols: Column<any>[] = [
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '-' },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind ?? '-' },
    { key: 'founder_approval_required', header: 'Approval Req?', render: (r: any) => r.founder_approval_required ? 'yes' : 'no' },
    { key: 'founder_approved', header: 'Approved?', render: (r: any) => r.founder_approved ? 'yes' : 'no' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'summary_md', header: 'Summary', render: (r: any) => r.summary_md ?? '-' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Quarterly Budget-Cycle Discount Asks</h1>
        <p className="text-sm text-gray-600">
          Hospital > quarter > budget tightening > discount ask > decision > ARR impact.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-lg font-semibold">All Asks</h2>
        <DataTable
          rows={asks}
          columns={asksCols}
          emptyMessage="No quarterly asks logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Top ARR-Impact Focus</h2>
        <DataTable
          rows={topArr}
          columns={topArrCols}
          emptyMessage="No high-ARR asks."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Budget Tightening Breakdown</h2>
        <DataTable
          rows={tightening}
          columns={tighteningCols}
          emptyMessage="No tightening data."
          rowKey={(r: any, i: number) => String(r.budget_tightening_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Decision Kind Summary</h2>
        <DataTable
          rows={decision}
          columns={decisionCols}
          emptyMessage="No decisions."
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Quarterly Ask Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend yet."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Founder Approval Pipeline</h2>
        <DataTable
          rows={approval}
          columns={approvalCols}
          emptyMessage="No approval items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Decision Log</h2>
        <DataTable
          rows={log}
          columns={logCols}
          emptyMessage="No decision log entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
