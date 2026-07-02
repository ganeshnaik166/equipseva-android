import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [comparisons, winLoss, topBrands, kindBreakdown, winRate, monthly, lessons] = await Promise.all([
    supabase.rpc('list_comparisons_r2567'),
    supabase.rpc('list_win_loss_log_r2567'),
    supabase.rpc('top_competitor_brands_r2567'),
    supabase.rpc('equipment_kind_breakdown_r2567'),
    supabase.rpc('win_rate_summary_r2567'),
    supabase.rpc('monthly_decision_trend_r2567'),
    supabase.rpc('lessons_focus_r2567'),
  ]);

  const comparisonRows = (comparisons.data ?? []) as any[];
  const winLossRows = (winLoss.data ?? []) as any[];
  const brandRows = (topBrands.data ?? []) as any[];
  const kindRows = (kindBreakdown.data ?? []) as any[];
  const summary = ((winRate.data ?? [])[0] ?? {}) as any;
  const monthlyRows = (monthly.data ?? []) as any[];
  const lessonRows = (lessons.data ?? []) as any[];

  const fmtMoney = (v: any) => {
    if (v === null || v === undefined) return '-';
    const n = Number(v);
    if (!Number.isFinite(n)) return '-';
    return '₹' + n.toLocaleString('en-IN');
  };

  const comparisonCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'competitor_brand', header: 'Competitor', render: (r: any) => r.competitor_brand ?? '-' },
    { key: 'our_positioning_md', header: 'Our Positioning', render: (r: any) => r.our_positioning_md ?? '-' },
    { key: 'win_factors_md', header: 'Win Factors', render: (r: any) => r.win_factors_md ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const winLossCols: Column<any>[] = [
    { key: 'decision_at', header: 'Decision At', render: (r: any) => r.decision_at ? new Date(r.decision_at).toLocaleString() : '-' },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'competitor_brand', header: 'Competitor', render: (r: any) => r.competitor_brand ?? '-' },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind ?? '-' },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtMoney(r.value_rupees) },
    { key: 'lessons_md', header: 'Lessons', render: (r: any) => r.lessons_md ?? '-' },
  ];

  const brandCols: Column<any>[] = [
    { key: 'competitor_brand', header: 'Brand', render: (r: any) => r.competitor_brand ?? '-' },
    { key: 'encounters', header: 'Encounters', render: (r: any) => String(r.encounters ?? 0) },
    { key: 'we_won_count', header: 'We Won', render: (r: any) => String(r.we_won_count ?? 0) },
    { key: 'competitor_won_count', header: 'They Won', render: (r: any) => String(r.competitor_won_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtMoney(r.total_value_rupees) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'comparison_count', header: 'Comparisons', render: (r: any) => String(r.comparison_count ?? 0) },
    { key: 'distinct_brands', header: 'Distinct Brands', render: (r: any) => String(r.distinct_brands ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '-' },
    { key: 'total', header: 'Decisions', render: (r: any) => String(r.total ?? 0) },
    { key: 'we_won', header: 'Won', render: (r: any) => String(r.we_won ?? 0) },
    { key: 'competitor_won', header: 'Lost', render: (r: any) => String(r.competitor_won ?? 0) },
    { key: 'value_won_rupees', header: 'Value Won', render: (r: any) => fmtMoney(r.value_won_rupees) },
  ];

  const lessonsCols: Column<any>[] = [
    { key: 'decision_at', header: 'When', render: (r: any) => r.decision_at ? new Date(r.decision_at).toLocaleDateString() : '-' },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '-' },
    { key: 'competitor_brand', header: 'Competitor', render: (r: any) => r.competitor_brand ?? '-' },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind ?? '-' },
    { key: 'decision_kind', header: 'Outcome', render: (r: any) => r.decision_kind ?? '-' },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtMoney(r.value_rupees) },
    { key: 'lessons_md', header: 'Lessons', render: (r: any) => r.lessons_md ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Chain Equipment Vendor Comparison Matrix
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Chain × equipment kind × competitor brand & the win/loss intel behind each pursuit.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Win Rate Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <div style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Total Decisions</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{String(summary.total_decisions ?? 0)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>We Won</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#16a34a' }}>{String(summary.we_won ?? 0)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Competitor Won</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: '#dc2626' }}>{String(summary.competitor_won ?? 0)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Win Rate %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.win_rate_pct ?? '-'}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Value Won</div>
            <div style={{ fontSize: 18, fontWeight: 700, color: '#16a34a' }}>{fmtMoney(summary.total_won_value_rupees)}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Value Lost</div>
            <div style={{ fontSize: 18, fontWeight: 700, color: '#dc2626' }}>{fmtMoney(summary.total_lost_value_rupees)}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Comparisons</h2>
        <DataTable
          rows={comparisonRows}
          columns={comparisonCols}
          emptyMessage="No comparisons yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Competitor Brands</h2>
        <DataTable
          rows={brandRows}
          columns={brandCols}
          emptyMessage="No competitor data yet."
          rowKey={(r: any, i: number) => String(r.competitor_brand ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Equipment Kind Breakdown</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No equipment categories yet."
          rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Decision Trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No monthly data yet."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Win/Loss Log</h2>
        <DataTable
          rows={winLossRows}
          columns={winLossCols}
          emptyMessage="No decisions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Lessons Focus (Losses & Postponed)</h2>
        <DataTable
          rows={lessonRows}
          columns={lessonsCols}
          emptyMessage="No lessons logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
