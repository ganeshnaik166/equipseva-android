import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [loyalty, actions, eroding, kindDist, statusFunnel, monthlyTrend, shareSummary] = await Promise.all([
    supabase.rpc('list_loyalty_r2667'),
    supabase.rpc('list_expansion_actions_r2667'),
    supabase.rpc('top_eroding_focus_r2667'),
    supabase.rpc('loyalty_kind_distribution_r2667'),
    supabase.rpc('status_funnel_r2667'),
    supabase.rpc('monthly_loyalty_trend_r2667'),
    supabase.rpc('our_share_summary_r2667'),
  ]);

  const summary = (shareSummary.data ?? [])[0] ?? { total_chains: 0, total_our_units: 0, total_competitor_units: 0, avg_share_pct: 0 };

  const loyaltyCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'our_equipment_count', header: 'Our Units', render: (r: any) => r.our_equipment_count },
    { key: 'competitor_equipment_count', header: 'Competitor Units', render: (r: any) => r.competitor_equipment_count },
    { key: 'our_share_pct', header: 'Share %', render: (r: any) => `${r.our_share_pct}%` },
    { key: 'loyalty_kind', header: 'Loyalty', render: (r: any) => r.loyalty_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const erodingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'our_share_pct', header: 'Share %', render: (r: any) => `${r.our_share_pct}%` },
    { key: 'competitor_equipment_count', header: 'Competitor Units', render: (r: any) => r.competitor_equipment_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'loyalty_kind', header: 'Loyalty Kind', render: (r: any) => r.loyalty_kind },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_our_units', header: 'Our Units', render: (r: any) => r.total_our_units },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString() },
    { key: 'chains_added', header: 'Chains Added', render: (r: any) => r.chains_added },
    { key: 'avg_share_pct', header: 'Avg Share %', render: (r: any) => `${r.avg_share_pct}%` },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain Installed-Base Loyalty</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Track our share vs competitor units across chains & defend the install base.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Chains</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_chains}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Our Units</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_our_units}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Competitor Units</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_competitor_units}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Share %</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.avg_share_pct}%</div>
        </div>
      </div>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Eroding Chains (focus list)</h2>
        <DataTable
          rows={eroding.data ?? []}
          columns={erodingCols}
          emptyMessage="No eroding chains"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Chains</h2>
        <DataTable
          rows={loyalty.data ?? []}
          columns={loyaltyCols}
          emptyMessage="No chains tracked yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expansion Actions</h2>
        <DataTable
          rows={actions.data ?? []}
          columns={actionCols}
          emptyMessage="No actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Loyalty Kind Distribution</h2>
        <DataTable
          rows={kindDist.data ?? []}
          columns={kindCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.loyalty_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={statusFunnel.data ?? []}
          columns={funnelCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Trend</h2>
        <DataTable
          rows={monthlyTrend.data ?? []}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </div>
  );
}
