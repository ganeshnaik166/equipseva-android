import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, stagesRes, hotRes, lostRes, tierRes, touchesRes, trendRes] = await Promise.all([
    sb.rpc('warranty_pipeline_summary_r2239'),
    sb.rpc('warranty_stage_breakdown_r2239'),
    sb.rpc('warranty_hot_leads_r2239'),
    sb.rpc('warranty_lost_reasons_r2239'),
    sb.rpc('warranty_won_tier_mix_r2239'),
    sb.rpc('warranty_recent_touches_r2239'),
    sb.rpc('warranty_monthly_trend_r2239'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {}) as any;
  const stages = (stagesRes.data ?? []) as any[];
  const hot = (hotRes.data ?? []) as any[];
  const lost = (lostRes.data ?? []) as any[];
  const tiers = (tierRes.data ?? []) as any[];
  const touches = (touchesRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => String(r.stage ?? '') },
    { key: 'deal_count', header: 'Deals', render: (r: any) => String(r.deal_count ?? 0) },
    { key: 'total_value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.total_value_rupees ?? 0) },
    { key: 'avg_win_prob_pct', header: 'Avg Win Prob %', render: (r: any) => String(r.avg_win_prob_pct ?? 0) },
  ];

  const hotCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'warranty_expires_on', header: 'Warranty Ends', render: (r: any) => String(r.warranty_expires_on ?? '') },
    { key: 'days_left', header: 'Days Left', render: (r: any) => String(r.days_left ?? 0) },
    { key: 'pipeline_stage', header: 'Stage', render: (r: any) => String(r.pipeline_stage ?? '') },
    { key: 'proposed_annual_fee_rupees', header: 'Proposed Fee (Rs)', render: (r: any) => String(r.proposed_annual_fee_rupees ?? 0) },
    { key: 'win_probability_pct', header: 'Win Prob %', render: (r: any) => String(r.win_probability_pct ?? 0) },
  ];

  const lostCols: Column<any>[] = [
    { key: 'lost_reason', header: 'Lost Reason', render: (r: any) => String(r.lost_reason ?? '') },
    { key: 'deal_count', header: 'Deals', render: (r: any) => String(r.deal_count ?? 0) },
    { key: 'lost_value_rupees', header: 'Lost Value (Rs)', render: (r: any) => String(r.lost_value_rupees ?? 0) },
  ];

  const tierCols: Column<any>[] = [
    { key: 'amc_tier', header: 'AMC Tier', render: (r: any) => String(r.amc_tier ?? '') },
    { key: 'deals_won', header: 'Deals Won', render: (r: any) => String(r.deals_won ?? 0) },
    { key: 'total_fee_rupees', header: 'Total Fee (Rs)', render: (r: any) => String(r.total_fee_rupees ?? 0) },
  ];

  const touchCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => String(r.occurred_at ?? '').slice(0, 19) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'touch_kind', header: 'Touch Kind', render: (r: any) => String(r.touch_kind ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'touch_summary', header: 'Summary', render: (r: any) => String(r.touch_summary ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => String(r.month_label ?? '') },
    { key: 'won_count', header: 'Won', render: (r: any) => String(r.won_count ?? 0) },
    { key: 'lost_count', header: 'Lost', render: (r: any) => String(r.lost_count ?? 0) },
    { key: 'won_value_rupees', header: 'Won Value (Rs)', render: (r: any) => String(r.won_value_rupees ?? 0) },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Warranty → AMC Conversion Pipeline</h1>
        <p className="text-sm text-gray-600">Equipment coming off warranty, AMC conversion funnel, win rate & lost revenue</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">In Pipeline</div>
          <div className="text-2xl font-semibold">{String(summary.total_in_pipeline ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Expiring &lt;= 30d</div>
          <div className="text-2xl font-semibold">{String(summary.expiring_30d ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Won YTD</div>
          <div className="text-2xl font-semibold">{String(summary.won_ytd ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Lost YTD</div>
          <div className="text-2xl font-semibold">{String(summary.lost_ytd ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Win Rate %</div>
          <div className="text-2xl font-semibold">{String(summary.win_rate_pct ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Pipeline Value (Rs)</div>
          <div className="text-2xl font-semibold">{String(summary.total_pipeline_value_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Lost Revenue (Rs)</div>
          <div className="text-2xl font-semibold">{String(summary.lost_revenue_rupees ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stage Breakdown</h2>
        <DataTable columns={stageCols} rows={stages} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hot Leads — Warranty Ending &lt;= 60 Days</h2>
        <DataTable columns={hotCols} rows={hot} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lost Reasons</h2>
        <DataTable columns={lostCols} rows={lost} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Won Deal Tier Mix</h2>
        <DataTable columns={tierCols} rows={tiers} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Touches</h2>
        <DataTable columns={touchCols} rows={touches} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Trend — Last 6 Months</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
