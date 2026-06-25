import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_engineers: number;
  total_hours: number;
  avg_fairness: number;
  critical_count: number;
  high_count: number;
  elevated_count: number;
};

type RotationRow = {
  id: string;
  engineer_name: string;
  engineer_region: string;
  rotation_month: string;
  weekday_hours: number;
  weekend_hours: number;
  night_hours: number;
  total_hours: number;
  overload_signal: string;
  fairness_score: number;
  status: string;
};

type RegionRow = {
  engineer_region: string;
  engineer_count: number;
  total_hours: number;
  avg_fairness: number;
  weekend_share: number;
};

type SignalRow = {
  overload_signal: string;
  engineer_count: number;
  avg_total_hours: number;
  avg_fairness: number;
};

type ActionRow = {
  id: string;
  engineer_name: string;
  action_type: string;
  triggered_by: string;
  hours_shifted: number;
  target_engineer: string | null;
  outcome: string;
  notes: string | null;
  created_at: string;
};

type OutlierRow = {
  engineer_name: string;
  engineer_region: string;
  total_hours: number;
  fairness_score: number;
  overload_signal: string;
  gap_from_median: number;
};

type OutcomeRow = {
  action_type: string;
  outcome: string;
  count: number;
  total_hours_shifted: number;
};

type OverloadedRow = {
  engineer_name: string;
  engineer_region: string;
  total_hours: number;
  weekend_hours: number;
  night_hours: number;
  overload_signal: string;
  fairness_score: number;
};

function fmtNum(v: unknown, digits = 2): string {
  const n = typeof v === 'number' ? v : Number(v ?? 0);
  if (!Number.isFinite(n)) return '0';
  return n.toLocaleString('en-IN', { minimumFractionDigits: digits, maximumFractionDigits: digits });
}

function fmtInt(v: unknown): string {
  const n = typeof v === 'number' ? v : Number(v ?? 0);
  return Number.isFinite(n) ? n.toLocaleString('en-IN') : '0';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, listRes, regionRes, signalRes, actionsRes, outliersRes, outcomesRes, overloadedRes] = await Promise.all([
    supabase.rpc('founder_on_call_rotation_summary_r2702'),
    supabase.rpc('founder_on_call_rotation_list_r2702'),
    supabase.rpc('founder_on_call_region_breakdown_r2702'),
    supabase.rpc('founder_on_call_overload_signal_dist_r2702'),
    supabase.rpc('founder_on_call_rebalance_actions_r2702'),
    supabase.rpc('founder_on_call_fairness_outliers_r2702'),
    supabase.rpc('founder_on_call_action_outcomes_r2702'),
    supabase.rpc('founder_on_call_top_overloaded_r2702'),
  ]);

  const summary: SummaryRow = (summaryRes.data?.[0] as SummaryRow) ?? {
    total_engineers: 0,
    total_hours: 0,
    avg_fairness: 0,
    critical_count: 0,
    high_count: 0,
    elevated_count: 0,
  };
  const rotations: RotationRow[] = (listRes.data as RotationRow[]) ?? [];
  const regions: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const signals: SignalRow[] = (signalRes.data as SignalRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const outliers: OutlierRow[] = (outliersRes.data as OutlierRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomesRes.data as OutcomeRow[]) ?? [];
  const overloaded: OverloadedRow[] = (overloadedRes.data as OverloadedRow[]) ?? [];

  const kpis = [
    { label: 'Engineers', value: fmtInt(summary.total_engineers) },
    { label: 'Total Hours', value: fmtNum(summary.total_hours, 1) },
    { label: 'Avg Fairness', value: fmtNum(summary.avg_fairness, 1) },
    { label: 'Critical', value: fmtInt(summary.critical_count) },
    { label: 'High', value: fmtInt(summary.high_count) },
    { label: 'Elevated', value: fmtInt(summary.elevated_count) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>Engineer Monthly On-Call Rotation Fairness</h1>
        <p style={{ color: '#555', margin: '6px 0 0 0' }}>
          Track engineer hours, weekend load, overload signals, fairness scores & rebalance actions month over month.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px', marginBottom: '28px' }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e3e3e3', borderRadius: '8px', padding: '14px 16px', background: '#fafafa' }}>
            <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{k.label}</div>
            <div style={{ fontSize: '22px', fontWeight: 700, marginTop: '4px' }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Engineer Rotation Roster</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '10px' }}>
          Sorted by fairness ascending — lowest-scored engineers carry the heaviest unfair load.
        </p>
        <DataTable
          rows={rotations}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: RotationRow) => r.engineer_name },
            { key: 'engineer_region', header: 'Region', render: (r: RotationRow) => r.engineer_region },
            { key: 'rotation_month', header: 'Month', render: (r: RotationRow) => r.rotation_month },
            { key: 'weekday_hours', header: 'Weekday Hrs', render: (r: RotationRow) => fmtNum(r.weekday_hours, 1) },
            { key: 'weekend_hours', header: 'Weekend Hrs', render: (r: RotationRow) => fmtNum(r.weekend_hours, 1) },
            { key: 'night_hours', header: 'Night Hrs', render: (r: RotationRow) => fmtNum(r.night_hours, 1) },
            { key: 'total_hours', header: 'Total Hrs', render: (r: RotationRow) => fmtNum(r.total_hours, 1) },
            { key: 'overload_signal', header: 'Signal', render: (r: RotationRow) => r.overload_signal },
            { key: 'fairness_score', header: 'Fairness', render: (r: RotationRow) => fmtNum(r.fairness_score, 1) },
            { key: 'status', header: 'Status', render: (r: RotationRow) => r.status },
          ]}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Region Breakdown</h2>
        <DataTable
          rows={regions}
          rowKey={(r, i) => String(r.engineer_region ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_region', header: 'Region', render: (r: RegionRow) => r.engineer_region },
            { key: 'engineer_count', header: 'Engineers', render: (r: RegionRow) => fmtInt(r.engineer_count) },
            { key: 'total_hours', header: 'Total Hrs', render: (r: RegionRow) => fmtNum(r.total_hours, 1) },
            { key: 'avg_fairness', header: 'Avg Fairness', render: (r: RegionRow) => fmtNum(r.avg_fairness, 1) },
            { key: 'weekend_share', header: 'Weekend Share %', render: (r: RegionRow) => fmtNum(r.weekend_share, 2) },
          ]}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Overload Signal Distribution</h2>
        <DataTable
          rows={signals}
          rowKey={(r, i) => String(r.overload_signal ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'overload_signal', header: 'Signal', render: (r: SignalRow) => r.overload_signal },
            { key: 'engineer_count', header: 'Engineers', render: (r: SignalRow) => fmtInt(r.engineer_count) },
            { key: 'avg_total_hours', header: 'Avg Total Hrs', render: (r: SignalRow) => fmtNum(r.avg_total_hours, 1) },
            { key: 'avg_fairness', header: 'Avg Fairness', render: (r: SignalRow) => fmtNum(r.avg_fairness, 1) },
          ]}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Fairness Outliers (Below Median)</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '10px' }}>
          Engineers whose fairness score sits below the team median — gap is shown vs median.
        </p>
        <DataTable
          rows={outliers}
          rowKey={(r, i) => String(r.engineer_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: OutlierRow) => r.engineer_name },
            { key: 'engineer_region', header: 'Region', render: (r: OutlierRow) => r.engineer_region },
            { key: 'total_hours', header: 'Total Hrs', render: (r: OutlierRow) => fmtNum(r.total_hours, 1) },
            { key: 'fairness_score', header: 'Fairness', render: (r: OutlierRow) => fmtNum(r.fairness_score, 1) },
            { key: 'overload_signal', header: 'Signal', render: (r: OutlierRow) => r.overload_signal },
            { key: 'gap_from_median', header: 'Gap vs Median', render: (r: OutlierRow) => fmtNum(r.gap_from_median, 2) },
          ]}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Top Overloaded Engineers</h2>
        <DataTable
          rows={overloaded}
          rowKey={(r, i) => String(r.engineer_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: OverloadedRow) => r.engineer_name },
            { key: 'engineer_region', header: 'Region', render: (r: OverloadedRow) => r.engineer_region },
            { key: 'total_hours', header: 'Total Hrs', render: (r: OverloadedRow) => fmtNum(r.total_hours, 1) },
            { key: 'weekend_hours', header: 'Weekend Hrs', render: (r: OverloadedRow) => fmtNum(r.weekend_hours, 1) },
            { key: 'night_hours', header: 'Night Hrs', render: (r: OverloadedRow) => fmtNum(r.night_hours, 1) },
            { key: 'overload_signal', header: 'Signal', render: (r: OverloadedRow) => r.overload_signal },
            { key: 'fairness_score', header: 'Fairness', render: (r: OverloadedRow) => fmtNum(r.fairness_score, 1) },
          ]}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Rebalance Actions Ledger</h2>
        <DataTable
          rows={actions}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ActionRow) => r.engineer_name },
            { key: 'action_type', header: 'Action', render: (r: ActionRow) => r.action_type },
            { key: 'triggered_by', header: 'Triggered By', render: (r: ActionRow) => r.triggered_by },
            { key: 'hours_shifted', header: 'Hrs Shifted', render: (r: ActionRow) => fmtNum(r.hours_shifted, 1) },
            { key: 'target_engineer', header: 'Target', render: (r: ActionRow) => r.target_engineer ?? '—' },
            { key: 'outcome', header: 'Outcome', render: (r: ActionRow) => r.outcome },
            { key: 'notes', header: 'Notes', render: (r: ActionRow) => r.notes ?? '—' },
            { key: 'created_at', header: 'When', render: (r: ActionRow) => new Date(r.created_at).toLocaleString('en-IN') },
          ]}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Action Outcomes Roll-Up</h2>
        <DataTable
          rows={outcomes}
          rowKey={(r, i) => `${r.action_type}-${r.outcome}-${i}`}
          emptyMessage="No data"
          columns={[
            { key: 'action_type', header: 'Action Type', render: (r: OutcomeRow) => r.action_type },
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'count', header: 'Count', render: (r: OutcomeRow) => fmtInt(r.count) },
            { key: 'total_hours_shifted', header: 'Hrs Shifted', render: (r: OutcomeRow) => fmtNum(r.total_hours_shifted, 1) },
          ]}
        />
      </section>
    </main>
  );
}
