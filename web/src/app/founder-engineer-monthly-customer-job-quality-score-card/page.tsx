import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  engineers_scored: number;
  avg_raw_score: number | string;
  avg_variance: number | string;
  escalate_count: number;
  excellent_count: number;
  open_interventions: number;
};

type ScoreRow = {
  id: string;
  month_start: string;
  engineer_code: string;
  engineer_name: string;
  job_code: string;
  dimension: string;
  raw_score: number | string;
  cohort_median: number | string;
  variance: number | string;
  customer_count: number;
  verdict: string;
  notes: string | null;
};

type RollupRow = {
  engineer_code: string;
  engineer_name: string;
  dimensions: number;
  avg_score: number | string;
  avg_variance: number | string;
  worst_verdict: string;
};

type DimensionRow = {
  dimension: string;
  rows_count: number;
  avg_score: number | string;
  avg_variance: number | string;
  worst_score: number | string;
};

type InterventionRow = {
  intervention_id: string;
  engineer_code: string;
  engineer_name: string;
  dimension: string;
  intervention_type: string;
  owner: string;
  due_date: string;
  status: string;
  outcome_note: string | null;
};

type VerdictRow = {
  verdict: string;
  rows_count: number;
  share_pct: number | string;
};

type WorstRow = {
  engineer_code: string;
  engineer_name: string;
  job_code: string;
  dimension: string;
  raw_score: number | string;
  cohort_median: number | string;
  variance: number | string;
  verdict: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, rowsRes, rollupRes, dimensionRes, interventionRes, verdictRes, worstRes] = await Promise.all([
    supabase.rpc('founder_r2846_score_card_kpis'),
    supabase.rpc('founder_r2846_score_card_rows'),
    supabase.rpc('founder_r2846_engineer_rollup'),
    supabase.rpc('founder_r2846_dimension_breakdown'),
    supabase.rpc('founder_r2846_intervention_queue'),
    supabase.rpc('founder_r2846_verdict_mix'),
    supabase.rpc('founder_r2846_worst_variance', { p_limit: 5 }),
  ]);

  const kpis: KpiRow | null = Array.isArray(kpisRes.data) ? (kpisRes.data[0] as KpiRow) ?? null : null;
  const rows: ScoreRow[] = (rowsRes.data as ScoreRow[] | null) ?? [];
  const rollup: RollupRow[] = (rollupRes.data as RollupRow[] | null) ?? [];
  const dimensions: DimensionRow[] = (dimensionRes.data as DimensionRow[] | null) ?? [];
  const interventions: InterventionRow[] = (interventionRes.data as InterventionRow[] | null) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[] | null) ?? [];
  const worst: WorstRow[] = (worstRes.data as WorstRow[] | null) ?? [];

  const fmtNum = (v: number | string | null | undefined) => {
    if (v === null || v === undefined) return '-';
    const n = typeof v === 'string' ? Number(v) : v;
    return Number.isFinite(n) ? n.toFixed(2) : String(v);
  };

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Job Quality Score Card</h1>
        <p className="text-sm text-gray-600">
          Round r2846 — dimension-level scores, variance vs cohort median, and intervention queue.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Engineers scored</div>
          <div className="text-2xl font-semibold">{kpis?.engineers_scored ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Avg raw score</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.avg_raw_score)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Avg variance vs median</div>
          <div className="text-2xl font-semibold">{fmtNum(kpis?.avg_variance)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Excellent rows</div>
          <div className="text-2xl font-semibold">{kpis?.excellent_count ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Escalate rows</div>
          <div className="text-2xl font-semibold">{kpis?.escalate_count ?? 0}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Open interventions</div>
          <div className="text-2xl font-semibold">{kpis?.open_interventions ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-engineer rollup</h2>
        <p className="text-xs text-gray-500 mb-2">
          Avg score and avg variance across all measured dimensions. Worst verdict is the most severe label seen.
        </p>
        <DataTable
          rows={rollup}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: RollupRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: RollupRow) => r.engineer_name },
            { key: 'dimensions', header: 'Dimensions', render: (r: RollupRow) => r.dimensions },
            { key: 'avg_score', header: 'Avg score', render: (r: RollupRow) => fmtNum(r.avg_score) },
            { key: 'avg_variance', header: 'Avg variance', render: (r: RollupRow) => fmtNum(r.avg_variance) },
            { key: 'worst_verdict', header: 'Worst verdict', render: (r: RollupRow) => r.worst_verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: RollupRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dimension breakdown</h2>
        <p className="text-xs text-gray-500 mb-2">
          Rolled-up score per quality dimension. Worst score is the single lowest data point in that dimension.
        </p>
        <DataTable
          rows={dimensions}
          columns={[
            { key: 'dimension', header: 'Dimension', render: (r: DimensionRow) => r.dimension },
            { key: 'rows_count', header: 'Rows', render: (r: DimensionRow) => r.rows_count },
            { key: 'avg_score', header: 'Avg score', render: (r: DimensionRow) => fmtNum(r.avg_score) },
            { key: 'avg_variance', header: 'Avg variance', render: (r: DimensionRow) => fmtNum(r.avg_variance) },
            { key: 'worst_score', header: 'Worst score', render: (r: DimensionRow) => fmtNum(r.worst_score) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DimensionRow, i: number) => String(r.dimension ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Worst variance (bottom 5)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Rows where raw score is far below the cohort median. Negative variance means the engineer scored lower than
          peers on that dimension.
        </p>
        <DataTable
          rows={worst}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: WorstRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: WorstRow) => r.engineer_name },
            { key: 'job_code', header: 'Job', render: (r: WorstRow) => r.job_code },
            { key: 'dimension', header: 'Dimension', render: (r: WorstRow) => r.dimension },
            { key: 'raw_score', header: 'Score', render: (r: WorstRow) => fmtNum(r.raw_score) },
            { key: 'cohort_median', header: 'Cohort median', render: (r: WorstRow) => fmtNum(r.cohort_median) },
            { key: 'variance', header: 'Variance', render: (r: WorstRow) => fmtNum(r.variance) },
            { key: 'verdict', header: 'Verdict', render: (r: WorstRow) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: WorstRow, i: number) => `${r.engineer_code}-${r.dimension}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All score card rows</h2>
        <DataTable
          rows={rows}
          columns={[
            { key: 'month_start', header: 'Month', render: (r: ScoreRow) => r.month_start },
            { key: 'engineer_code', header: 'Engineer', render: (r: ScoreRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: ScoreRow) => r.engineer_name },
            { key: 'job_code', header: 'Job', render: (r: ScoreRow) => r.job_code },
            { key: 'dimension', header: 'Dimension', render: (r: ScoreRow) => r.dimension },
            { key: 'raw_score', header: 'Score', render: (r: ScoreRow) => fmtNum(r.raw_score) },
            { key: 'cohort_median', header: 'Median', render: (r: ScoreRow) => fmtNum(r.cohort_median) },
            { key: 'variance', header: 'Variance', render: (r: ScoreRow) => fmtNum(r.variance) },
            { key: 'customer_count', header: 'Customers', render: (r: ScoreRow) => r.customer_count },
            { key: 'verdict', header: 'Verdict', render: (r: ScoreRow) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: ScoreRow) => r.notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: ScoreRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Verdict mix</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'rows_count', header: 'Rows', render: (r: VerdictRow) => r.rows_count },
            { key: 'share_pct', header: 'Share %', render: (r: VerdictRow) => fmtNum(r.share_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Intervention queue</h2>
        <p className="text-xs text-gray-500 mb-2">
          Ordered by status (open first) then due date. Owners are responsible for closing the loop with the engineer.
        </p>
        <DataTable
          rows={interventions}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: InterventionRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: InterventionRow) => r.engineer_name },
            { key: 'dimension', header: 'Dimension', render: (r: InterventionRow) => r.dimension },
            { key: 'intervention_type', header: 'Type', render: (r: InterventionRow) => r.intervention_type },
            { key: 'owner', header: 'Owner', render: (r: InterventionRow) => r.owner },
            { key: 'due_date', header: 'Due', render: (r: InterventionRow) => r.due_date },
            { key: 'status', header: 'Status', render: (r: InterventionRow) => r.status },
            { key: 'outcome_note', header: 'Outcome', render: (r: InterventionRow) => r.outcome_note ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: InterventionRow, i: number) => String(r.intervention_id ?? i)}
        />
      </section>
    </main>
  );
}