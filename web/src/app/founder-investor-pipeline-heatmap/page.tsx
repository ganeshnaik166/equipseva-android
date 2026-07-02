import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PipelineRow = {
  id: string;
  investor_id: string;
  current_stage: string;
  warmth: number;
  days_in_stage: number;
  expected_close_date: string | null;
  expected_check_size_rupees: number | null;
  last_touch_at: string | null;
  founder_note: string | null;
  created_at: string;
};

type SummaryRow = {
  stage: string;
  state_count: number;
  avg_warmth: number | null;
  avg_days_in_stage: number | null;
  total_expected_rupees: number | null;
};

type QuarterRow = {
  id: string;
  investor_id: string;
  current_stage: string;
  warmth: number;
  expected_close_date: string | null;
  expected_check_size_rupees: number | null;
};

type ColdRow = {
  id: string;
  investor_id: string;
  current_stage: string;
  warmth: number;
  days_in_stage: number;
  last_touch_at: string | null;
  founder_note: string | null;
};

function fmtRupees(v: number | null | undefined) {
  if (v == null) return '—';
  return '₹' + Number(v).toLocaleString('en-IN');
}

function fmtDate(v: string | null | undefined) {
  if (!v) return '—';
  try {
    return new Date(v).toLocaleDateString('en-IN');
  } catch {
    return v;
  }
}

function fmtDateTime(v: string | null | undefined) {
  if (!v) return '—';
  try {
    return new Date(v).toLocaleString('en-IN');
  } catch {
    return v;
  }
}

export default async function FounderInvestorPipelineHeatmapPage() {
  const sb = await getSupabaseServerClient();

  const [pipelineRes, summaryRes, quarterRes, coldRes] = await Promise.all([
    sb.rpc('list_pipeline_r1705'),
    sb.rpc('pipeline_heatmap_summary_r1705'),
    sb.rpc('expected_close_this_quarter_r1705'),
    sb.rpc('cold_investors_r1705'),
  ]);

  const pipeline: PipelineRow[] = (pipelineRes.data as PipelineRow[]) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[]) ?? [];
  const quarter: QuarterRow[] = (quarterRes.data as QuarterRow[]) ?? [];
  const cold: ColdRow[] = (coldRes.data as ColdRow[]) ?? [];

  const totalActive = pipeline.filter((p) => p.current_stage !== 'passed').length;
  const totalPipelineRupees = pipeline
    .filter((p) => p.current_stage !== 'passed')
    .reduce((s, p) => s + (p.expected_check_size_rupees ?? 0), 0);
  const avgWarmth =
    pipeline.length > 0
      ? (pipeline.reduce((s, p) => s + (p.warmth ?? 0), 0) / pipeline.length).toFixed(2)
      : '—';

  const pipelineCols: Column<PipelineRow>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id).slice(0, 8)}</span> },
    { key: 'current_stage', header: 'Stage', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.current_stage}</span> },
    { key: 'warmth', header: 'Warmth', render: (r: any) => <span>{r.warmth} / 10</span> },
    { key: 'days_in_stage', header: 'Days in stage', render: (r: any) => <span>{r.days_in_stage}</span> },
    { key: 'expected_close_date', header: 'Expected close', render: (r: any) => <span>{fmtDate(r.expected_close_date)}</span> },
    { key: 'expected_check_size_rupees', header: 'Check size', render: (r: any) => <span>{fmtRupees(r.expected_check_size_rupees)}</span> },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => <span>{fmtDateTime(r.last_touch_at)}</span> },
    { key: 'founder_note', header: 'Note', render: (r: any) => <span className="text-xs">{r.founder_note ?? '—'}</span> },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => <span className="font-medium">{r.stage}</span> },
    { key: 'state_count', header: 'Count', render: (r: any) => <span>{r.state_count}</span> },
    { key: 'avg_warmth', header: 'Avg warmth', render: (r: any) => <span>{r.avg_warmth ?? '—'}</span> },
    { key: 'avg_days_in_stage', header: 'Avg days', render: (r: any) => <span>{r.avg_days_in_stage ?? '—'}</span> },
    { key: 'total_expected_rupees', header: 'Total expected', render: (r: any) => <span>{fmtRupees(r.total_expected_rupees)}</span> },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id).slice(0, 8)}</span> },
    { key: 'current_stage', header: 'Stage', render: (r: any) => <span>{r.current_stage}</span> },
    { key: 'warmth', header: 'Warmth', render: (r: any) => <span>{r.warmth} / 10</span> },
    { key: 'expected_close_date', header: 'Expected close', render: (r: any) => <span>{fmtDate(r.expected_close_date)}</span> },
    { key: 'expected_check_size_rupees', header: 'Check size', render: (r: any) => <span>{fmtRupees(r.expected_check_size_rupees)}</span> },
  ];

  const coldCols: Column<ColdRow>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id).slice(0, 8)}</span> },
    { key: 'current_stage', header: 'Stage', render: (r: any) => <span>{r.current_stage}</span> },
    { key: 'warmth', header: 'Warmth', render: (r: any) => <span className="text-red-700">{r.warmth} / 10</span> },
    { key: 'days_in_stage', header: 'Days stuck', render: (r: any) => <span>{r.days_in_stage}</span> },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => <span>{fmtDateTime(r.last_touch_at)}</span> },
    { key: 'founder_note', header: 'Note', render: (r: any) => <span className="text-xs">{r.founder_note ?? '—'}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Investor Pipeline Heatmap</h1>
        <p className="text-sm text-[var(--color-muted)]">
          All active investor conversations + stage heat (warmth times proximity to close).
        </p>
      </header>

      <section className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Active conversations</div>
          <div className="mt-1 text-2xl font-semibold">{totalActive}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Pipeline value</div>
          <div className="mt-1 text-2xl font-semibold">{fmtRupees(totalPipelineRupees)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Avg warmth</div>
          <div className="mt-1 text-2xl font-semibold">{avgWarmth}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Heatmap by stage</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Stage rollup excludes "passed". Avg warmth on a 1–10 scale.
        </p>
        <DataTable<SummaryRow>
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.stage ?? i)}
          emptyMessage="No active stages."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Expected close this quarter</h2>
        <DataTable<QuarterRow>
          rows={quarter}
          columns={quarterCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No closes expected this quarter."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Cold investors</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Warmth &lt;= 3 or last touch older than 21 days. Reach out before they go silent.
        </p>
        <DataTable<ColdRow>
          rows={cold}
          columns={coldCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No cold investors."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All pipeline states</h2>
        <DataTable<PipelineRow>
          rows={pipeline}
          columns={pipelineCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No investor conversations logged yet."
        />
      </section>
    </main>
  );
}
