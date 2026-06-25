import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_blocks: number;
  total_planned_min: number;
  total_actual_min: number;
  avg_flow: number;
  avg_quality: number;
  total_interruptions: number;
  pct_variance: number;
};

type CategoryRow = {
  category: string;
  blocks: number;
  total_minutes: number;
  avg_flow: number;
  avg_quality: number;
};

type BlockRow = {
  block_date: string;
  block_label: string;
  topic: string;
  category: string;
  planned_minutes: number;
  actual_minutes: number;
  interruption_count: number;
  flow_state_score: number;
  output_quality: number;
  output_artifact: string;
};

type CalibrationRow = {
  calibration_date: string;
  topic: string;
  prior_avg_minutes: number;
  observed_avg_minutes: number;
  variance_pct: number;
  decision: string;
  rationale: string;
  next_target_minutes: number;
  reviewed_by: string;
};

type DecisionRow = {
  decision: string;
  topics: number;
  total_next_minutes: number;
  avg_variance_pct: number;
};

type FlowRow = {
  topic: string;
  block_date: string;
  flow_state_score: number;
  output_quality: number;
  actual_minutes: number;
  interruption_count: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, catRes, blocksRes, calRes, decRes, flowRes] = await Promise.all([
    supabase.rpc('founder_dw_kpi_r2765'),
    supabase.rpc('founder_dw_by_category_r2765'),
    supabase.rpc('founder_dw_recent_blocks_r2765'),
    supabase.rpc('founder_dw_calibrations_r2765'),
    supabase.rpc('founder_dw_decision_breakdown_r2765'),
    supabase.rpc('founder_dw_top_flow_r2765'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_blocks: 0,
    total_planned_min: 0,
    total_actual_min: 0,
    avg_flow: 0,
    avg_quality: 0,
    total_interruptions: 0,
    pct_variance: 0,
  }) as Kpi;

  const categories: CategoryRow[] = (catRes.data ?? []) as CategoryRow[];
  const blocks: BlockRow[] = (blocksRes.data ?? []) as BlockRow[];
  const calibrations: CalibrationRow[] = (calRes.data ?? []) as CalibrationRow[];
  const decisions: DecisionRow[] = (decRes.data ?? []) as DecisionRow[];
  const flows: FlowRow[] = (flowRes.data ?? []) as FlowRow[];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-3xl font-semibold tracking-tight">Quarterly Deep Work Time Audit</h1>
        <p className="text-sm text-neutral-600 mt-1">
          Block × topic × minutes × interruption × output &amp; calibrate decision. Variance &gt;= 20% triggers review; flow score &lt; 6 flags interruption pattern.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Blocks" value={String(kpi.total_blocks)} />
        <KpiCard label="Planned (min)" value={String(kpi.total_planned_min)} />
        <KpiCard label="Actual (min)" value={String(kpi.total_actual_min)} />
        <KpiCard label="Variance %" value={`${kpi.pct_variance}%`} />
        <KpiCard label="Avg Flow (1-10)" value={String(kpi.avg_flow)} />
        <KpiCard label="Avg Quality (1-10)" value={String(kpi.avg_quality)} />
        <KpiCard label="Interruptions" value={String(kpi.total_interruptions)} />
        <KpiCard label="Decisions Logged" value={String(calibrations.length)} />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Time by Category</h2>
        <DataTable
          rows={categories}
          columns={[
            { key: 'category', header: 'Category', render: (r: CategoryRow) => r.category },
            { key: 'blocks', header: 'Blocks', render: (r: CategoryRow) => r.blocks },
            { key: 'total_minutes', header: 'Total Min', render: (r: CategoryRow) => r.total_minutes },
            { key: 'avg_flow', header: 'Avg Flow', render: (r: CategoryRow) => r.avg_flow },
            { key: 'avg_quality', header: 'Avg Quality', render: (r: CategoryRow) => r.avg_quality },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(r.category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Recent Deep Work Blocks</h2>
        <DataTable
          rows={blocks}
          columns={[
            { key: 'block_date', header: 'Date', render: (r: BlockRow) => r.block_date },
            { key: 'block_label', header: 'Block', render: (r: BlockRow) => r.block_label },
            { key: 'topic', header: 'Topic', render: (r: BlockRow) => r.topic },
            { key: 'category', header: 'Cat', render: (r: BlockRow) => r.category },
            { key: 'planned_minutes', header: 'Plan', render: (r: BlockRow) => r.planned_minutes },
            { key: 'actual_minutes', header: 'Actual', render: (r: BlockRow) => r.actual_minutes },
            { key: 'interruption_count', header: 'Intr', render: (r: BlockRow) => r.interruption_count },
            { key: 'flow_state_score', header: 'Flow', render: (r: BlockRow) => r.flow_state_score },
            { key: 'output_quality', header: 'Qual', render: (r: BlockRow) => r.output_quality },
            { key: 'output_artifact', header: 'Output', render: (r: BlockRow) => r.output_artifact },
          ]}
          emptyMessage="No data"
          rowKey={(r: BlockRow, i: number) => String(`${r.block_date}-${r.block_label}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Calibrate Decisions</h2>
        <p className="text-sm text-neutral-600 mb-3">
          Variance &gt;= 20% or flow &lt; 6 flags a row for delegate/kill/batch review.
        </p>
        <DataTable
          rows={calibrations}
          columns={[
            { key: 'calibration_date', header: 'Date', render: (r: CalibrationRow) => r.calibration_date },
            { key: 'topic', header: 'Topic', render: (r: CalibrationRow) => r.topic },
            { key: 'prior_avg_minutes', header: 'Prior', render: (r: CalibrationRow) => r.prior_avg_minutes },
            { key: 'observed_avg_minutes', header: 'Observed', render: (r: CalibrationRow) => r.observed_avg_minutes },
            { key: 'variance_pct', header: 'Var %', render: (r: CalibrationRow) => `${r.variance_pct}%` },
            { key: 'decision', header: 'Decision', render: (r: CalibrationRow) => r.decision },
            { key: 'next_target_minutes', header: 'Next Target', render: (r: CalibrationRow) => r.next_target_minutes },
            { key: 'rationale', header: 'Rationale', render: (r: CalibrationRow) => r.rationale },
            { key: 'reviewed_by', header: 'By', render: (r: CalibrationRow) => r.reviewed_by },
          ]}
          emptyMessage="No data"
          rowKey={(r: CalibrationRow, i: number) => String(`${r.calibration_date}-${r.topic}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Decision Breakdown</h2>
        <DataTable
          rows={decisions}
          columns={[
            { key: 'decision', header: 'Decision', render: (r: DecisionRow) => r.decision },
            { key: 'topics', header: 'Topics', render: (r: DecisionRow) => r.topics },
            { key: 'total_next_minutes', header: 'Next Min Total', render: (r: DecisionRow) => r.total_next_minutes },
            { key: 'avg_variance_pct', header: 'Avg Var %', render: (r: DecisionRow) => `${r.avg_variance_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: DecisionRow, i: number) => String(r.decision ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Flow Blocks</h2>
        <DataTable
          rows={flows}
          columns={[
            { key: 'topic', header: 'Topic', render: (r: FlowRow) => r.topic },
            { key: 'block_date', header: 'Date', render: (r: FlowRow) => r.block_date },
            { key: 'flow_state_score', header: 'Flow', render: (r: FlowRow) => r.flow_state_score },
            { key: 'output_quality', header: 'Quality', render: (r: FlowRow) => r.output_quality },
            { key: 'actual_minutes', header: 'Minutes', render: (r: FlowRow) => r.actual_minutes },
            { key: 'interruption_count', header: 'Intr', render: (r: FlowRow) => r.interruption_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: FlowRow, i: number) => String(`${r.topic}-${r.block_date}-${i}`)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-neutral-900">{value}</div>
    </div>
  );
}
