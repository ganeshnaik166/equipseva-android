import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Prediction = {
  id: string;
  customer_label: string;
  customer_segment: string;
  cohort_month: string;
  predicted_ltv_rupees: number;
  predicted_horizon_months: number;
  realized_to_date_rupees: number;
  months_elapsed: number;
  status: string;
  confidence_band: string;
  realized_pct_of_predicted_bps: number;
  predicted_on: string;
  prediction_model_version: string;
  last_realized_refresh_on: string | null;
  notes: string | null;
  created_at: string;
};

type AccuracyLog = {
  id: string;
  prediction_id: string;
  snapshot_on: string;
  months_elapsed_at_snap: number;
  expected_realized_rupees: number;
  actual_realized_rupees: number;
  variance_bps: number;
  accuracy_band: string;
  model_adjustment_note: string | null;
  adjusted_model_version: string | null;
  created_at: string;
};

type SegmentRow = {
  customer_segment: string;
  predictions_count: number;
  total_predicted_rupees: number;
  total_realized_rupees: number;
  realized_pct_of_predicted_bps: number;
  avg_predicted_rupees: number;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return `₹${v.toLocaleString('en-IN')}`;
}

function bpsToPct(bps: number | null | undefined) {
  const v = Number(bps ?? 0) / 100;
  return `${v.toFixed(2)}%`;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [predRes, summaryRes, segRes, logRes] = await Promise.all([
    sb.rpc('list_ltv_predictions_r2300'),
    sb.rpc('ltv_accuracy_summary_r2300'),
    sb.rpc('ltv_segment_breakdown_r2300'),
    sb.rpc('list_ltv_accuracy_log_r2300', { p_prediction_id: null }),
  ]);

  const predictions: Prediction[] = (predRes.data as Prediction[] | null) ?? [];
  const summary = ((summaryRes.data as any[] | null) ?? [])[0] ?? {
    total_predictions: 0,
    active_predictions: 0,
    churned_predictions: 0,
    total_predicted_rupees: 0,
    total_realized_rupees: 0,
    realized_pct_of_predicted_bps: 0,
    snapshots_logged: 0,
    on_track_snaps: 0,
    under_snaps: 0,
    over_snaps: 0,
    avg_variance_bps: 0,
  };
  const segments: SegmentRow[] = (segRes.data as SegmentRow[] | null) ?? [];
  const logs: AccuracyLog[] = (logRes.data as AccuracyLog[] | null) ?? [];

  const predCols: Column<Prediction>[] = [
    { key: 'label', header: 'Customer', render: (r) => (
      <div>
        <div className="font-medium">{r.customer_label}</div>
        <div className="text-xs text-[var(--color-muted)]">{r.customer_segment}</div>
      </div>
    ) },
    { key: 'cohort', header: 'Cohort', render: (r) => <span className="text-xs">{r.cohort_month}</span> },
    { key: 'predicted', header: 'Predicted LTV', render: (r) => (
      <div>
        <div dangerouslySetInnerHTML={{ __html: rupees(r.predicted_ltv_rupees) }} />
        <div className="text-xs text-[var(--color-muted)]">over {r.predicted_horizon_months} mo</div>
      </div>
    ) },
    { key: 'realized', header: 'Realized to date', render: (r) => (
      <div>
        <div dangerouslySetInnerHTML={{ __html: rupees(r.realized_to_date_rupees) }} />
        <div className="text-xs text-[var(--color-muted)]">{r.months_elapsed} mo elapsed</div>
      </div>
    ) },
    { key: 'pct', header: '% of predicted', render: (r) => {
      const pct = r.realized_pct_of_predicted_bps / 100;
      const tone = pct >= 90 ? 'text-emerald-700' : pct >= 60 ? 'text-amber-700' : 'text-rose-700';
      return <span className={`font-medium ${tone}`}>{bpsToPct(r.realized_pct_of_predicted_bps)}</span>;
    } },
    { key: 'status', header: 'Status', render: (r) => (
      <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span>
    ) },
    { key: 'conf', header: 'Confidence', render: (r) => (
      <span className="text-xs">{r.confidence_band}</span>
    ) },
    { key: 'model', header: 'Model', render: (r) => (
      <span className="text-xs">{r.prediction_model_version}</span>
    ) },
    { key: 'refresh', header: 'Last refresh', render: (r) => (
      <span className="text-xs">{r.last_realized_refresh_on ?? '—'}</span>
    ) },
  ];

  const segCols: Column<SegmentRow>[] = [
    { key: 'segment', header: 'Segment', render: (r) => <span className="font-medium">{r.customer_segment}</span> },
    { key: 'count', header: 'Predictions', render: (r) => <span>{r.predictions_count}</span> },
    { key: 'predicted', header: 'Total predicted', render: (r) => (
      <span dangerouslySetInnerHTML={{ __html: rupees(r.total_predicted_rupees) }} />
    ) },
    { key: 'realized', header: 'Total realized', render: (r) => (
      <span dangerouslySetInnerHTML={{ __html: rupees(r.total_realized_rupees) }} />
    ) },
    { key: 'pct', header: '% realized', render: (r) => {
      const pct = r.realized_pct_of_predicted_bps / 100;
      const tone = pct >= 90 ? 'text-emerald-700' : pct >= 60 ? 'text-amber-700' : 'text-rose-700';
      return <span className={`font-medium ${tone}`}>{bpsToPct(r.realized_pct_of_predicted_bps)}</span>;
    } },
    { key: 'avg', header: 'Avg predicted', render: (r) => (
      <span dangerouslySetInnerHTML={{ __html: rupees(r.avg_predicted_rupees) }} />
    ) },
  ];

  const logCols: Column<AccuracyLog>[] = [
    { key: 'snap', header: 'Snapshot', render: (r) => <span className="text-xs">{r.snapshot_on}</span> },
    { key: 'elapsed', header: 'Months', render: (r) => <span>{r.months_elapsed_at_snap}</span> },
    { key: 'expected', header: 'Expected', render: (r) => (
      <span dangerouslySetInnerHTML={{ __html: rupees(r.expected_realized_rupees) }} />
    ) },
    { key: 'actual', header: 'Actual', render: (r) => (
      <span dangerouslySetInnerHTML={{ __html: rupees(r.actual_realized_rupees) }} />
    ) },
    { key: 'variance', header: 'Variance', render: (r) => {
      const tone = r.variance_bps >= 1000 ? 'text-emerald-700'
                 : r.variance_bps <= -1000 ? 'text-rose-700'
                 : 'text-[var(--color-fg)]';
      const sign = r.variance_bps >= 0 ? '+' : '';
      return <span className={`font-medium ${tone}`}>{sign}{bpsToPct(r.variance_bps)}</span>;
    } },
    { key: 'band', header: 'Band', render: (r) => (
      <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.accuracy_band}</span>
    ) },
    { key: 'note', header: 'Model adjustment', render: (r) => (
      <div className="max-w-md">
        <div className="text-xs">{r.model_adjustment_note ?? '—'}</div>
        {r.adjusted_model_version ? (
          <div className="text-xs text-[var(--color-muted)]">→ {r.adjusted_model_version}</div>
        ) : null}
      </div>
    ) },
  ];

  const realizedPct = bpsToPct(summary.realized_pct_of_predicted_bps);
  const avgVar = (Number(summary.avg_variance_bps ?? 0) / 100).toFixed(2);

  return (
    <div className="space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer LTV — realized vs predicted</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track initial LTV predictions, refresh realized-to-date numbers, and log accuracy
          snapshots with model adjustment notes. Use the bands to decide when the prediction
          model needs a rev.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Total predictions</div>
          <div className="mt-1 text-2xl font-semibold">{summary.total_predictions}</div>
          <div className="text-xs text-[var(--color-muted)]">
            {summary.active_predictions} active · {summary.churned_predictions} churned
          </div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Predicted LTV pool</div>
          <div className="mt-1 text-2xl font-semibold" dangerouslySetInnerHTML={{ __html: rupees(summary.total_predicted_rupees) }} />
          <div className="text-xs text-[var(--color-muted)]">across all cohorts</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Realized to date</div>
          <div className="mt-1 text-2xl font-semibold" dangerouslySetInnerHTML={{ __html: rupees(summary.total_realized_rupees) }} />
          <div className="text-xs text-[var(--color-muted)]">{realizedPct} of predicted</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Accuracy snapshots</div>
          <div className="mt-1 text-2xl font-semibold">{summary.snapshots_logged}</div>
          <div className="text-xs text-[var(--color-muted)]">
            on-track {summary.on_track_snaps} · under {summary.under_snaps} · over {summary.over_snaps}
          </div>
          <div className="mt-1 text-xs text-[var(--color-muted)]">avg variance {avgVar}%</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Segment breakdown</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Aggregated predicted vs realized rupees per customer segment. Bands &gt;= 90% are green,
          60–90% amber, &lt; 60% red.
        </p>
        <DataTable<SegmentRow>
          columns={segCols}
          rows={segments}
          rowKey={(r: SegmentRow, i: number) => String(r.customer_segment ?? i)}
          emptyMessage="No segment rows yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Predictions ({predictions.length})</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Initial LTV prediction vs realized to date. Use the % column to spot customers tracking
          &lt;= 60% of plan early.
        </p>
        <DataTable<Prediction>
          columns={predCols}
          rows={predictions}
          rowKey={(r: Prediction, i: number) => String(r.id ?? i)}
          emptyMessage="No LTV predictions logged yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Accuracy log & model adjustments</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Each snapshot compares expected (predicted × months_elapsed / horizon) against
          actual realized. Variance bands: &gt;= +/-30% severe, &gt;= +/-10% under/over, otherwise
          on-track.
        </p>
        <DataTable<AccuracyLog>
          columns={logCols}
          rows={logs}
          rowKey={(r: AccuracyLog, i: number) => String(r.id ?? i)}
          emptyMessage="No accuracy snapshots logged yet."
        />
      </section>
    </div>
  );
}
