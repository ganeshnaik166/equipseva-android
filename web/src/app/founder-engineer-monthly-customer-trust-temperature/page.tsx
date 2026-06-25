import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_pairs: number;
  blazing_pairs: number;
  frozen_pairs: number;
  avg_score: number;
  avg_delta: number;
  net_promoter_avg: number;
};

type Pair = {
  id: string;
  engineer_name: string;
  engineer_tier: string;
  customer_org: string;
  customer_segment: string;
  trust_score: number;
  trust_band: string;
  score_delta: number;
  primary_signal: string;
  jobs_completed: number;
  nps_score: number | null;
};

type BandRow = {
  trust_band: string;
  pair_count: number;
  avg_score: number;
  avg_delta: number;
};

type SignalRow = {
  primary_signal: string;
  pair_count: number;
  avg_delta: number;
  worst_score: number;
};

type Intervention = {
  id: string;
  engineer_name: string;
  customer_org: string;
  intervention_type: string;
  intervention_status: string;
  owner_role: string;
  outcome_band: string;
  outcome_note: string;
  trust_lift: number;
  scheduled_at: string;
};

type Mover = {
  engineer_name: string;
  customer_org: string;
  prior_score: number;
  trust_score: number;
  score_delta: number;
  direction: string;
};

type Segment = {
  customer_segment: string;
  pair_count: number;
  avg_score: number;
  blazing_count: number;
  frozen_count: number;
};

type Outcome = {
  intervention_type: string;
  total: number;
  recovered: number;
  improved: number;
  flat: number;
  worsened: number;
  pending: number;
  avg_lift: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, pairsRes, bandRes, signalRes, intvRes, moverRes, segRes, outcomeRes] = await Promise.all([
    supabase.rpc('founder_trust_temperature_kpis_r2722'),
    supabase.rpc('founder_trust_temperature_pairs_r2722'),
    supabase.rpc('founder_trust_temperature_band_dist_r2722'),
    supabase.rpc('founder_trust_temperature_signals_r2722'),
    supabase.rpc('founder_trust_temperature_interventions_r2722'),
    supabase.rpc('founder_trust_temperature_top_movers_r2722'),
    supabase.rpc('founder_trust_temperature_segment_heatmap_r2722'),
    supabase.rpc('founder_trust_temperature_outcomes_r2722'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_pairs: 0,
    blazing_pairs: 0,
    frozen_pairs: 0,
    avg_score: 0,
    avg_delta: 0,
    net_promoter_avg: 0,
  };
  const pairs: Pair[] = (pairsRes.data as Pair[]) ?? [];
  const bands: BandRow[] = (bandRes.data as BandRow[]) ?? [];
  const signals: SignalRow[] = (signalRes.data as SignalRow[]) ?? [];
  const interventions: Intervention[] = (intvRes.data as Intervention[]) ?? [];
  const movers: Mover[] = (moverRes.data as Mover[]) ?? [];
  const segments: Segment[] = (segRes.data as Segment[]) ?? [];
  const outcomes: Outcome[] = (outcomeRes.data as Outcome[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Trust Temperature</h1>
        <p className="text-sm text-gray-600">
          Pair-level trust scoring across engineer &amp; customer with signals, deltas &amp;
          interventions. Cold pairs (score &lt; 50) get escalation; blazing pairs (score &gt;= 90)
          get recognition.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-4">
        <KpiCard label="Total Pairs" value={kpi.total_pairs} />
        <KpiCard label="Blazing" value={kpi.blazing_pairs} tone="hot" />
        <KpiCard label="Cold/Frozen" value={kpi.frozen_pairs} tone="cold" />
        <KpiCard label="Avg Score" value={kpi.avg_score} />
        <KpiCard label="Avg Delta" value={kpi.avg_delta} />
        <KpiCard label="Avg NPS" value={kpi.net_promoter_avg} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer × Customer Trust Pairs</h2>
        <DataTable
          rows={pairs}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Pair) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: Pair) => r.engineer_tier },
            { key: 'customer_org', header: 'Customer', render: (r: Pair) => r.customer_org },
            { key: 'customer_segment', header: 'Segment', render: (r: Pair) => r.customer_segment },
            { key: 'trust_score', header: 'Score', render: (r: Pair) => r.trust_score.toFixed(2) },
            { key: 'trust_band', header: 'Band', render: (r: Pair) => r.trust_band },
            { key: 'score_delta', header: 'Delta', render: (r: Pair) => r.score_delta.toFixed(2) },
            { key: 'primary_signal', header: 'Signal', render: (r: Pair) => r.primary_signal },
            { key: 'jobs_completed', header: 'Jobs', render: (r: Pair) => String(r.jobs_completed) },
            { key: 'nps_score', header: 'NPS', render: (r: Pair) => (r.nps_score == null ? '-' : String(r.nps_score)) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Pair, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Trust Band Distribution</h2>
        <DataTable
          rows={bands}
          columns={[
            { key: 'trust_band', header: 'Band', render: (r: BandRow) => r.trust_band },
            { key: 'pair_count', header: 'Pairs', render: (r: BandRow) => String(r.pair_count) },
            { key: 'avg_score', header: 'Avg Score', render: (r: BandRow) => Number(r.avg_score).toFixed(2) },
            { key: 'avg_delta', header: 'Avg Delta', render: (r: BandRow) => Number(r.avg_delta).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: BandRow, i: number) => String(r.trust_band ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Primary Signal Breakdown</h2>
        <DataTable
          rows={signals}
          columns={[
            { key: 'primary_signal', header: 'Signal', render: (r: SignalRow) => r.primary_signal },
            { key: 'pair_count', header: 'Pairs', render: (r: SignalRow) => String(r.pair_count) },
            { key: 'avg_delta', header: 'Avg Delta', render: (r: SignalRow) => Number(r.avg_delta).toFixed(2) },
            { key: 'worst_score', header: 'Worst', render: (r: SignalRow) => Number(r.worst_score).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SignalRow, i: number) => String(r.primary_signal ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Movers (largest absolute delta)</h2>
        <DataTable
          rows={movers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Mover) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: Mover) => r.customer_org },
            { key: 'prior_score', header: 'Prior', render: (r: Mover) => Number(r.prior_score).toFixed(2) },
            { key: 'trust_score', header: 'Now', render: (r: Mover) => Number(r.trust_score).toFixed(2) },
            { key: 'score_delta', header: 'Delta', render: (r: Mover) => Number(r.score_delta).toFixed(2) },
            { key: 'direction', header: 'Dir', render: (r: Mover) => r.direction },
          ]}
          emptyMessage="No data"
          rowKey={(r: Mover, i: number) => `${r.engineer_name}-${r.customer_org}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Customer Segment Heatmap</h2>
        <DataTable
          rows={segments}
          columns={[
            { key: 'customer_segment', header: 'Segment', render: (r: Segment) => r.customer_segment },
            { key: 'pair_count', header: 'Pairs', render: (r: Segment) => String(r.pair_count) },
            { key: 'avg_score', header: 'Avg Score', render: (r: Segment) => Number(r.avg_score).toFixed(2) },
            { key: 'blazing_count', header: 'Blazing', render: (r: Segment) => String(r.blazing_count) },
            { key: 'frozen_count', header: 'Cold/Frozen', render: (r: Segment) => String(r.frozen_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Segment, i: number) => String(r.customer_segment ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Interventions</h2>
        <DataTable
          rows={interventions}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Intervention) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: Intervention) => r.customer_org },
            { key: 'intervention_type', header: 'Type', render: (r: Intervention) => r.intervention_type },
            { key: 'intervention_status', header: 'Status', render: (r: Intervention) => r.intervention_status },
            { key: 'owner_role', header: 'Owner', render: (r: Intervention) => r.owner_role },
            { key: 'outcome_band', header: 'Outcome', render: (r: Intervention) => r.outcome_band },
            { key: 'outcome_note', header: 'Note', render: (r: Intervention) => r.outcome_note },
            { key: 'trust_lift', header: 'Lift', render: (r: Intervention) => Number(r.trust_lift).toFixed(2) },
            { key: 'scheduled_at', header: 'Scheduled', render: (r: Intervention) => new Date(r.scheduled_at).toLocaleDateString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Intervention, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Intervention Outcomes Rollup</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'intervention_type', header: 'Type', render: (r: Outcome) => r.intervention_type },
            { key: 'total', header: 'Total', render: (r: Outcome) => String(r.total) },
            { key: 'recovered', header: 'Recovered', render: (r: Outcome) => String(r.recovered) },
            { key: 'improved', header: 'Improved', render: (r: Outcome) => String(r.improved) },
            { key: 'flat', header: 'Flat', render: (r: Outcome) => String(r.flat) },
            { key: 'worsened', header: 'Worsened', render: (r: Outcome) => String(r.worsened) },
            { key: 'pending', header: 'Pending', render: (r: Outcome) => String(r.pending) },
            { key: 'avg_lift', header: 'Avg Lift', render: (r: Outcome) => Number(r.avg_lift).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Outcome, i: number) => String(r.intervention_type ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: number | string; tone?: 'hot' | 'cold' }) {
  const toneClass =
    tone === 'hot'
      ? 'border-red-400 bg-red-50'
      : tone === 'cold'
      ? 'border-blue-400 bg-blue-50'
      : 'border-gray-200 bg-white';
  return (
    <div className={`rounded-lg border p-4 ${toneClass}`}>
      <div className="text-xs uppercase text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}
