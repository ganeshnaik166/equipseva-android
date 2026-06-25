import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [pipelineRes, actionsRes, focusRes, decisionRes, funnelRes, trendRes, shareRes] = await Promise.all([
    supabase.rpc('list_pipeline_r2639'),
    supabase.rpc('list_decision_actions_r2639'),
    supabase.rpc('top_investment_value_focus_r2639'),
    supabase.rpc('decision_kind_distribution_r2639'),
    supabase.rpc('status_funnel_r2639'),
    supabase.rpc('quarterly_pipeline_trend_r2639'),
    supabase.rpc('our_share_summary_r2639'),
  ]);

  const pipeline = (pipelineRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const decision = (decisionRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const share = (shareRes.data ?? []) as any[];

  const fmtCr = (n: number | null | undefined) => {
    const v = Number(n ?? 0);
    if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
    if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
    return `Rs ${v.toLocaleString('en-IN')}`;
  };

  const pipelineColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'investment_value_rupees', header: 'Investment', render: (r: any) => fmtCr(r.investment_value_rupees) },
    { key: 'investment_decision_kind', header: 'Decision', render: (r: any) => r.investment_decision_kind },
    { key: 'our_share_kind', header: 'Our Share', render: (r: any) => r.our_share_kind },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => `${r.win_probability_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString('en-IN') },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'investment_value_rupees', header: 'Investment', render: (r: any) => fmtCr(r.investment_value_rupees) },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => `${r.win_probability_pct}%` },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => fmtCr(r.weighted_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const decisionColumns: Column<any>[] = [
    { key: 'investment_decision_kind', header: 'Decision', render: (r: any) => r.investment_decision_kind },
    { key: 'deal_count', header: 'Deals', render: (r: any) => r.deal_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
    { key: 'avg_win_probability', header: 'Avg Win %', render: (r: any) => `${r.avg_win_probability ?? 0}%` },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'deal_count', header: 'Deals', render: (r: any) => r.deal_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'deal_count', header: 'Deals', render: (r: any) => r.deal_count },
    { key: 'total_value_rupees', header: 'Pipeline Value', render: (r: any) => fmtCr(r.total_value_rupees) },
    { key: 'won_value_rupees', header: 'Won Value', render: (r: any) => fmtCr(r.won_value_rupees) },
  ];

  const shareColumns: Column<any>[] = [
    { key: 'our_share_kind', header: 'Our Share', render: (r: any) => r.our_share_kind },
    { key: 'deal_count', header: 'Deals', render: (r: any) => r.deal_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtCr(r.total_value_rupees) },
    { key: 'won_count', header: 'Won', render: (r: any) => r.won_count },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Quarterly Equipment Investment Pipeline</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track chain capex decisions quarter-by-quarter & lock in our AMC / install / training / parts share.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Weighted Focus (Open Deals)</h2>
        <DataTable
          rows={focus}
          columns={focusColumns}
          emptyMessage="No open deals to focus on"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.chain_name}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Full Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineColumns}
          emptyMessage="No pipeline records"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Decision Actions Log</h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          emptyMessage="No actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: 24, marginBottom: 32 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Decision Kind Distribution</h2>
          <DataTable
            rows={decision}
            columns={decisionColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.investment_decision_kind ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Funnel</h2>
          <DataTable
            rows={funnel}
            columns={funnelColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly Trend</h2>
          <DataTable
            rows={trend}
            columns={trendColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Our Share Summary</h2>
          <DataTable
            rows={share}
            columns={shareColumns}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.our_share_kind ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
