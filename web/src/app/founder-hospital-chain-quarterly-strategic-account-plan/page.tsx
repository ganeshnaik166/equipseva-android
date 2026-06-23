import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainQuarterlyStrategicAccountPlanPage() {
  const supabase = await getSupabaseServerClient();

  const [plans, initiatives, topRevenue, execSummary, statusFunnel, qbrRate, trend] = await Promise.all([
    supabase.rpc('list_account_plans_r2603'),
    supabase.rpc('list_initiative_progress_r2603'),
    supabase.rpc('top_revenue_target_r2603'),
    supabase.rpc('execution_score_summary_r2603'),
    supabase.rpc('status_funnel_r2603'),
    supabase.rpc('qbr_completion_rate_r2603'),
    supabase.rpc('quarterly_plan_trend_r2603'),
  ]);

  const plansRows = (plans.data as any[]) ?? [];
  const initiativeRows = (initiatives.data as any[]) ?? [];
  const topRevenueRows = (topRevenue.data as any[]) ?? [];
  const execRows = (execSummary.data as any[]) ?? [];
  const statusRows = (statusFunnel.data as any[]) ?? [];
  const qbrRows = (qbrRate.data as any[]) ?? [];
  const trendRows = (trend.data as any[]) ?? [];

  const fmtRupees = (v: number | null | undefined) =>
    v == null ? '-' : '₹' + Number(v).toLocaleString('en-IN');
  const fmtDate = (v: string | null | undefined) =>
    v ? new Date(v).toLocaleDateString('en-IN') : '-';

  const planCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'revenue_target_rupees', header: 'Target', render: (r: any) => fmtRupees(r.revenue_target_rupees) },
    { key: 'execution_scorecard_pct', header: 'Score %', render: (r: any) => `${r.execution_scorecard_pct}%` },
    { key: 'qbr_held', header: 'QBR', render: (r: any) => (r.qbr_held ? 'Held' : 'Pending') },
    { key: 'qbr_at', header: 'QBR at', render: (r: any) => fmtDate(r.qbr_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const initiativeCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'initiative_label', header: 'Initiative', render: (r: any) => r.initiative_label },
    { key: 'target_pct', header: 'Target %', render: (r: any) => `${r.target_pct}%` },
    { key: 'actual_pct', header: 'Actual %', render: (r: any) => `${r.actual_pct}%` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topRevenueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'plans_count', header: 'Plans', render: (r: any) => r.plans_count },
    { key: 'total_target_rupees', header: 'Total target', render: (r: any) => fmtRupees(r.total_target_rupees) },
  ];

  const execCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'plans_count', header: 'Plans', render: (r: any) => r.plans_count },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => `${r.avg_score}%` },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'plans_count', header: 'Plans', render: (r: any) => r.plans_count },
  ];

  const qbrCols: Column<any>[] = [
    { key: 'total_plans', header: 'Total plans', render: (r: any) => r.total_plans },
    { key: 'qbr_done', header: 'QBR done', render: (r: any) => r.qbr_done },
    { key: 'qbr_rate_pct', header: 'QBR rate', render: (r: any) => `${r.qbr_rate_pct}%` },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'plans_count', header: 'Plans', render: (r: any) => r.plans_count },
    { key: 'total_target_rupees', header: 'Total target', render: (r: any) => fmtRupees(r.total_target_rupees) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => `${r.avg_score}%` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Strategic Account Plan</h1>
        <p className="text-sm text-gray-600">
          Chain > quarter > initiatives > revenue target > execution scorecard > QBR.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Account plans</h2>
        <DataTable
          rows={plansRows}
          columns={planCols}
          emptyMessage="No plans yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Initiative progress</h2>
        <DataTable
          rows={initiativeRows}
          columns={initiativeCols}
          emptyMessage="No initiatives yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top revenue target (chain)</h2>
        <DataTable
          rows={topRevenueRows}
          columns={topRevenueCols}
          emptyMessage="No revenue data."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Execution score summary</h2>
        <DataTable
          rows={execRows}
          columns={execCols}
          emptyMessage="No score data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">QBR completion rate</h2>
        <DataTable
          rows={qbrRows}
          columns={qbrCols}
          emptyMessage="No QBR data."
          rowKey={(_r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly plan trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>
    </div>
  );
}
</parameter>
