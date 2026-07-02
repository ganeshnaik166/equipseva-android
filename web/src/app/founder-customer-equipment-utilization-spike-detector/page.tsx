import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(v: number | null | undefined): string {
  if (v == null) return '-';
  return '₹' + Number(v).toLocaleString('en-IN');
}

function fmtPct(v: number | null | undefined): string {
  if (v == null) return '-';
  return Number(v).toFixed(1) + '%';
}

function fmtDate(v: string | null | undefined): string {
  if (!v) return '-';
  try {
    return new Date(v).toLocaleDateString('en-IN');
  } catch {
    return String(v);
  }
}

function fmtDateTime(v: string | null | undefined): string {
  if (!v) return '-';
  try {
    return new Date(v).toLocaleString('en-IN');
  } catch {
    return String(v);
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [spikes, actions, topUplift, funnel, kindSummary, weekCal, monthlyTrend] = await Promise.all([
    supabase.rpc('list_spikes_r2440'),
    supabase.rpc('list_action_log_r2440'),
    supabase.rpc('top_revenue_uplift_r2440'),
    supabase.rpc('status_funnel_r2440'),
    supabase.rpc('equipment_kind_summary_r2440'),
    supabase.rpc('this_week_action_calendar_r2440'),
    supabase.rpc('monthly_spike_trend_r2440'),
  ]);

  const spikesRows = (spikes.data ?? []) as any[];
  const actionsRows = (actions.data ?? []) as any[];
  const topUpliftRows = (topUplift.data ?? []) as any[];
  const funnelRows = (funnel.data ?? []) as any[];
  const kindRows = (kindSummary.data ?? []) as any[];
  const weekRows = (weekCal.data ?? []) as any[];
  const monthRows = (monthlyTrend.data ?? []) as any[];

  const spikesCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '-' },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'baseline_usage_pct', header: 'Baseline', render: (r: any) => fmtPct(r.baseline_usage_pct) },
    { key: 'current_usage_pct', header: 'Current', render: (r: any) => fmtPct(r.current_usage_pct) },
    { key: 'delta_pct', header: 'Delta', render: (r: any) => fmtPct(r.delta_pct) },
    { key: 'observation_period_start', header: 'Period Start', render: (r: any) => fmtDate(r.observation_period_start) },
    { key: 'observation_period_end', header: 'Period End', render: (r: any) => fmtDate(r.observation_period_end) },
    { key: 'revenue_uplift_estimate_rupees', header: 'Uplift', render: (r: any) => fmtRupees(r.revenue_uplift_estimate_rupees) },
    { key: 'cross_sell_hint', header: 'Cross-sell Hint', render: (r: any) => r.cross_sell_hint ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'action_count', header: 'Actions', render: (r: any) => String(r.action_count ?? 0) },
    { key: 'last_action_at', header: 'Last Action', render: (r: any) => fmtDateTime(r.last_action_at) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDateTime(r.observed_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '-' },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    { key: 'outcome_notes', header: 'Outcome Notes', render: (r: any) => r.outcome_notes ?? '-' },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDateTime(r.follow_up_at) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topUpliftCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '-' },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'delta_pct', header: 'Delta', render: (r: any) => fmtPct(r.delta_pct) },
    { key: 'revenue_uplift_estimate_rupees', header: 'Uplift', render: (r: any) => fmtRupees(r.revenue_uplift_estimate_rupees) },
    { key: 'cross_sell_hint', header: 'Cross-sell Hint', render: (r: any) => r.cross_sell_hint ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'spike_count', header: 'Spikes', render: (r: any) => String(r.spike_count ?? 0) },
    { key: 'total_uplift_rupees', header: 'Total Uplift', render: (r: any) => fmtRupees(r.total_uplift_rupees) },
    { key: 'avg_delta_pct', header: 'Avg Delta', render: (r: any) => fmtPct(r.avg_delta_pct) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'spike_count', header: 'Spikes', render: (r: any) => String(r.spike_count ?? 0) },
    { key: 'avg_baseline_pct', header: 'Avg Baseline', render: (r: any) => fmtPct(r.avg_baseline_pct) },
    { key: 'avg_current_pct', header: 'Avg Current', render: (r: any) => fmtPct(r.avg_current_pct) },
    { key: 'avg_delta_pct', header: 'Avg Delta', render: (r: any) => fmtPct(r.avg_delta_pct) },
    { key: 'total_uplift_rupees', header: 'Total Uplift', render: (r: any) => fmtRupees(r.total_uplift_rupees) },
  ];

  const weekCols: Column<any>[] = [
    { key: 'follow_up_at', header: 'Due', render: (r: any) => fmtDateTime(r.follow_up_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '-' },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    { key: 'hours_until_due', header: 'Hours Until Due', render: (r: any) => r.hours_until_due != null ? String(r.hours_until_due) : '-' },
  ];

  const monthCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'spike_count', header: 'Spikes', render: (r: any) => String(r.spike_count ?? 0) },
    { key: 'avg_delta_pct', header: 'Avg Delta', render: (r: any) => fmtPct(r.avg_delta_pct) },
    { key: 'total_uplift_rupees', header: 'Total Uplift', render: (r: any) => fmtRupees(r.total_uplift_rupees) },
    { key: 'won_count', header: 'Won', render: (r: any) => String(r.won_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Equipment Utilization Spike Detector
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round r2440 — usage spike vs baseline, delta %, revenue uplift, cross-sell hint, owner.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Revenue Uplift Opportunities</h2>
        <DataTable
          rows={topUpliftRows}
          columns={topUpliftCols}
          emptyMessage="No open uplift opportunities."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No spikes yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Equipment Kind Summary</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No equipment kind data yet."
          rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>This Week Action Calendar</h2>
        <DataTable
          rows={weekRows}
          columns={weekCols}
          emptyMessage="No follow-ups due in the next 7 days."
          rowKey={(r: any, i: number) => String(r.spike_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Spike Trend</h2>
        <DataTable
          rows={monthRows}
          columns={monthCols}
          emptyMessage="No monthly trend yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Spikes</h2>
        <DataTable
          rows={spikesRows}
          columns={spikesCols}
          emptyMessage="No spikes detected yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Log</h2>
        <DataTable
          rows={actionsRows}
          columns={actionsCols}
          emptyMessage="No actions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
