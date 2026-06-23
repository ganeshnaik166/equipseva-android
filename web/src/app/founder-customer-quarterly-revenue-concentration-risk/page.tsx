import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerQuarterlyRevenueConcentrationRiskPage() {
  const supabase = await getSupabaseServerClient();

  const [
    concentrationRes,
    outcomesRes,
    topCriticalRes,
    hedgeDistRes,
    quarterlyTrendRes,
    lessonsRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_concentration_r2600'),
    supabase.rpc('list_diversification_outcomes_r2600'),
    supabase.rpc('top_critical_dependency_r2600'),
    supabase.rpc('hedge_kind_distribution_r2600'),
    supabase.rpc('quarterly_concentration_trend_r2600'),
    supabase.rpc('lessons_summary_r2600'),
    supabase.rpc('owner_load_r2600'),
  ]);

  const concentration = concentrationRes.data ?? [];
  const outcomes = outcomesRes.data ?? [];
  const topCritical = topCriticalRes.data ?? [];
  const hedgeDist = hedgeDistRes.data ?? [];
  const quarterlyTrend = quarterlyTrendRes.data ?? [];
  const lessons = lessonsRes.data ?? [];
  const ownerLoad = ownerLoadRes.data ?? [];

  const concentrationCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'revenue_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'share_of_total_pct', header: 'Share %', render: (r: any) => `${Number(r.share_of_total_pct ?? 0).toFixed(2)}%` },
    { key: 'dependency_risk_kind', header: 'Risk', render: (r: any) => r.dependency_risk_kind },
    { key: 'hedge_kind', header: 'Hedge', render: (r: any) => r.hedge_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const outcomesCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '—' },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'new_share_pct', header: 'New Share %', render: (r: any) => `${Number(r.new_share_pct ?? 0).toFixed(2)}%` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'lessons_md', header: 'Lessons', render: (r: any) => r.lessons_md },
  ];

  const topCriticalCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'revenue_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'share_of_total_pct', header: 'Share %', render: (r: any) => `${Number(r.share_of_total_pct ?? 0).toFixed(2)}%` },
    { key: 'dependency_risk_kind', header: 'Risk', render: (r: any) => r.dependency_risk_kind },
    { key: 'hedge_kind', header: 'Hedge', render: (r: any) => r.hedge_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const hedgeDistCols: Column<any>[] = [
    { key: 'hedge_kind', header: 'Hedge Kind', render: (r: any) => r.hedge_kind },
    { key: 'account_count', header: 'Accounts', render: (r: any) => r.account_count },
    { key: 'total_revenue_rupees', header: 'Total Revenue (Rs)', render: (r: any) => Number(r.total_revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'avg_share_pct', header: 'Avg Share %', render: (r: any) => `${Number(r.avg_share_pct ?? 0).toFixed(2)}%` },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'account_count', header: 'Accounts', render: (r: any) => r.account_count },
    { key: 'total_revenue_rupees', header: 'Total Revenue (Rs)', render: (r: any) => Number(r.total_revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'max_share_pct', header: 'Max Share %', render: (r: any) => `${Number(r.max_share_pct ?? 0).toFixed(2)}%` },
    { key: 'critical_accounts', header: 'Critical Accounts', render: (r: any) => r.critical_accounts },
  ];

  const lessonsCols: Column<any>[] = [
    { key: 'outcome_kind', header: 'Outcome Kind', render: (r: any) => r.outcome_kind },
    { key: 'outcome_count', header: 'Count', render: (r: any) => r.outcome_count },
    { key: 'avg_new_share_pct', header: 'Avg New Share %', render: (r: any) => `${Number(r.avg_new_share_pct ?? 0).toFixed(2)}%` },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'concentration_count', header: 'Concentrations', render: (r: any) => r.concentration_count },
    { key: 'outcome_count', header: 'Outcomes', render: (r: any) => r.outcome_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => r.in_progress_count },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Quarterly Revenue Concentration Risk</h1>
        <p className="text-sm text-gray-600">
          Track per-hospital revenue concentration, dependency risk, hedge actions & diversification outcomes.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Critical Dependencies (high & critical)</h2>
        <DataTable
          rows={topCritical}
          columns={topCriticalCols}
          emptyMessage="No high/critical dependencies yet."
          rowKey={(r: any, i: number) => String(r.id ?? `${r.hospital_email}-${r.quarter_label}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Concentration Trend</h2>
        <DataTable
          rows={quarterlyTrend}
          columns={trendCols}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hedge Kind Distribution</h2>
        <DataTable
          rows={hedgeDist}
          columns={hedgeDistCols}
          emptyMessage="No hedge data yet."
          rowKey={(r: any, i: number) => String(r.hedge_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Concentration Records</h2>
        <DataTable
          rows={concentration}
          columns={concentrationCols}
          emptyMessage="No concentration records yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Diversification Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomesCols}
          emptyMessage="No outcomes recorded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lessons Summary</h2>
        <DataTable
          rows={lessons}
          columns={lessonsCols}
          emptyMessage="No lessons captured yet."
          rowKey={(r: any, i: number) => String(r.outcome_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner load data yet."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
