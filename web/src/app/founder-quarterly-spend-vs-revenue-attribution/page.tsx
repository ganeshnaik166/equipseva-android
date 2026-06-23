import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlySpendVsRevenueAttributionPage() {
  const supabase = await getSupabaseServerClient();

  const [allocsRes, changesRes, paybackRes, teamRes, ltvCacRes, trendRes, funnelRes] = await Promise.all([
    supabase.rpc('list_spend_revenue_r2573'),
    supabase.rpc('list_attribution_changes_r2573'),
    supabase.rpc('top_payback_teams_r2573'),
    supabase.rpc('team_kind_distribution_r2573'),
    supabase.rpc('ltv_cac_ratio_summary_r2573'),
    supabase.rpc('monthly_spend_trend_r2573'),
    supabase.rpc('status_funnel_r2573'),
  ]);

  const allocations = (allocsRes.data ?? []) as any[];
  const changes = (changesRes.data ?? []) as any[];
  const payback = (paybackRes.data ?? []) as any[];
  const teams = (teamRes.data ?? []) as any[];
  const ltvCac = (ltvCacRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const fmtR = (n: number) => `Rs ${Number(n ?? 0).toLocaleString('en-IN')}`;

  const allocationCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'team_kind', header: 'Team', render: (r: any) => r.team_kind ?? '-' },
    { key: 'spend_rupees', header: 'Spend', render: (r: any) => fmtR(r.spend_rupees) },
    { key: 'revenue_attributed_rupees', header: 'Revenue', render: (r: any) => fmtR(r.revenue_attributed_rupees) },
    { key: 'cac_rupees', header: 'CAC', render: (r: any) => fmtR(r.cac_rupees) },
    { key: 'ltv_rupees', header: 'LTV', render: (r: any) => fmtR(r.ltv_rupees) },
    { key: 'payback_months', header: 'Payback (mo)', render: (r: any) => r.payback_months ?? 0 },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const changeCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'team_kind', header: 'Team', render: (r: any) => r.team_kind ?? '-' },
    { key: 'change_kind', header: 'Change', render: (r: any) => r.change_kind ?? '-' },
    { key: 'prior_spend_rupees', header: 'Prior', render: (r: any) => fmtR(r.prior_spend_rupees) },
    { key: 'new_spend_rupees', header: 'New', render: (r: any) => fmtR(r.new_spend_rupees) },
    { key: 'delta_rupees', header: 'Delta', render: (r: any) => fmtR(r.delta_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const paybackCols: Column<any>[] = [
    { key: 'team_kind', header: 'Team', render: (r: any) => r.team_kind ?? '-' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '-' },
    { key: 'payback_months', header: 'Payback (mo)', render: (r: any) => r.payback_months ?? 0 },
    { key: 'spend_rupees', header: 'Spend', render: (r: any) => fmtR(r.spend_rupees) },
    { key: 'revenue_attributed_rupees', header: 'Revenue', render: (r: any) => fmtR(r.revenue_attributed_rupees) },
  ];

  const teamCols: Column<any>[] = [
    { key: 'team_kind', header: 'Team', render: (r: any) => r.team_kind ?? '-' },
    { key: 'allocation_count', header: 'Allocations', render: (r: any) => r.allocation_count ?? 0 },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r: any) => fmtR(r.total_spend_rupees) },
    { key: 'total_revenue_rupees', header: 'Total Revenue', render: (r: any) => fmtR(r.total_revenue_rupees) },
  ];

  const ltvCacCols: Column<any>[] = [
    { key: 'team_kind', header: 'Team', render: (r: any) => r.team_kind ?? '-' },
    { key: 'avg_cac_rupees', header: 'Avg CAC', render: (r: any) => fmtR(Math.round(Number(r.avg_cac_rupees ?? 0))) },
    { key: 'avg_ltv_rupees', header: 'Avg LTV', render: (r: any) => fmtR(Math.round(Number(r.avg_ltv_rupees ?? 0))) },
    { key: 'ltv_cac_ratio', header: 'LTV/CAC', render: (r: any) => Number(r.ltv_cac_ratio ?? 0).toFixed(2) },
    { key: 'sample_size', header: 'Sample', render: (r: any) => r.sample_size ?? 0 },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '-' },
    { key: 'allocation_count', header: 'Allocations', render: (r: any) => r.allocation_count ?? 0 },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r: any) => fmtR(r.total_spend_rupees) },
    { key: 'total_revenue_rupees', header: 'Total Revenue', render: (r: any) => fmtR(r.total_revenue_rupees) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'allocation_count', header: 'Count', render: (r: any) => r.allocation_count ?? 0 },
    { key: 'total_spend_rupees', header: 'Spend', render: (r: any) => fmtR(r.total_spend_rupees) },
  ];

  return (
    <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <header>
        <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '4px' }}>
          Quarterly Spend vs Revenue Attribution
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Quarter & team spend vs revenue attributed — CAC, LTV & payback per team
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Allocations</h2>
        <DataTable
          rows={allocations}
          columns={allocationCols}
          emptyMessage="No allocations yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Attribution Changes</h2>
        <DataTable
          rows={changes}
          columns={changeCols}
          emptyMessage="No changes logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Fastest Payback Teams</h2>
        <DataTable
          rows={payback}
          columns={paybackCols}
          emptyMessage="No payback data"
          rowKey={(r: any, i: number) => String(r.team_kind ?? i) + '-' + String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Team Distribution</h2>
        <DataTable
          rows={teams}
          columns={teamCols}
          emptyMessage="No teams"
          rowKey={(r: any, i: number) => String(r.team_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>LTV/CAC Ratio Summary</h2>
        <DataTable
          rows={ltvCac}
          columns={ltvCacCols}
          emptyMessage="No LTV/CAC samples"
          rowKey={(r: any, i: number) => String(r.team_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Monthly Spend Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </div>
  );
}
