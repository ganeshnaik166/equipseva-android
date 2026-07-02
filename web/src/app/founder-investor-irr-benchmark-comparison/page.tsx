import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cmpRes, latestRes, yearRes, topRes] = await Promise.all([
    sb.rpc('list_irr_benchmark_comparisons_r1849'),
    sb.rpc('latest_irr_benchmark_comparison_r1849'),
    sb.rpc('irr_benchmark_year_summary_r1849'),
    sb.rpc('irr_benchmark_top_performers_r1849'),
  ]);

  const comparisons: any[] = Array.isArray(cmpRes.data) ? cmpRes.data : [];
  const latest: any[] = Array.isArray(latestRes.data) ? latestRes.data : [];
  const yearSummary: any[] = Array.isArray(yearRes.data) ? yearRes.data : [];
  const topPerformers: any[] = Array.isArray(topRes.data) ? topRes.data : [];

  const fmtPct = (n: any) => (n == null ? '—' : `${Number(n).toFixed(2)}%`);
  const fmtDate = (s: any) => (s ? new Date(s).toLocaleDateString() : '—');

  const cmpCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => String(r.fiscal_year ?? '—') },
    { key: 'our_avg', header: 'Our Avg', render: (r: any) => fmtPct(r.our_avg_irr_pct) },
    { key: 'our_median', header: 'Our Median', render: (r: any) => fmtPct(r.our_median_irr_pct) },
    { key: 'our_tq', header: 'Our Top Quartile', render: (r: any) => fmtPct(r.our_top_quartile_irr_pct) },
    { key: 'cambridge', header: 'Cambridge US VC', render: (r: any) => fmtPct(r.cambridge_us_vc_irr_pct) },
    { key: 'preqin', header: 'Preqin India', render: (r: any) => fmtPct(r.preqin_india_irr_pct) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const latestCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => String(r.fiscal_year ?? '—') },
    { key: 'our_avg', header: 'Our Avg IRR', render: (r: any) => fmtPct(r.our_avg_irr_pct) },
    { key: 'our_median', header: 'Our Median IRR', render: (r: any) => fmtPct(r.our_median_irr_pct) },
    { key: 'our_tq', header: 'Our Top Quartile', render: (r: any) => fmtPct(r.our_top_quartile_irr_pct) },
    { key: 'cambridge', header: 'Cambridge', render: (r: any) => fmtPct(r.cambridge_us_vc_irr_pct) },
    { key: 'preqin', header: 'Preqin India', render: (r: any) => fmtPct(r.preqin_india_irr_pct) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
  ];

  const yearCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => String(r.fiscal_year ?? '—') },
    { key: 'current', header: 'Current', render: (r: any) => String(r.current_count ?? 0) },
    { key: 'superseded', header: 'Superseded', render: (r: any) => String(r.superseded_count ?? 0) },
    { key: 'our_avg', header: 'Our Avg', render: (r: any) => fmtPct(r.our_avg_irr_pct) },
    { key: 'cambridge', header: 'Cambridge', render: (r: any) => fmtPct(r.cambridge_us_vc_irr_pct) },
    { key: 'preqin', header: 'Preqin India', render: (r: any) => fmtPct(r.preqin_india_irr_pct) },
  ];

  const topCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => String(r.fiscal_year ?? '—') },
    { key: 'tq', header: 'Top Quartile', render: (r: any) => fmtPct(r.our_top_quartile_irr_pct) },
    { key: 'our_avg', header: 'Our Avg', render: (r: any) => fmtPct(r.our_avg_irr_pct) },
    { key: 'cambridge', header: 'Cambridge', render: (r: any) => fmtPct(r.cambridge_us_vc_irr_pct) },
    { key: 'alpha', header: 'Alpha vs Cambridge', render: (r: any) => fmtPct(r.alpha_vs_cambridge) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Investor IRR Benchmark Comparison</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Benchmark our investor IRR vs Cambridge Associates US VC & Preqin India indices.
          Higher is better — alpha &gt; 0 means we beat the benchmark.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Latest Current Comparison</h2>
        <DataTable rows={latest} columns={latestCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Performers (Alpha &gt; 0)</h2>
        <DataTable rows={topPerformers} columns={topCols} rowKey={(r: any, i: number) => String(r.fiscal_year ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Per-Year Summary</h2>
        <DataTable rows={yearSummary} columns={yearCols} rowKey={(r: any, i: number) => String(r.fiscal_year ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Comparisons (current & superseded)</h2>
        <DataTable rows={comparisons} columns={cmpCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
