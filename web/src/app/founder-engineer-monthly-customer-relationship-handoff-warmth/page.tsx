import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  active_pairs: number;
  glowing_pairs: number;
  at_risk_pairs: number;
  avg_csat: number;
  avg_handoff_score: number;
  clean_handoffs: number;
  dropped_handoffs: number;
};

type Signal = {
  id: string;
  month_start: string;
  engineer_code: string;
  engineer_name: string;
  customer_code: string;
  customer_name: string;
  prior_engineer_name: string | null;
  city: string;
  visits_this_month: number;
  csat_avg: number;
  on_time_pct: number;
  handoff_quality_score: number;
  warmth_bucket: string;
  continuity_status: string;
  notes: string | null;
};

type Handoff = {
  id: string;
  occurred_on: string;
  customer_code: string;
  from_engineer_code: string | null;
  to_engineer_code: string;
  handoff_kind: string;
  outcome: string;
  warmth_delta: number;
  duration_minutes: number;
  notes: string | null;
};

type BucketRow = { warmth_bucket: string; pair_count: number; avg_csat: number; avg_handoff: number };
type ContinuityRow = { continuity_status: string; pair_count: number; avg_visits: number; avg_on_time: number };
type TopEngRow = { engineer_code: string; engineer_name: string; pairs: number; avg_csat: number; avg_handoff: number };
type AtRiskRow = {
  customer_code: string;
  customer_name: string;
  engineer_name: string;
  prior_engineer_name: string | null;
  city: string;
  csat_avg: number;
  warmth_bucket: string;
  notes: string | null;
};
type OutcomeRow = { outcome: string; event_count: number; avg_delta: number; avg_duration: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpi, signals, handoffs, buckets, continuity, topEng, atRisk, outcomes] = await Promise.all([
    supabase.rpc('founder_r2854_kpis'),
    supabase.rpc('founder_r2854_warmth_signals'),
    supabase.rpc('founder_r2854_handoff_events'),
    supabase.rpc('founder_r2854_by_warmth_bucket'),
    supabase.rpc('founder_r2854_by_continuity'),
    supabase.rpc('founder_r2854_top_engineers'),
    supabase.rpc('founder_r2854_at_risk_customers'),
    supabase.rpc('founder_r2854_handoff_outcomes'),
  ]);

  const k: KpiRow = (kpi.data?.[0] ?? {
    active_pairs: 0,
    glowing_pairs: 0,
    at_risk_pairs: 0,
    avg_csat: 0,
    avg_handoff_score: 0,
    clean_handoffs: 0,
    dropped_handoffs: 0,
  }) as KpiRow;

  const signalRows: Signal[] = (signals.data ?? []) as Signal[];
  const handoffRows: Handoff[] = (handoffs.data ?? []) as Handoff[];
  const bucketRows: BucketRow[] = (buckets.data ?? []) as BucketRow[];
  const continuityRows: ContinuityRow[] = (continuity.data ?? []) as ContinuityRow[];
  const topEngRows: TopEngRow[] = (topEng.data ?? []) as TopEngRow[];
  const atRiskRows: AtRiskRow[] = (atRisk.data ?? []) as AtRiskRow[];
  const outcomeRows: OutcomeRow[] = (outcomes.data ?? []) as OutcomeRow[];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Relationship Handoff Warmth</h1>
        <p className="text-sm text-gray-600">
          Round r2854 — engineer × customer × prior engineer × warmth signal × continuity × outcome.
          Track CSAT &gt;= 4.5 as glowing, &lt;= 3.0 as at-risk.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Active pairs" value={k.active_pairs} />
        <Kpi label="Glowing" value={k.glowing_pairs} />
        <Kpi label="At risk" value={k.at_risk_pairs} />
        <Kpi label="Avg CSAT" value={k.avg_csat} />
        <Kpi label="Avg handoff score" value={k.avg_handoff_score} />
        <Kpi label="Clean handoffs" value={k.clean_handoffs} />
        <Kpi label="Dropped handoffs" value={k.dropped_handoffs} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Warmth signals (engineer × customer)</h2>
        <DataTable
          rows={signalRows}
          columns={[
            { key: 'month_start', header: 'Month', render: (r: Signal) => r.month_start },
            { key: 'engineer_name', header: 'Engineer', render: (r: Signal) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: Signal) => r.customer_name },
            { key: 'prior_engineer_name', header: 'Prior eng', render: (r: Signal) => r.prior_engineer_name ?? '—' },
            { key: 'city', header: 'City', render: (r: Signal) => r.city },
            { key: 'visits_this_month', header: 'Visits', render: (r: Signal) => String(r.visits_this_month) },
            { key: 'csat_avg', header: 'CSAT', render: (r: Signal) => r.csat_avg.toFixed(2) },
            { key: 'on_time_pct', header: 'On-time %', render: (r: Signal) => r.on_time_pct.toFixed(1) },
            { key: 'handoff_quality_score', header: 'Handoff', render: (r: Signal) => r.handoff_quality_score.toFixed(1) },
            { key: 'warmth_bucket', header: 'Warmth', render: (r: Signal) => r.warmth_bucket },
            { key: 'continuity_status', header: 'Continuity', render: (r: Signal) => r.continuity_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Signal, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Handoff events</h2>
        <DataTable
          rows={handoffRows}
          columns={[
            { key: 'occurred_on', header: 'Date', render: (r: Handoff) => r.occurred_on },
            { key: 'customer_code', header: 'Customer', render: (r: Handoff) => r.customer_code },
            { key: 'from_engineer_code', header: 'From', render: (r: Handoff) => r.from_engineer_code ?? '—' },
            { key: 'to_engineer_code', header: 'To', render: (r: Handoff) => r.to_engineer_code },
            { key: 'handoff_kind', header: 'Kind', render: (r: Handoff) => r.handoff_kind },
            { key: 'outcome', header: 'Outcome', render: (r: Handoff) => r.outcome },
            { key: 'warmth_delta', header: 'Delta', render: (r: Handoff) => r.warmth_delta.toFixed(2) },
            { key: 'duration_minutes', header: 'Mins', render: (r: Handoff) => String(r.duration_minutes) },
            { key: 'notes', header: 'Notes', render: (r: Handoff) => r.notes ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Handoff, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">By warmth bucket</h2>
          <DataTable
            rows={bucketRows}
            columns={[
              { key: 'warmth_bucket', header: 'Bucket', render: (r: BucketRow) => r.warmth_bucket },
              { key: 'pair_count', header: 'Pairs', render: (r: BucketRow) => String(r.pair_count) },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: BucketRow) => Number(r.avg_csat).toFixed(2) },
              { key: 'avg_handoff', header: 'Avg handoff', render: (r: BucketRow) => Number(r.avg_handoff).toFixed(2) },
            ]}
            emptyMessage="No data"
            rowKey={(r: BucketRow, i: number) => String(r.warmth_bucket ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">By continuity status</h2>
          <DataTable
            rows={continuityRows}
            columns={[
              { key: 'continuity_status', header: 'Status', render: (r: ContinuityRow) => r.continuity_status },
              { key: 'pair_count', header: 'Pairs', render: (r: ContinuityRow) => String(r.pair_count) },
              { key: 'avg_visits', header: 'Avg visits', render: (r: ContinuityRow) => Number(r.avg_visits).toFixed(2) },
              { key: 'avg_on_time', header: 'Avg on-time %', render: (r: ContinuityRow) => Number(r.avg_on_time).toFixed(1) },
            ]}
            emptyMessage="No data"
            rowKey={(r: ContinuityRow, i: number) => String(r.continuity_status ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top engineers by handoff quality</h2>
        <DataTable
          rows={topEngRows}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: TopEngRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: TopEngRow) => r.engineer_name },
            { key: 'pairs', header: 'Pairs', render: (r: TopEngRow) => String(r.pairs) },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: TopEngRow) => Number(r.avg_csat).toFixed(2) },
            { key: 'avg_handoff', header: 'Avg handoff', render: (r: TopEngRow) => Number(r.avg_handoff).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopEngRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-risk customers (CSAT &lt;= 3.5 or cool/cold)</h2>
        <DataTable
          rows={atRiskRows}
          columns={[
            { key: 'customer_code', header: 'Code', render: (r: AtRiskRow) => r.customer_code },
            { key: 'customer_name', header: 'Customer', render: (r: AtRiskRow) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: AtRiskRow) => r.engineer_name },
            { key: 'prior_engineer_name', header: 'Prior', render: (r: AtRiskRow) => r.prior_engineer_name ?? '—' },
            { key: 'city', header: 'City', render: (r: AtRiskRow) => r.city },
            { key: 'csat_avg', header: 'CSAT', render: (r: AtRiskRow) => Number(r.csat_avg).toFixed(2) },
            { key: 'warmth_bucket', header: 'Warmth', render: (r: AtRiskRow) => r.warmth_bucket },
            { key: 'notes', header: 'Notes', render: (r: AtRiskRow) => r.notes ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRiskRow, i: number) => String(r.customer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Handoff outcomes</h2>
        <DataTable
          rows={outcomeRows}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'event_count', header: 'Events', render: (r: OutcomeRow) => String(r.event_count) },
            { key: 'avg_delta', header: 'Avg warmth delta', render: (r: OutcomeRow) => Number(r.avg_delta).toFixed(2) },
            { key: 'avg_duration', header: 'Avg mins', render: (r: OutcomeRow) => Number(r.avg_duration).toFixed(1) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value ?? '—'}</div>
    </div>
  );
}
