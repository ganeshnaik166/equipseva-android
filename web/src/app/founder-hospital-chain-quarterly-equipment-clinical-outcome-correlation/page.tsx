import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_correlations: number;
  high_confidence: number;
  strong_positive: number;
  strong_negative: number;
  avg_abs_pearson_r: number;
  total_uplift_lakhs: number;
};

type Correlation = {
  id: string;
  chain_name: string;
  quarter: string;
  equipment_category: string;
  uptime_pct: number;
  clinical_metric: string;
  metric_baseline: number;
  metric_observed: number;
  pearson_r: number;
  p_value: number;
  confidence_level: string;
  story_headline: string;
};

type ChainRow = {
  chain_name: string;
  correlations: number;
  high_conf: number;
  avg_r: number;
  uplift_lakhs: number;
};

type EquipmentRow = {
  equipment_category: string;
  correlations: number;
  avg_uptime: number;
  avg_abs_r: number;
};

type Signal = {
  id: string;
  chain_name: string;
  quarter: string;
  signal_type: string;
  equipment_category: string;
  delta_pct: number;
  recommended_action: string;
  est_revenue_uplift_lakhs: number;
  owner_role: string;
  due_by: string;
};

type SignalMix = {
  signal_type: string;
  count_signals: number;
  uplift_lakhs: number;
};

type Story = {
  chain_name: string;
  equipment_category: string;
  pearson_r: number;
  confidence_level: string;
  story_headline: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ovRes, corrRes, chainRes, equipRes, sigRes, mixRes, storyRes] = await Promise.all([
    supabase.rpc('r2859_overview'),
    supabase.rpc('r2859_list_correlations'),
    supabase.rpc('r2859_by_chain'),
    supabase.rpc('r2859_by_equipment'),
    supabase.rpc('r2859_list_signals'),
    supabase.rpc('r2859_signal_mix'),
    supabase.rpc('r2859_top_stories'),
  ]);

  const overview: Overview = (ovRes.data?.[0] ?? {
    total_correlations: 0,
    high_confidence: 0,
    strong_positive: 0,
    strong_negative: 0,
    avg_abs_pearson_r: 0,
    total_uplift_lakhs: 0,
  }) as Overview;

  const correlations: Correlation[] = (corrRes.data ?? []) as Correlation[];
  const chains: ChainRow[] = (chainRes.data ?? []) as ChainRow[];
  const equipment: EquipmentRow[] = (equipRes.data ?? []) as EquipmentRow[];
  const signals: Signal[] = (sigRes.data ?? []) as Signal[];
  const mix: SignalMix[] = (mixRes.data ?? []) as SignalMix[];
  const stories: Story[] = (storyRes.data ?? []) as Story[];

  const kpis = [
    { label: 'Correlations tracked', value: overview.total_correlations },
    { label: 'High-confidence', value: overview.high_confidence },
    { label: 'Strong positive (r >= 0.7)', value: overview.strong_positive },
    { label: 'Strong negative (r <= -0.7)', value: overview.strong_negative },
    { label: 'Avg |Pearson r|', value: Number(overview.avg_abs_pearson_r ?? 0).toFixed(3) },
    { label: 'Pipeline uplift (lakhs)', value: `Rs ${Number(overview.total_uplift_lakhs ?? 0).toFixed(2)}` },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Quarterly Equipment & Clinical Outcome Correlation
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Quarterly view of how equipment uptime correlates with clinical outcomes across every hospital chain. Use
        confidence + Pearson r to decide where to expand, escalate & celebrate.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ color: '#6b7280', fontSize: 12, marginBottom: 4 }} dangerouslySetInnerHTML={{ __html: k.label }} />
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top stories (high confidence)</h2>
        <DataTable
          rows={stories}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Story) => r.chain_name },
            { key: 'equipment_category', header: 'Equipment', render: (r: Story) => r.equipment_category },
            { key: 'pearson_r', header: 'Pearson r', render: (r: Story) => Number(r.pearson_r).toFixed(3) },
            { key: 'confidence_level', header: 'Confidence', render: (r: Story) => r.confidence_level },
            { key: 'story_headline', header: 'Story', render: (r: Story) => r.story_headline },
          ]}
          emptyMessage="No data"
          rowKey={(r: Story, i: number) => String((r as unknown as { id?: string }).id ?? `${r.chain_name}-${r.equipment_category}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All correlations (sorted by |r|)</h2>
        <DataTable
          rows={correlations}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Correlation) => r.chain_name },
            { key: 'quarter', header: 'Quarter', render: (r: Correlation) => r.quarter },
            { key: 'equipment_category', header: 'Equipment', render: (r: Correlation) => r.equipment_category },
            { key: 'uptime_pct', header: 'Uptime %', render: (r: Correlation) => `${Number(r.uptime_pct).toFixed(2)}%` },
            { key: 'clinical_metric', header: 'Clinical metric', render: (r: Correlation) => r.clinical_metric },
            { key: 'metric_baseline', header: 'Baseline', render: (r: Correlation) => Number(r.metric_baseline).toFixed(2) },
            { key: 'metric_observed', header: 'Observed', render: (r: Correlation) => Number(r.metric_observed).toFixed(2) },
            { key: 'pearson_r', header: 'r', render: (r: Correlation) => Number(r.pearson_r).toFixed(3) },
            { key: 'p_value', header: 'p', render: (r: Correlation) => Number(r.p_value).toFixed(4) },
            { key: 'confidence_level', header: 'Confidence', render: (r: Correlation) => r.confidence_level },
          ]}
          emptyMessage="No data"
          rowKey={(r: Correlation, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain leaderboard</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'correlations', header: 'Correlations', render: (r: ChainRow) => String(r.correlations) },
            { key: 'high_conf', header: 'High-conf', render: (r: ChainRow) => String(r.high_conf) },
            { key: 'avg_r', header: 'Avg |r|', render: (r: ChainRow) => Number(r.avg_r).toFixed(3) },
            { key: 'uplift_lakhs', header: 'Uplift (lakhs)', render: (r: ChainRow) => `Rs ${Number(r.uplift_lakhs).toFixed(2)}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(`${r.chain_name}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Equipment leaderboard</h2>
        <DataTable
          rows={equipment}
          columns={[
            { key: 'equipment_category', header: 'Equipment', render: (r: EquipmentRow) => r.equipment_category },
            { key: 'correlations', header: 'Correlations', render: (r: EquipmentRow) => String(r.correlations) },
            { key: 'avg_uptime', header: 'Avg uptime %', render: (r: EquipmentRow) => `${Number(r.avg_uptime).toFixed(2)}%` },
            { key: 'avg_abs_r', header: 'Avg |r|', render: (r: EquipmentRow) => Number(r.avg_abs_r).toFixed(3) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EquipmentRow, i: number) => String(`${r.equipment_category}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Signal mix</h2>
        <DataTable
          rows={mix}
          columns={[
            { key: 'signal_type', header: 'Signal', render: (r: SignalMix) => r.signal_type },
            { key: 'count_signals', header: 'Count', render: (r: SignalMix) => String(r.count_signals) },
            { key: 'uplift_lakhs', header: 'Uplift (lakhs)', render: (r: SignalMix) => `Rs ${Number(r.uplift_lakhs).toFixed(2)}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: SignalMix, i: number) => String(`${r.signal_type}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action signals</h2>
        <DataTable
          rows={signals}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Signal) => r.chain_name },
            { key: 'signal_type', header: 'Signal', render: (r: Signal) => r.signal_type },
            { key: 'equipment_category', header: 'Equipment', render: (r: Signal) => r.equipment_category },
            { key: 'delta_pct', header: 'Delta %', render: (r: Signal) => `${Number(r.delta_pct).toFixed(2)}%` },
            { key: 'recommended_action', header: 'Action', render: (r: Signal) => r.recommended_action },
            { key: 'est_revenue_uplift_lakhs', header: 'Uplift (lakhs)', render: (r: Signal) => `Rs ${Number(r.est_revenue_uplift_lakhs).toFixed(2)}` },
            { key: 'owner_role', header: 'Owner', render: (r: Signal) => r.owner_role },
            { key: 'due_by', header: 'Due', render: (r: Signal) => r.due_by },
          ]}
          emptyMessage="No data"
          rowKey={(r: Signal, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
