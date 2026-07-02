import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(Number(n));
}
function fmtMoney(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + new Intl.NumberFormat('en-IN').format(Number(n));
}
function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(2) + '%';
}
function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function FounderPricingExperimentsPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = {};
  let list: any[] = [];
  let results: any[] = [];
  let bySegment: any[] = [];
  let byScope: any[] = [];
  let winners: any[] = [];
  let exposures: any[] = [];

  try {
    const { data } = await sb.rpc('founder_pricing_experiments_summary');
    summary = (data && data[0]) || {};
  } catch { summary = {}; }
  try {
    const { data } = await sb.rpc('founder_pricing_experiments_list');
    list = data || [];
  } catch { list = []; }
  try {
    const { data } = await sb.rpc('founder_pricing_experiments_results');
    results = data || [];
  } catch { results = []; }
  try {
    const { data } = await sb.rpc('founder_pricing_experiments_by_segment');
    bySegment = data || [];
  } catch { bySegment = []; }
  try {
    const { data } = await sb.rpc('founder_pricing_experiments_by_scope');
    byScope = data || [];
  } catch { byScope = []; }
  try {
    const { data } = await sb.rpc('founder_pricing_experiments_top_winners');
    winners = data || [];
  } catch { winners = []; }
  try {
    const { data } = await sb.rpc('founder_pricing_experiments_recent_exposures');
    exposures = data || [];
  } catch { exposures = []; }

  const kpis: Kpi[] = [
    { label: 'Total Experiments', value: fmtInt(summary.total_experiments) },
    { label: 'Running', value: fmtInt(summary.running_experiments) },
    { label: 'Draft', value: fmtInt(summary.draft_experiments) },
    { label: 'Promoted', value: fmtInt(summary.promoted_experiments) },
    { label: 'Rejected', value: fmtInt(summary.rejected_experiments) },
    { label: 'Completed', value: fmtInt(summary.completed_experiments) },
    { label: 'Total Exposures', value: fmtInt(summary.total_exposures) },
    { label: 'Total Conversions', value: fmtInt(summary.total_conversions) },
    { label: 'Overall Conv %', value: fmtPct(summary.overall_conversion_pct) },
    { label: 'Realized Revenue', value: fmtMoney(summary.total_realized_revenue_rupees) },
    { label: 'Avg Control Price', value: fmtMoney(summary.avg_control_price_rupees) },
    { label: 'Avg Variant Price', value: fmtMoney(summary.avg_variant_price_rupees) },
    { label: 'Segments Covered', value: fmtInt(summary.segments_covered) },
    { label: 'Longest Running (d)', value: fmtInt(summary.longest_running_days) },
    { label: 'New (7d)', value: fmtInt(summary.experiments_last_7d) },
    { label: 'New (30d)', value: fmtInt(summary.experiments_last_30d) },
  ];

  const listCols: Column<any>[] = [
    { key: 'name', header: 'Name', render: (r: any) => r.name ?? '—' },
    { key: 'customer_segment', header: 'Segment', render: (r: any) => r.customer_segment ?? '—' },
    { key: 'product_scope', header: 'Scope', render: (r: any) => r.product_scope ?? '—' },
    { key: 'control_price_rupees', header: 'Control', render: (r: any) => fmtMoney(r.control_price_rupees) },
    { key: 'variant_price_rupees', header: 'Variant', render: (r: any) => fmtMoney(r.variant_price_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'started_at', header: 'Started', render: (r: any) => fmtDate(r.started_at) },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const resultsCols: Column<any>[] = [
    { key: 'name', header: 'Experiment', render: (r: any) => r.name ?? '—' },
    { key: 'customer_segment', header: 'Segment', render: (r: any) => r.customer_segment ?? '—' },
    { key: 'control_exposures', header: 'Ctrl Exp', render: (r: any) => fmtInt(r.control_exposures) },
    { key: 'control_conversion_pct', header: 'Ctrl Conv', render: (r: any) => fmtPct(r.control_conversion_pct) },
    { key: 'control_revenue_rupees', header: 'Ctrl Rev', render: (r: any) => fmtMoney(r.control_revenue_rupees) },
    { key: 'variant_exposures', header: 'Var Exp', render: (r: any) => fmtInt(r.variant_exposures) },
    { key: 'variant_conversion_pct', header: 'Var Conv', render: (r: any) => fmtPct(r.variant_conversion_pct) },
    { key: 'variant_revenue_rupees', header: 'Var Rev', render: (r: any) => fmtMoney(r.variant_revenue_rupees) },
    { key: 'lift_pct', header: 'Lift', render: (r: any) => fmtPct(r.lift_pct) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const segmentCols: Column<any>[] = [
    { key: 'customer_segment', header: 'Segment', render: (r: any) => r.customer_segment ?? '—' },
    { key: 'experiment_count', header: 'Experiments', render: (r: any) => fmtInt(r.experiment_count) },
    { key: 'running_count', header: 'Running', render: (r: any) => fmtInt(r.running_count) },
    { key: 'promoted_count', header: 'Promoted', render: (r: any) => fmtInt(r.promoted_count) },
    { key: 'avg_control_price_rupees', header: 'Avg Ctrl', render: (r: any) => fmtMoney(r.avg_control_price_rupees) },
    { key: 'avg_variant_price_rupees', header: 'Avg Var', render: (r: any) => fmtMoney(r.avg_variant_price_rupees) },
    { key: 'total_exposures', header: 'Exposures', render: (r: any) => fmtInt(r.total_exposures) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtMoney(r.total_revenue_rupees) },
  ];

  const scopeCols: Column<any>[] = [
    { key: 'product_scope', header: 'Scope', render: (r: any) => r.product_scope ?? '—' },
    { key: 'experiment_count', header: 'Experiments', render: (r: any) => fmtInt(r.experiment_count) },
    { key: 'running_count', header: 'Running', render: (r: any) => fmtInt(r.running_count) },
    { key: 'promoted_count', header: 'Promoted', render: (r: any) => fmtInt(r.promoted_count) },
    { key: 'total_exposures', header: 'Exposures', render: (r: any) => fmtInt(r.total_exposures) },
    { key: 'total_conversions', header: 'Conversions', render: (r: any) => fmtInt(r.total_conversions) },
    { key: 'conversion_pct', header: 'Conv %', render: (r: any) => fmtPct(r.conversion_pct) },
  ];

  const winnerCols: Column<any>[] = [
    { key: 'name', header: 'Experiment', render: (r: any) => r.name ?? '—' },
    { key: 'customer_segment', header: 'Segment', render: (r: any) => r.customer_segment ?? '—' },
    { key: 'product_scope', header: 'Scope', render: (r: any) => r.product_scope ?? '—' },
    { key: 'promoted_variant', header: 'Winner', render: (r: any) => r.promoted_variant ?? '—' },
    { key: 'promoted_at', header: 'Promoted', render: (r: any) => fmtDate(r.promoted_at) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtMoney(r.total_revenue_rupees) },
    { key: 'conversion_pct', header: 'Conv %', render: (r: any) => fmtPct(r.conversion_pct) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Pricing Experiments</h1>
        <p style={{ color: '#666' }}>
          A/B price experiments across customer segments. Control vs variant, conversion rate, revenue impact, and founder approve/promote winning variant.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Experiment Results</h2>
        <DataTable<any> columns={resultsCols} rows={results} rowKey={(r: any) => r.experiment_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Experiments</h2>
        <DataTable<any> columns={listCols} rows={list} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Customer Segment</h2>
        <DataTable<any> columns={segmentCols} rows={bySegment} rowKey={(r: any) => r.customer_segment} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Product Scope</h2>
        <DataTable<any> columns={scopeCols} rows={byScope} rowKey={(r: any) => r.product_scope} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Promoted Winners</h2>
        <DataTable<any> columns={winnerCols} rows={winners} rowKey={(r: any) => r.experiment_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Exposures (100)</h2>
        <div style={{ fontSize: 12, color: '#666' }}>{exposures.length} exposure rows · most recent first</div>
      </section>
    </main>
  );
}
