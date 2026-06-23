import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [cyclesRes, bottleneckRes, tierRes, stuckRes, dwellRes, monthlyRes, summaryRes] = await Promise.all([
    supabase.rpc('fn_r2403_list_cycles'),
    supabase.rpc('fn_r2403_bottleneck_breakdown'),
    supabase.rpc('fn_r2403_tier_velocity'),
    supabase.rpc('fn_r2403_stuck_cycles'),
    supabase.rpc('fn_r2403_stage_dwell'),
    supabase.rpc('fn_r2403_monthly_wins'),
    supabase.rpc('fn_r2403_summary'),
  ]);

  const cycles = cyclesRes.data ?? [];
  const bottlenecks = bottleneckRes.data ?? [];
  const tiers = tierRes.data ?? [];
  const stuck = stuckRes.data ?? [];
  const dwell = dwellRes.data ?? [];
  const monthly = monthlyRes.data ?? [];
  const summary = summaryRes.data?.[0] ?? null;

  const fmtRupees = (v: number | null | undefined) =>
    v == null ? '—' : `₹${(Number(v) / 100000).toFixed(1)}L`;

  const cycleCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => r.hospital_count },
    { key: 'rfp_issued_at', header: 'RFP Issued', render: (r) => new Date(r.rfp_issued_at).toLocaleDateString() },
    { key: 'total_days', header: 'Total Days', render: (r) => r.total_days },
    { key: 'our_days_active', header: 'Our Days', render: (r) => r.our_days_active },
    { key: 'their_days_active', header: 'Their Days', render: (r) => r.their_days_active },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'bottleneck_owner', header: 'Bottleneck', render: (r) => r.bottleneck_owner ?? '—' },
    { key: 'contract_value_rupees', header: 'Value', render: (r) => fmtRupees(r.contract_value_rupees) },
  ];

  const bottleneckCols: Column<any>[] = [
    { key: 'bottleneck_owner', header: 'Owner', render: (r) => r.bottleneck_owner },
    { key: 'active_cycles', header: 'Active Cycles', render: (r) => r.active_cycles },
    { key: 'avg_dwell_days', header: 'Avg Dwell (days)', render: (r) => r.avg_dwell_days ?? '—' },
    { key: 'pipeline_value_rupees', header: 'Pipeline Value', render: (r) => fmtRupees(r.pipeline_value_rupees) },
  ];

  const tierCols: Column<any>[] = [
    { key: 'chain_tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'cycles_won', header: 'Won', render: (r) => r.cycles_won },
    { key: 'avg_days_to_sign', header: 'Avg Days to Sign', render: (r) => r.avg_days_to_sign ?? '—' },
    { key: 'avg_our_days', header: 'Avg Our Days', render: (r) => r.avg_our_days ?? '—' },
    { key: 'avg_their_days', header: 'Avg Their Days', render: (r) => r.avg_their_days ?? '—' },
    { key: 'win_rate_pct', header: 'Win Rate %', render: (r) => r.win_rate_pct ?? '—' },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r) => r.chain_tier },
    { key: 'bottleneck_owner', header: 'Bottleneck', render: (r) => r.bottleneck_owner ?? '—' },
    { key: 'our_days_active', header: 'Our Days', render: (r) => r.our_days_active },
    { key: 'their_days_active', header: 'Their Days', render: (r) => r.their_days_active },
    { key: 'total_days', header: 'Total Days', render: (r) => r.total_days },
    { key: 'contract_value_rupees', header: 'Value', render: (r) => fmtRupees(r.contract_value_rupees) },
    { key: 'bottleneck_notes', header: 'Notes', render: (r) => r.bottleneck_notes ?? '—' },
  ];

  const dwellCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r) => r.stage },
    { key: 'events_count', header: 'Events', render: (r) => r.events_count },
    { key: 'avg_dwell_days', header: 'Avg Dwell (days)', render: (r) => r.avg_dwell_days ?? '—' },
    { key: 'us_owned_pct', header: 'Us-Owned %', render: (r) => r.us_owned_pct ?? '—' },
    { key: 'chain_owned_pct', header: 'Chain-Owned %', render: (r) => r.chain_owned_pct ?? '—' },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r) => new Date(r.month_start).toLocaleDateString() },
    { key: 'wins', header: 'Wins', render: (r) => r.wins },
    { key: 'total_value_rupees', header: 'Total Value', render: (r) => fmtRupees(r.total_value_rupees) },
    { key: 'avg_days_to_sign', header: 'Avg Days to Sign', render: (r) => r.avg_days_to_sign ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Chain Decision-Velocity Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-chain RFP =&gt; contract days, our share vs theirs, and bottleneck owner.
      </p>

      {summary && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active Cycles</div>
            <div style={{ fontSize: 24, fontWeight: 600 }}>{summary.active_cycles}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Won (90d)</div>
            <div style={{ fontSize: 24, fontWeight: 600 }}>{summary.won_last_90d}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Lost (90d)</div>
            <div style={{ fontSize: 24, fontWeight: 600 }}>{summary.lost_last_90d}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg Cycle Days</div>
            <div style={{ fontSize: 24, fontWeight: 600 }}>{summary.avg_cycle_days ?? '—'}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Pipeline Value</div>
            <div style={{ fontSize: 24, fontWeight: 600 }}>{fmtRupees(summary.pipeline_value_rupees)}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Our Share %</div>
            <div style={{ fontSize: 24, fontWeight: 600 }}>{summary.our_share_pct ?? '—'}</div>
          </div>
        </div>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Bottleneck Breakdown (active)</h2>
        <DataTable
          rows={bottlenecks}
          columns={bottleneckCols}
          emptyMessage="No active cycles."
          rowKey={(r: any) => r.bottleneck_owner}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tier Velocity</h2>
        <DataTable
          rows={tiers}
          columns={tierCols}
          emptyMessage="No tier data yet."
          rowKey={(r: any) => r.chain_tier}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Stuck Cycles (our days &gt;= 30 or chain days &gt;= 60)
        </h2>
        <DataTable
          rows={stuck}
          columns={stuckCols}
          emptyMessage="No stuck cycles."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stage Dwell (where time is spent)</h2>
        <DataTable
          rows={dwell}
          columns={dwellCols}
          emptyMessage="No stage events logged."
          rowKey={(r: any) => r.stage}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Closed-Won Trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No wins recorded."
          rowKey={(r: any) => String(r.month_start)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Cycles (latest 200)</h2>
        <DataTable
          rows={cycles}
          columns={cycleCols}
          emptyMessage="No cycles recorded."
          rowKey={(r: any) => r.id}
        />
      </section>
    </div>
  );
}
