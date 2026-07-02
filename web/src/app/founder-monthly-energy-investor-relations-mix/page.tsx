import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyEnergyInvestorRelationsMixPage() {
  const supabase = await getSupabaseServerClient();

  const [
    mixRes,
    actionsRes,
    trendRes,
    statusDistRes,
    drainRes,
    focusRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_ir_mix_r2569'),
    supabase.rpc('list_reallocation_actions_r2569'),
    supabase.rpc('monthly_leverage_trend_r2569'),
    supabase.rpc('status_distribution_r2569'),
    supabase.rpc('top_drain_investors_r2569'),
    supabase.rpc('top_high_leverage_focus_r2569'),
    supabase.rpc('action_status_funnel_r2569'),
  ]);

  const mix = (mixRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const statusDist = (statusDistRes.data ?? []) as any[];
  const drains = (drainRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const mixCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'ir_hours', header: 'IR Hours', render: (r: any) => r.ir_hours },
    { key: 'dilution_pct', header: 'Dilution %', render: (r: any) => r.dilution_pct },
    { key: 'leverage_score', header: 'Leverage', render: (r: any) => r.leverage_score },
    { key: 'stalling_count', header: 'Stalling', render: (r: any) => r.stalling_count },
    { key: 'roi_per_hour_rupees', header: 'ROI/hr (Rs)', render: (r: any) => r.roi_per_hour_rupees },
    { key: 'top_high_leverage_investor', header: 'Top Leverage', render: (r: any) => r.top_high_leverage_investor ?? '-' },
    { key: 'top_drain_investor', header: 'Top Drain', render: (r: any) => r.top_drain_investor ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary },
    { key: 'expected_impact_md', header: 'Expected Impact', render: (r: any) => r.expected_impact_md ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'ir_hours', header: 'IR Hours', render: (r: any) => r.ir_hours },
    { key: 'leverage_score', header: 'Leverage', render: (r: any) => r.leverage_score },
    { key: 'stalling_count', header: 'Stalling', render: (r: any) => r.stalling_count },
    { key: 'roi_per_hour_rupees', header: 'ROI/hr (Rs)', render: (r: any) => r.roi_per_hour_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const statusDistCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
    { key: 'avg_leverage', header: 'Avg Leverage', render: (r: any) => r.avg_leverage },
    { key: 'total_ir_hours', header: 'Total IR Hours', render: (r: any) => r.total_ir_hours },
    { key: 'avg_stalling', header: 'Avg Stalling', render: (r: any) => r.avg_stalling },
  ];

  const drainCols: Column<any>[] = [
    { key: 'top_drain_investor', header: 'Drain Investor', render: (r: any) => r.top_drain_investor },
    { key: 'occurrences', header: 'Months Topped', render: (r: any) => r.occurrences },
    { key: 'total_stalling', header: 'Total Stalling', render: (r: any) => r.total_stalling },
    { key: 'avg_leverage', header: 'Avg Leverage', render: (r: any) => r.avg_leverage },
  ];

  const focusCols: Column<any>[] = [
    { key: 'top_high_leverage_investor', header: 'High-Leverage Investor', render: (r: any) => r.top_high_leverage_investor },
    { key: 'occurrences', header: 'Months Topped', render: (r: any) => r.occurrences },
    { key: 'avg_leverage', header: 'Avg Leverage', render: (r: any) => r.avg_leverage },
    { key: 'total_roi_rupees', header: 'Total ROI (Rs)', render: (r: any) => r.total_roi_rupees },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Monthly Energy & Investor Relations Mix
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Month-by-month IR time vs dilution vs leverage score. Stalling-investor count & ROI per investor hour drive
        reallocation actions (delegate / automate / eliminate / reduce cadence / escalate).
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly IR Mix</h2>
        <DataTable
          rows={mix}
          columns={mixCols}
          emptyMessage="No monthly IR mix rows yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Reallocation Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No reallocation actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Leverage Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Status Distribution</h2>
        <DataTable
          rows={statusDist}
          columns={statusDistCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Drain Investors</h2>
        <DataTable
          rows={drains}
          columns={drainCols}
          emptyMessage="No drain investors flagged"
          rowKey={(r: any, i: number) => String(r.top_drain_investor ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top High-Leverage Focus</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No high-leverage investors yet"
          rowKey={(r: any, i: number) => String(r.top_high_leverage_investor ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Action Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No actions yet"
          rowKey={(r: any, i: number) => String((r.action_kind ?? '') + '|' + (r.status ?? '') + '|' + (r.outcome ?? '') + '|' + i)}
        />
      </section>
    </div>
  );
}
