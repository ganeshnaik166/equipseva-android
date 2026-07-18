import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SpendRow = {
  id: string;
  chain_name: string;
  observation_period_start: string;
  observation_period_end: string;
  pharmacy_spend_rupees: number;
  our_influence_kind: string;
  cross_sell_opportunity_rupees: number;
  upsell_target_kind: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type ActionRow = {
  id: string;
  spend_id: string;
  chain_name: string;
  action_at: string;
  action_kind: string;
  outcome: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type TopChainRow = {
  chain_name: string;
  total_pharmacy_spend_rupees: number;
  total_cross_sell_opportunity_rupees: number;
  influence_kind: string;
  status: string;
};

type InfluenceSummaryRow = {
  our_influence_kind: string;
  chain_count: number;
  total_pharmacy_spend_rupees: number;
  total_cross_sell_opportunity_rupees: number;
};

type UpsellBreakdownRow = {
  upsell_target_kind: string;
  chain_count: number;
  total_cross_sell_opportunity_rupees: number;
};

type MonthlyTrendRow = {
  month_label: string;
  action_count: number;
  positive_count: number;
  pending_count: number;
};

type FunnelRow = {
  status: string;
  chain_count: number;
  total_cross_sell_opportunity_rupees: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [spendRes, actionsRes, topRes, influenceRes, upsellRes, trendRes, funnelRes] = await Promise.all([
    sb.rpc('list_spend_r2543'),
    sb.rpc('list_cross_sell_actions_r2543'),
    sb.rpc('top_opportunity_chains_r2543'),
    sb.rpc('influence_kind_summary_r2543'),
    sb.rpc('upsell_target_breakdown_r2543'),
    sb.rpc('monthly_cross_sell_trend_r2543'),
    sb.rpc('status_funnel_r2543'),
  ]);

  const spend: SpendRow[] = (spendRes.data as SpendRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const top: TopChainRow[] = (topRes.data as TopChainRow[] | null) ?? [];
  const influence: InfluenceSummaryRow[] = (influenceRes.data as InfluenceSummaryRow[] | null) ?? [];
  const upsell: UpsellBreakdownRow[] = (upsellRes.data as UpsellBreakdownRow[] | null) ?? [];
  const trend: MonthlyTrendRow[] = (trendRes.data as MonthlyTrendRow[] | null) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[] | null) ?? [];

  const spendCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'period', header: 'Period', render: (r: any) => String(r.observation_period_start) + ' → ' + String(r.observation_period_end) },
    { key: 'pharmacy_spend_rupees', header: 'Pharmacy Spend', render: (r: any) => fmtRupees(r.pharmacy_spend_rupees) },
    { key: 'our_influence_kind', header: 'Influence', render: (r: any) => r.our_influence_kind },
    { key: 'cross_sell_opportunity_rupees', header: 'Cross-Sell Opp', render: (r: any) => fmtRupees(r.cross_sell_opportunity_rupees) },
    { key: 'upsell_target_kind', header: 'Upsell Target', render: (r: any) => r.upsell_target_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString('en-IN') },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_pharmacy_spend_rupees', header: 'Total Pharmacy Spend', render: (r: any) => fmtRupees(r.total_pharmacy_spend_rupees) },
    { key: 'total_cross_sell_opportunity_rupees', header: 'Total Cross-Sell Opp', render: (r: any) => fmtRupees(r.total_cross_sell_opportunity_rupees) },
    { key: 'influence_kind', header: 'Influence', render: (r: any) => r.influence_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const influenceCols: Column<any>[] = [
    { key: 'our_influence_kind', header: 'Influence Kind', render: (r: any) => r.our_influence_kind },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_pharmacy_spend_rupees', header: 'Pharmacy Spend', render: (r: any) => fmtRupees(r.total_pharmacy_spend_rupees) },
    { key: 'total_cross_sell_opportunity_rupees', header: 'Cross-Sell Opp', render: (r: any) => fmtRupees(r.total_cross_sell_opportunity_rupees) },
  ];

  const upsellCols: Column<any>[] = [
    { key: 'upsell_target_kind', header: 'Upsell Target', render: (r: any) => r.upsell_target_kind },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_cross_sell_opportunity_rupees', header: 'Cross-Sell Opp', render: (r: any) => fmtRupees(r.total_cross_sell_opportunity_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_cross_sell_opportunity_rupees', header: 'Cross-Sell Opp', render: (r: any) => fmtRupees(r.total_cross_sell_opportunity_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain — Pharmacy Spend & Influence</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Per-chain pharmacy spend & our influence kind =&gt; cross-sell / upsell opportunities from pharmacy data.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Opportunity Chains</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No chain opportunities yet"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Influence Kind Summary</h2>
        <DataTable
          rows={influence}
          columns={influenceCols}
          emptyMessage="No influence rows yet"
          rowKey={(r: any, i: number) => String(r.our_influence_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upsell Target Breakdown</h2>
        <DataTable
          rows={upsell}
          columns={upsellCols}
          emptyMessage="No upsell targets yet"
          rowKey={(r: any, i: number) => String(r.upsell_target_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Cross-Sell Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No actions logged yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status rows yet"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Chain Pharmacy Spend</h2>
        <DataTable
          rows={spend}
          columns={spendCols}
          emptyMessage="No pharmacy spend records yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Cross-Sell Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No cross-sell actions logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
