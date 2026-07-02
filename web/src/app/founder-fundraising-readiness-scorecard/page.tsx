import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  overall_score: number | null;
  dimensions_count: number | null;
  ready_dimensions: number | null;
  blocker_dimensions: number | null;
  open_gaps: number | null;
  blocker_gaps: number | null;
  avg_score: number | null;
  total_effort_days: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpisRes, byCatRes, dimsRes, gapsRes, bucketsRes] = await Promise.all([
    sb.rpc('fundraising_readiness_kpis_r2269'),
    sb.rpc('fundraising_readiness_by_category_r2269'),
    sb.rpc('fundraising_readiness_dimensions_list_r2269'),
    sb.rpc('fundraising_readiness_open_gaps_r2269'),
    sb.rpc('fundraising_readiness_score_buckets_r2269'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] ?? {}) as Kpis;
  const byCat: any[] = byCatRes.data ?? [];
  const dims: any[] = dimsRes.data ?? [];
  const gaps: any[] = gapsRes.data ?? [];
  const buckets: any[] = bucketsRes.data ?? [];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => <span className="font-medium capitalize">{r.category}</span> },
    { key: 'dimensions_count', header: 'Dims', render: (r) => r.dimensions_count },
    { key: 'weighted_score', header: 'Weighted score', render: (r) => Number(r.weighted_score ?? 0).toFixed(2) },
    { key: 'avg_score', header: 'Avg score', render: (r) => Number(r.avg_score ?? 0).toFixed(1) },
    { key: 'total_weight', header: 'Weight %', render: (r) => Number(r.total_weight ?? 0).toFixed(1) },
    { key: 'open_gaps', header: 'Open gaps', render: (r) => r.open_gaps },
  ];

  const dimCols: Column<any>[] = [
    { key: 'dimension_label', header: 'Dimension', render: (r) => <span className="font-medium">{r.dimension_label}</span> },
    { key: 'category', header: 'Category', render: (r) => <span className="capitalize text-xs px-2 py-0.5 rounded bg-slate-100">{r.category}</span> },
    { key: 'weight_pct', header: 'Weight %', render: (r) => Number(r.weight_pct ?? 0).toFixed(1) },
    {
      key: 'current_score',
      header: 'Score',
      render: (r) => {
        const s = Number(r.current_score ?? 0);
        const color = s >= 90 ? 'text-emerald-700' : s >= 60 ? 'text-amber-700' : 'text-rose-700';
        return <span className={`font-semibold ${color}`}>{s}</span>;
      },
    },
    { key: 'gap_to_target', header: 'Gap to target', render: (r) => r.gap_to_target },
    { key: 'weighted_contribution', header: 'Weighted contrib.', render: (r) => Number(r.weighted_contribution ?? 0).toFixed(2) },
    { key: 'blocker_notes', header: 'Notes', render: (r) => <span className="text-xs text-slate-600">{r.blocker_notes ?? '—'}</span> },
  ];

  const gapCols: Column<any>[] = [
    { key: 'gap_title', header: 'Gap', render: (r) => <span className="font-medium">{r.gap_title}</span> },
    { key: 'dimension_label', header: 'Dimension', render: (r) => r.dimension_label },
    { key: 'category', header: 'Category', render: (r) => <span className="capitalize">{r.category}</span> },
    {
      key: 'gap_severity',
      header: 'Severity',
      render: (r) => {
        const sev = String(r.gap_severity ?? '');
        const cls =
          sev === 'blocker' ? 'bg-rose-100 text-rose-800' :
          sev === 'high' ? 'bg-amber-100 text-amber-800' :
          sev === 'medium' ? 'bg-yellow-100 text-yellow-800' :
          'bg-slate-100 text-slate-700';
        return <span className={`text-xs px-2 py-0.5 rounded ${cls}`}>{sev}</span>;
      },
    },
    { key: 'effort_days', header: 'Effort (d)', render: (r) => r.effort_days },
    { key: 'target_close_date', header: 'Target close', render: (r) => r.target_close_date ?? '—' },
    { key: 'days_to_target', header: 'Days to target', render: (r) => r.days_to_target ?? '—' },
  ];

  const bucketCols: Column<any>[] = [
    { key: 'bucket', header: 'Readiness bucket', render: (r) => r.bucket },
    { key: 'dimensions_count', header: 'Dimensions', render: (r) => r.dimensions_count },
  ];

  const overall = Number(kpis.overall_score ?? 0);
  const overallColor = overall >= 80 ? 'text-emerald-700' : overall >= 60 ? 'text-amber-700' : 'text-rose-700';

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Fundraising readiness scorecard</h1>
        <p className="text-slate-600 mt-1">
          10-dimension readiness across metrics, deck, references, financials & pipeline. Gap-to-ready tracking for next round.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-slate-500">Overall score</div>
          <div className={`text-3xl font-bold ${overallColor}`}>{overall.toFixed(1)}</div>
          <div className="text-xs text-slate-500 mt-1">weighted across 10 dims</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-slate-500">Ready dims (&gt;= 90)</div>
          <div className="text-3xl font-bold text-emerald-700">{kpis.ready_dimensions ?? 0}</div>
          <div className="text-xs text-slate-500 mt-1">of {kpis.dimensions_count ?? 0}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-slate-500">Blocker dims (&lt; 60)</div>
          <div className="text-3xl font-bold text-rose-700">{kpis.blocker_dimensions ?? 0}</div>
          <div className="text-xs text-slate-500 mt-1">need urgent attention</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-slate-500">Open gaps</div>
          <div className="text-3xl font-bold text-slate-900">{kpis.open_gaps ?? 0}</div>
          <div className="text-xs text-slate-500 mt-1">{kpis.blocker_gaps ?? 0} blocker & {kpis.total_effort_days ?? 0}d total effort</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Score by category</h2>
        <DataTable columns={catCols} rows={byCat} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Readiness buckets</h2>
        <DataTable columns={bucketCols} rows={buckets} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All 10 dimensions</h2>
        <DataTable columns={dimCols} rows={dims} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open gaps (sorted blocker &gt; high &gt; medium &gt; low)</h2>
        <DataTable columns={gapCols} rows={gaps} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
