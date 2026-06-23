import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderLeadershipAntiPatternSpotterPage() {
  const supabase = await getSupabaseServerClient();

  const [patternsRes, actionsRes, topCostRes, freqDistRes, killOutcomeRes, monthlyRes, statusRes] = await Promise.all([
    supabase.rpc('list_anti_patterns_r2509'),
    supabase.rpc('list_kill_actions_r2509'),
    supabase.rpc('top_cost_patterns_r2509'),
    supabase.rpc('frequency_distribution_r2509'),
    supabase.rpc('kill_outcome_summary_r2509'),
    supabase.rpc('monthly_anti_pattern_trend_r2509'),
    supabase.rpc('status_funnel_r2509'),
  ]);

  const patterns = (patternsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topCost = (topCostRes.data ?? []) as any[];
  const freqDist = (freqDistRes.data ?? []) as any[];
  const killOutcome = (killOutcomeRes.data ?? []) as any[];
  const monthly = (monthlyRes.data ?? []) as any[];
  const statusFunnel = (statusRes.data ?? []) as any[];

  const patternsCols: Column<any>[] = [
    { key: 'pattern_kind', header: 'Pattern', render: (r: any) => r.pattern_kind },
    { key: 'frequency_score', header: 'Freq', render: (r: any) => r.frequency_score },
    { key: 'cost_impact_rupees', header: 'Cost ₹', render: (r: any) => Number(r.cost_impact_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'observed_at', header: 'Observed', render: (r: any) => new Date(r.observed_at).toLocaleDateString('en-IN') },
    { key: 'observation_md', header: 'Observation', render: (r: any) => r.observation_md ?? '—' },
    { key: 'correction_md', header: 'Correction', render: (r: any) => r.correction_md ?? '—' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'pattern_kind', header: 'Pattern', render: (r: any) => r.pattern_kind },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'action_at', header: 'Acted', render: (r: any) => new Date(r.action_at).toLocaleDateString('en-IN') },
    { key: 'follow_up_at', header: 'Follow up', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString('en-IN') : '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topCostCols: Column<any>[] = [
    { key: 'pattern_kind', header: 'Pattern', render: (r: any) => r.pattern_kind },
    { key: 'total_cost_rupees', header: 'Total Cost ₹', render: (r: any) => Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'occurrences', header: 'Occurrences', render: (r: any) => r.occurrences },
    { key: 'avg_frequency', header: 'Avg Freq', render: (r: any) => r.avg_frequency },
  ];

  const freqDistCols: Column<any>[] = [
    { key: 'bucket', header: 'Frequency Bucket', render: (r: any) => r.bucket },
    { key: 'pattern_count', header: 'Patterns', render: (r: any) => r.pattern_count },
  ];

  const killOutcomeCols: Column<any>[] = [
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
    { key: 'pct_of_total', header: 'Pct of Total', render: (r: any) => `${r.pct_of_total}%` },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'pattern_count', header: 'Patterns', render: (r: any) => r.pattern_count },
    { key: 'total_cost_rupees', header: 'Cost ₹', render: (r: any) => Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'pattern_count', header: 'Count', render: (r: any) => r.pattern_count },
    { key: 'total_cost_rupees', header: 'Cost ₹', render: (r: any) => Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN') },
  ];

  return (
    <div style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 600 }}>Founder Leadership Anti-Pattern Spotter</h1>
        <p style={{ color: '#555', fontSize: 13 }}>Anti-pattern > frequency > cost > correction > root cause > kill plan.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Anti-patterns</h2>
        <DataTable
          rows={patterns}
          columns={patternsCols}
          emptyMessage="No anti-patterns logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Kill actions</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No kill actions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top cost patterns</h2>
        <DataTable
          rows={topCost}
          columns={topCostCols}
          emptyMessage="No cost data."
          rowKey={(r: any, i: number) => String(r.pattern_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Frequency distribution</h2>
        <DataTable
          rows={freqDist}
          columns={freqDistCols}
          emptyMessage="No frequency data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Kill outcome summary</h2>
        <DataTable
          rows={killOutcome}
          columns={killOutcomeCols}
          emptyMessage="No outcomes recorded."
          rowKey={(r: any, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly trend."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </div>
  );
}
