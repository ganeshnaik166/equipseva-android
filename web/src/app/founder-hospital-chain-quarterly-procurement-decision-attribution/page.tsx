import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  return `${Number(n ?? 0).toFixed(2)}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, decisionsRes, byCategoryRes, byVerdictRes, touchpointsRes, topChainsRes, trendRes, efficiencyRes] = await Promise.all([
    supabase.rpc('r2847_summary'),
    supabase.rpc('r2847_list_decisions'),
    supabase.rpc('r2847_by_category'),
    supabase.rpc('r2847_by_verdict'),
    supabase.rpc('r2847_touchpoints'),
    supabase.rpc('r2847_top_chains'),
    supabase.rpc('r2847_quarterly_trend'),
    supabase.rpc('r2847_influence_efficiency'),
  ]);

  const summary = (summaryRes.data ?? [])[0] ?? {
    total_decisions: 0,
    won_count: 0,
    lost_count: 0,
    pending_count: 0,
    total_contract_value_rupees: 0,
    total_our_cost_rupees: 0,
    avg_influence_score: 0,
    win_rate_pct: 0,
  };

  const decisions = decisionsRes.data ?? [];
  const byCategory = byCategoryRes.data ?? [];
  const byVerdict = byVerdictRes.data ?? [];
  const touchpoints = touchpointsRes.data ?? [];
  const topChains = topChainsRes.data ?? [];
  const trend = trendRes.data ?? [];
  const efficiency = efficiencyRes.data ?? [];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '6px' }}>
          Hospital Chain Quarterly Procurement Decision Attribution
        </h1>
        <p style={{ color: '#555', fontSize: '14px' }}>
          Round r2847 — chain × decision × stakeholders × our influence × close × cost × verdict.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total Decisions" value={String(summary.total_decisions ?? 0)} />
        <KpiCard label="Wins" value={String(summary.won_count ?? 0)} />
        <KpiCard label="Losses" value={String(summary.lost_count ?? 0)} />
        <KpiCard label="Pending" value={String(summary.pending_count ?? 0)} />
        <KpiCard label="Win Rate" value={pct(summary.win_rate_pct)} />
        <KpiCard label="Avg Influence" value={Number(summary.avg_influence_score ?? 0).toFixed(2)} />
        <KpiCard label="Contract Value" value={rupees(summary.total_contract_value_rupees)} />
        <KpiCard label="Our Cost" value={rupees(summary.total_our_cost_rupees)} />
      </section>

      <Section title="All Decisions">
        <DataTable
          rows={decisions}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'decision_quarter', header: 'Quarter', render: (r: any) => r.decision_quarter },
            { key: 'decision_category', header: 'Category', render: (r: any) => r.decision_category },
            { key: 'stakeholders', header: 'Stakeholders', render: (r: any) => r.stakeholders },
            { key: 'our_influence_score', header: 'Influence', render: (r: any) => Number(r.our_influence_score).toFixed(2) },
            { key: 'close_status', header: 'Close', render: (r: any) => r.close_status },
            { key: 'contract_value_rupees', header: 'Value', render: (r: any) => rupees(r.contract_value_rupees) },
            { key: 'our_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.our_cost_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict },
            { key: 'decided_at', header: 'Decided', render: (r: any) => String(r.decided_at) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="By Category">
        <DataTable
          rows={byCategory}
          columns={[
            { key: 'decision_category', header: 'Category', render: (r: any) => r.decision_category },
            { key: 'decisions', header: 'Decisions', render: (r: any) => String(r.decisions) },
            { key: 'wins', header: 'Wins', render: (r: any) => String(r.wins) },
            { key: 'win_rate_pct', header: 'Win Rate', render: (r: any) => pct(r.win_rate_pct) },
            { key: 'total_value_rupees', header: 'Value', render: (r: any) => rupees(r.total_value_rupees) },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.total_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.decision_category ?? i)}
        />
      </Section>

      <Section title="By Verdict">
        <DataTable
          rows={byVerdict}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict },
            { key: 'decisions', header: 'Decisions', render: (r: any) => String(r.decisions) },
            { key: 'total_value_rupees', header: 'Value', render: (r: any) => rupees(r.total_value_rupees) },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.total_cost_rupees) },
            { key: 'avg_influence', header: 'Avg Influence', render: (r: any) => Number(r.avg_influence ?? 0).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.verdict ?? i)}
        />
      </Section>

      <Section title="Top Chains by Value">
        <DataTable
          rows={topChains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'decisions', header: 'Decisions', render: (r: any) => String(r.decisions) },
            { key: 'total_value_rupees', header: 'Value', render: (r: any) => rupees(r.total_value_rupees) },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.total_cost_rupees) },
            { key: 'net_margin_rupees', header: 'Net Margin', render: (r: any) => rupees(r.net_margin_rupees) },
            { key: 'avg_influence', header: 'Avg Influence', render: (r: any) => Number(r.avg_influence ?? 0).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </Section>

      <Section title="Quarterly Trend">
        <DataTable
          rows={trend}
          columns={[
            { key: 'decision_quarter', header: 'Quarter', render: (r: any) => r.decision_quarter },
            { key: 'decisions', header: 'Decisions', render: (r: any) => String(r.decisions) },
            { key: 'wins', header: 'Wins', render: (r: any) => String(r.wins) },
            { key: 'win_rate_pct', header: 'Win Rate', render: (r: any) => pct(r.win_rate_pct) },
            { key: 'value_rupees', header: 'Value', render: (r: any) => rupees(r.value_rupees) },
            { key: 'cost_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.decision_quarter ?? i)}
        />
      </Section>

      <Section title="Touchpoints">
        <DataTable
          rows={touchpoints}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'touchpoint_type', header: 'Type', render: (r: any) => r.touchpoint_type },
            { key: 'touchpoint_date', header: 'Date', render: (r: any) => String(r.touchpoint_date) },
            { key: 'owner_name', header: 'Owner', render: (r: any) => r.owner_name },
            { key: 'influence_delta', header: 'Influence Delta', render: (r: any) => Number(r.influence_delta).toFixed(2) },
            { key: 'cost_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_rupees) },
            { key: 'outcome_note', header: 'Outcome', render: (r: any) => r.outcome_note ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Influence Efficiency (Rupees per Influence Point)">
        <DataTable
          rows={efficiency}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'decision_category', header: 'Category', render: (r: any) => r.decision_category },
            { key: 'our_influence_score', header: 'Influence', render: (r: any) => Number(r.our_influence_score).toFixed(2) },
            { key: 'contract_value_rupees', header: 'Value', render: (r: any) => rupees(r.contract_value_rupees) },
            { key: 'our_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.our_cost_rupees) },
            { key: 'rupees_per_influence_point', header: 'Cost / Inf Pt', render: (r: any) => rupees(r.rupees_per_influence_point) },
            { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i) + '-' + String(i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e2e2e2', borderRadius: '8px', padding: '14px', background: '#fff' }}>
      <div style={{ color: '#666', fontSize: '12px', marginBottom: '6px' }}>{label}</div>
      <div style={{ fontSize: '20px', fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '24px' }}>
      <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '10px' }}>{title}</h2>
      {children}
    </section>
  );
}
