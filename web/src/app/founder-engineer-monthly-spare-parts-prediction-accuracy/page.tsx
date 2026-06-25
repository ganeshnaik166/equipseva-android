import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_engineers: number;
  avg_hit_rate_pct: number;
  total_miss_cost_rupees: number;
  open_calibration_actions: number;
};

type LedgerRow = {
  engineer_name: string;
  engineer_tier: string;
  predicted_parts_count: number;
  actual_parts_used: number;
  hit_rate_pct: number;
  miss_kind: string;
  miss_cost_rupees: number;
  calibration_action: string;
  calibration_due_date: string;
};

type AggregateRow = {
  miss_kind: string;
  affected_engineers: number;
  total_miss_cost_rupees: number;
  median_hit_rate_pct: number;
  recommended_action: string;
  improvement_target_pct: number;
  closed: boolean;
};

type OffenderRow = {
  engineer_name: string;
  engineer_tier: string;
  hit_rate_pct: number;
  miss_cost_rupees: number;
  calibration_action: string;
};

type TierRow = {
  engineer_tier: string;
  engineers_count: number;
  avg_hit_rate_pct: number;
  total_miss_cost_rupees: number;
};

type QueueRow = {
  engineer_name: string;
  calibration_action: string;
  calibration_due_date: string;
  miss_kind: string;
  miss_cost_rupees: number;
};

function rupees(n: number | null | undefined): string {
  const v = typeof n === 'number' ? n : 0;
  return '₹' + v.toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  const v = typeof n === 'number' ? n : 0;
  return v.toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, ledgerRes, aggRes, offRes, tierRes, queueRes, openAggRes] = await Promise.all([
    supabase.rpc('founder_r2726_kpis'),
    supabase.rpc('founder_r2726_engineer_ledger'),
    supabase.rpc('founder_r2726_miss_kind_aggregates'),
    supabase.rpc('founder_r2726_top_offenders'),
    supabase.rpc('founder_r2726_tier_rollup'),
    supabase.rpc('founder_r2726_calibration_queue'),
    supabase.rpc('founder_r2726_open_aggregates'),
  ]);

  const kpi: Kpi = (kpisRes.data && kpisRes.data[0]) || {
    total_engineers: 0,
    avg_hit_rate_pct: 0,
    total_miss_cost_rupees: 0,
    open_calibration_actions: 0,
  };
  const ledger: LedgerRow[] = ledgerRes.data || [];
  const aggregates: AggregateRow[] = aggRes.data || [];
  const offenders: OffenderRow[] = offRes.data || [];
  const tiers: TierRow[] = tierRes.data || [];
  const queue: QueueRow[] = queueRes.data || [];
  const openAgg: AggregateRow[] = openAggRes.data || [];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
          Engineer Monthly Spare-Parts Prediction Accuracy
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Founder console r2726 — engineer × predicted × actual × hit rate × miss kind × calibration action.
          Flags engineers where hit rate &lt; 75% so calibration coaching can fire before the next month.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Engineers tracked" value={String(kpi.total_engineers)} />
        <KpiCard label="Avg hit rate" value={pct(kpi.avg_hit_rate_pct)} />
        <KpiCard label="Total miss cost" value={rupees(kpi.total_miss_cost_rupees)} />
        <KpiCard label="Open calibration actions" value={String(kpi.open_calibration_actions)} />
      </section>

      <Section title="Engineer ledger" subtitle="Per-engineer predicted vs actual with miss kind & calibration action.">
        <DataTable
          rows={ledger}
          rowKey={(r, i) => String(r.engineer_name + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: LedgerRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: LedgerRow) => r.engineer_tier },
            { key: 'predicted_parts_count', header: 'Predicted', render: (r: LedgerRow) => String(r.predicted_parts_count) },
            { key: 'actual_parts_used', header: 'Actual', render: (r: LedgerRow) => String(r.actual_parts_used) },
            { key: 'hit_rate_pct', header: 'Hit rate', render: (r: LedgerRow) => pct(r.hit_rate_pct) },
            { key: 'miss_kind', header: 'Miss kind', render: (r: LedgerRow) => r.miss_kind },
            { key: 'miss_cost_rupees', header: 'Miss cost', render: (r: LedgerRow) => rupees(r.miss_cost_rupees) },
            { key: 'calibration_action', header: 'Action', render: (r: LedgerRow) => r.calibration_action },
            { key: 'calibration_due_date', header: 'Due', render: (r: LedgerRow) => r.calibration_due_date },
          ]}
        />
      </Section>

      <Section title="Miss-kind aggregates" subtitle="Rolled up by failure mode — sorted by total miss cost descending.">
        <DataTable
          rows={aggregates}
          rowKey={(r, i) => String(r.miss_kind + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'miss_kind', header: 'Miss kind', render: (r: AggregateRow) => r.miss_kind },
            { key: 'affected_engineers', header: 'Engineers', render: (r: AggregateRow) => String(r.affected_engineers) },
            { key: 'total_miss_cost_rupees', header: 'Total cost', render: (r: AggregateRow) => rupees(r.total_miss_cost_rupees) },
            { key: 'median_hit_rate_pct', header: 'Median hit rate', render: (r: AggregateRow) => pct(r.median_hit_rate_pct) },
            { key: 'recommended_action', header: 'Action', render: (r: AggregateRow) => r.recommended_action },
            { key: 'improvement_target_pct', header: 'Target', render: (r: AggregateRow) => pct(r.improvement_target_pct) },
            { key: 'closed', header: 'Closed', render: (r: AggregateRow) => (r.closed ? 'yes' : 'no') },
          ]}
        />
      </Section>

      <Section title="Top offenders" subtitle="Engineers whose hit rate is below 75% — calibrate first.">
        <DataTable
          rows={offenders}
          rowKey={(r, i) => String(r.engineer_name + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: OffenderRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: OffenderRow) => r.engineer_tier },
            { key: 'hit_rate_pct', header: 'Hit rate', render: (r: OffenderRow) => pct(r.hit_rate_pct) },
            { key: 'miss_cost_rupees', header: 'Miss cost', render: (r: OffenderRow) => rupees(r.miss_cost_rupees) },
            { key: 'calibration_action', header: 'Action', render: (r: OffenderRow) => r.calibration_action },
          ]}
        />
      </Section>

      <Section title="Tier roll-up" subtitle="Average hit rate by engineer tier — gauges where the prediction model is weakest.">
        <DataTable
          rows={tiers}
          rowKey={(r, i) => String(r.engineer_tier + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_tier', header: 'Tier', render: (r: TierRow) => r.engineer_tier },
            { key: 'engineers_count', header: 'Engineers', render: (r: TierRow) => String(r.engineers_count) },
            { key: 'avg_hit_rate_pct', header: 'Avg hit rate', render: (r: TierRow) => pct(r.avg_hit_rate_pct) },
            { key: 'total_miss_cost_rupees', header: 'Total miss cost', render: (r: TierRow) => rupees(r.total_miss_cost_rupees) },
          ]}
        />
      </Section>

      <Section title="Calibration queue" subtitle="Open coaching, retrain, peer-shadow & tier-review actions ordered by due date.">
        <DataTable
          rows={queue}
          rowKey={(r, i) => String(r.engineer_name + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: QueueRow) => r.engineer_name },
            { key: 'calibration_action', header: 'Action', render: (r: QueueRow) => r.calibration_action },
            { key: 'calibration_due_date', header: 'Due', render: (r: QueueRow) => r.calibration_due_date },
            { key: 'miss_kind', header: 'Miss kind', render: (r: QueueRow) => r.miss_kind },
            { key: 'miss_cost_rupees', header: 'Miss cost', render: (r: QueueRow) => rupees(r.miss_cost_rupees) },
          ]}
        />
      </Section>

      <Section title="Open aggregates" subtitle="Miss-kind buckets still open — awaiting close-out.">
        <DataTable
          rows={openAgg}
          rowKey={(r, i) => String(r.miss_kind + '_' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'miss_kind', header: 'Miss kind', render: (r: AggregateRow) => r.miss_kind },
            { key: 'affected_engineers', header: 'Engineers', render: (r: AggregateRow) => String(r.affected_engineers) },
            { key: 'total_miss_cost_rupees', header: 'Total cost', render: (r: AggregateRow) => rupees(r.total_miss_cost_rupees) },
            { key: 'recommended_action', header: 'Action', render: (r: AggregateRow) => r.recommended_action },
            { key: 'improvement_target_pct', header: 'Target', render: (r: AggregateRow) => pct(r.improvement_target_pct) },
          ]}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#777', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>{title}</h2>
      {subtitle ? <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>{subtitle}</p> : null}
      {children}
    </section>
  );
}
