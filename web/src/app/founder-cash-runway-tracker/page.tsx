import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

export default async function FounderCashRunwayTrackerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [headline, runway, burn, pipeStage, pipeSeg, topPipe, revTraj] = await Promise.all([
    sb.rpc('founder_cash_headline_kpis'),
    sb.rpc('founder_cash_current_runway'),
    sb.rpc('founder_cash_burn_trajectory'),
    sb.rpc('founder_cash_pipeline_by_stage'),
    sb.rpc('founder_cash_pipeline_by_segment'),
    sb.rpc('founder_cash_top_pipeline'),
    sb.rpc('founder_cash_revenue_trajectory'),
  ]);

  const k: any = (headline.data && headline.data[0]) || {};
  const r: any = (runway.data && runway.data[0]) || {};
  const burnRows: any[] = (burn.data as any[]) || [];
  const stageRows: any[] = (pipeStage.data as any[]) || [];
  const segRows: any[] = (pipeSeg.data as any[]) || [];
  const topRows: any[] = (topPipe.data as any[]) || [];
  const revRows: any[] = (revTraj.data as any[]) || [];

  const redline = !!k.redline;

  const burnCols: Column<any>[] = [
    { key: 'month', header: 'Month', render: (row: any) => String(row.snapshot_month ?? '—') },
    { key: 'burn', header: 'Burn', render: (row: any) => formatRupees(Number(row.monthly_burn_rupees ?? 0)) },
    { key: 'rev', header: 'Revenue', render: (row: any) => formatRupees(Number(row.monthly_revenue_rupees ?? 0)) },
    { key: 'net', header: 'Net Burn', render: (row: any) => formatRupees(Number(row.net_burn_rupees ?? 0)) },
    { key: 'cash', header: 'Cash', render: (row: any) => formatRupees(Number(row.cash_on_hand_rupees ?? 0)) },
    { key: 'hc', header: 'Headcount', render: (row: any) => String(row.headcount ?? 0) },
    { key: 'mom', header: 'MoM Burn %', render: (row: any) => row.mom_burn_change_pct == null ? '—' : String(row.mom_burn_change_pct) + '%' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (row: any) => String(row.stage ?? '—') },
    { key: 'entries', header: 'Deals', render: (row: any) => String(row.entries ?? 0) },
    { key: 'arr', header: 'Total ARR', render: (row: any) => formatRupees(Number(row.total_arr_rupees ?? 0)) },
    { key: 'warr', header: 'Weighted ARR', render: (row: any) => formatRupees(Number(row.weighted_arr_rupees ?? 0)) },
    { key: 'prob', header: 'Avg Prob', render: (row: any) => String(row.avg_probability_pct ?? 0) + '%' },
  ];

  const segCols: Column<any>[] = [
    { key: 'segment', header: 'Segment', render: (row: any) => String(row.segment ?? '—') },
    { key: 'entries', header: 'Deals', render: (row: any) => String(row.entries ?? 0) },
    { key: 'arr', header: 'Total ARR', render: (row: any) => formatRupees(Number(row.total_arr_rupees ?? 0)) },
    { key: 'warr', header: 'Weighted ARR', render: (row: any) => formatRupees(Number(row.weighted_arr_rupees ?? 0)) },
  ];

  const topCols: Column<any>[] = [
    { key: 'account', header: 'Account', render: (row: any) => String(row.account_name ?? '—') },
    { key: 'segment', header: 'Segment', render: (row: any) => String(row.segment ?? '—') },
    { key: 'stage', header: 'Stage', render: (row: any) => String(row.stage ?? '—') },
    { key: 'arr', header: 'ARR', render: (row: any) => formatRupees(Number(row.arr_rupees ?? 0)) },
    { key: 'prob', header: 'Prob', render: (row: any) => String(row.probability_pct ?? 0) + '%' },
    { key: 'warr', header: 'Weighted', render: (row: any) => formatRupees(Number(row.weighted_rupees ?? 0)) },
    { key: 'close', header: 'Close', render: (row: any) => String(row.expected_close_month ?? '—') },
  ];

  const revCols: Column<any>[] = [
    { key: 'ym', header: 'Month', render: (row: any) => String(row.ym ?? '—') },
    { key: 'repair', header: 'Repair Revenue', render: (row: any) => formatRupees(Number(row.repair_revenue_rupees ?? 0)) },
    { key: 'amc', header: 'AMC Revenue', render: (row: any) => formatRupees(Number(row.amc_revenue_rupees ?? 0)) },
    { key: 'total', header: 'Total', render: (row: any) => formatRupees(Number(row.total_revenue_rupees ?? 0)) },
    { key: 'jobs', header: 'Jobs', render: (row: any) => String(row.active_jobs ?? 0) },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-neutral-900">Founder Cash-Runway Tracker</h1>
          <p className="text-sm text-neutral-500">Monthly burn, cash on hand, weighted pipeline, revenue trajectory, runway projection.</p>
        </div>
        {redline ? (
          <span className="rounded-full bg-red-100 px-3 py-1 text-sm font-semibold text-red-700">REDLINE: runway under 6 months</span>
        ) : (
          <span className="rounded-full bg-emerald-100 px-3 py-1 text-sm font-semibold text-emerald-700">Healthy</span>
        )}
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Cash on Hand" value={formatRupees(Number(k.cash_on_hand_rupees ?? 0))} />
        <Kpi label="Monthly Burn" value={formatRupees(Number(k.monthly_burn_rupees ?? 0))} />
        <Kpi label="Monthly Revenue" value={formatRupees(Number(k.monthly_revenue_rupees ?? 0))} />
        <Kpi label="Net Burn" value={formatRupees(Number(k.net_burn_rupees ?? 0))} />
        <Kpi label="Runway (months)" value={String(k.runway_months ?? '—')} />
        <Kpi label="Months to Default" value={String(k.months_to_default_risk ?? '—')} />
        <Kpi label="Burn Multiple" value={String(k.burn_multiple ?? '—')} />
        <Kpi label="Redline" value={k.redline ? 'YES' : 'No'} />
        <Kpi label="Weighted Pipeline" value={formatRupees(Number(k.weighted_pipeline_rupees ?? 0))} />
        <Kpi label="Total Pipeline" value={formatRupees(Number(k.total_pipeline_rupees ?? 0))} />
        <Kpi label="Open Deals" value={String(k.open_pipeline_count ?? 0)} />
        <Kpi label="Receivables" value={formatRupees(Number(k.receivables_rupees ?? 0))} />
        <Kpi label="Payables" value={formatRupees(Number(k.payables_rupees ?? 0))} />
        <Kpi label="Headcount" value={String(k.headcount ?? 0)} />
        <Kpi label="T3M Avg Burn" value={formatRupees(Number(k.trailing_3mo_avg_burn ?? 0))} />
        <Kpi label="T3M Avg Revenue" value={formatRupees(Number(k.trailing_3mo_avg_revenue ?? 0))} />
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Burn Trajectory (last 18 months)</h2>
        <DataTable<any> rows={burnRows} columns={burnCols} rowKey={(r: any) => String(r.snapshot_month)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Revenue Trajectory (last 12 months)</h2>
        <DataTable<any> rows={revRows} columns={revCols} rowKey={(r: any) => String(r.ym)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Pipeline by Stage</h2>
        <DataTable<any> rows={stageRows} columns={stageCols} rowKey={(r: any) => String(r.stage)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Pipeline by Segment</h2>
        <DataTable<any> rows={segRows} columns={segCols} rowKey={(r: any) => String(r.segment)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Top Weighted Deals</h2>
        <DataTable<any> rows={topRows} columns={topCols} rowKey={(r: any) => String(r.id)} />
      </section>

      <div className="text-xs text-neutral-400">r1473 · Founder-only · STABLE SECDEF RPCs · RLS founder-only.</div>
    </div>
  );
}
