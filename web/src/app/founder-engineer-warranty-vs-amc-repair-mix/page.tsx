import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerWarrantyVsAmcRepairMixPage() {
  const supabase = await getSupabaseServerClient();

  const [
    snapshotRes,
    coverageRes,
    engineerRes,
    weeklyRes,
    categoryRes,
    targetRes,
    recentRes,
  ] = await Promise.all([
    supabase.rpc('founder_repair_mix_snapshot_r2358'),
    supabase.rpc('founder_repair_coverage_distribution_r2358'),
    supabase.rpc('founder_engineer_revenue_split_r2358'),
    supabase.rpc('founder_repair_weekly_trend_r2358'),
    supabase.rpc('founder_repair_category_mix_r2358'),
    supabase.rpc('founder_repair_target_vs_actual_r2358'),
    supabase.rpc('founder_repair_recent_jobs_r2358'),
  ]);

  const snapshot = (snapshotRes.data ?? [])[0] ?? null;
  const coverage = coverageRes.data ?? [];
  const engineers = engineerRes.data ?? [];
  const weekly = weeklyRes.data ?? [];
  const categories = categoryRes.data ?? [];
  const targets = targetRes.data ?? [];
  const recent = recentRes.data ?? [];

  const coverageCols: Column<any>[] = [
    { key: 'coverage_type', header: 'Coverage', render: (r) => r.coverage_type },
    { key: 'jobs', header: 'Jobs', render: (r) => r.jobs },
    { key: 'pct_of_jobs', header: '% Jobs', render: (r) => `${r.pct_of_jobs ?? 0}%` },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r) => `Rs ${r.total_revenue_rupees ?? 0}` },
    { key: 'pct_of_revenue', header: '% Revenue', render: (r) => `${r.pct_of_revenue ?? 0}%` },
    { key: 'avg_job_hours', header: 'Avg Hours', render: (r) => r.avg_job_hours },
    { key: 'avg_revenue_rupees', header: 'Avg Revenue', render: (r) => `Rs ${r.avg_revenue_rupees ?? 0}` },
  ];

  const engineerCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '—' },
    { key: 'total_jobs', header: 'Jobs', render: (r) => r.total_jobs },
    { key: 'warranty_jobs', header: 'Warranty', render: (r) => r.warranty_jobs },
    { key: 'amc_jobs', header: 'AMC', render: (r) => r.amc_jobs },
    { key: 'paid_jobs', header: 'Paid', render: (r) => r.paid_jobs },
    { key: 'warranty_revenue_rupees', header: 'Warranty Rev', render: (r) => `Rs ${r.warranty_revenue_rupees ?? 0}` },
    { key: 'amc_revenue_rupees', header: 'AMC Rev', render: (r) => `Rs ${r.amc_revenue_rupees ?? 0}` },
    { key: 'paid_revenue_rupees', header: 'Paid Rev', render: (r) => `Rs ${r.paid_revenue_rupees ?? 0}` },
    { key: 'total_revenue_rupees', header: 'Total Rev', render: (r) => `Rs ${r.total_revenue_rupees ?? 0}` },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => r.week_start },
    { key: 'warranty_jobs', header: 'Warranty', render: (r) => r.warranty_jobs },
    { key: 'amc_jobs', header: 'AMC', render: (r) => r.amc_jobs },
    { key: 'paid_jobs', header: 'Paid', render: (r) => r.paid_jobs },
    { key: 'total_jobs', header: 'Total', render: (r) => r.total_jobs },
    { key: 'warranty_revenue_rupees', header: 'Warranty Rev', render: (r) => `Rs ${r.warranty_revenue_rupees ?? 0}` },
    { key: 'amc_revenue_rupees', header: 'AMC Rev', render: (r) => `Rs ${r.amc_revenue_rupees ?? 0}` },
    { key: 'paid_revenue_rupees', header: 'Paid Rev', render: (r) => `Rs ${r.paid_revenue_rupees ?? 0}` },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'total_jobs', header: 'Jobs', render: (r) => r.total_jobs },
    { key: 'warranty_pct', header: 'Warranty %', render: (r) => `${r.warranty_pct ?? 0}%` },
    { key: 'amc_pct', header: 'AMC %', render: (r) => `${r.amc_pct ?? 0}%` },
    { key: 'paid_pct', header: 'Paid %', render: (r) => `${r.paid_pct ?? 0}%` },
    { key: 'avg_revenue_rupees', header: 'Avg Revenue', render: (r) => `Rs ${r.avg_revenue_rupees ?? 0}` },
    { key: 'total_revenue_rupees', header: 'Total Revenue', render: (r) => `Rs ${r.total_revenue_rupees ?? 0}` },
  ];

  const targetCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '—' },
    { key: 'target_month', header: 'Month', render: (r) => r.target_month },
    { key: 'warranty_target_pct', header: 'Warranty Tgt', render: (r) => `${r.warranty_target_pct ?? 0}%` },
    { key: 'actual_warranty_pct', header: 'Actual Warranty', render: (r) => `${r.actual_warranty_pct ?? 0}%` },
    { key: 'amc_target_pct', header: 'AMC Tgt', render: (r) => `${r.amc_target_pct ?? 0}%` },
    { key: 'actual_amc_pct', header: 'Actual AMC', render: (r) => `${r.actual_amc_pct ?? 0}%` },
    { key: 'paid_target_pct', header: 'Paid Tgt', render: (r) => `${r.paid_target_pct ?? 0}%` },
    { key: 'actual_paid_pct', header: 'Actual Paid', render: (r) => `${r.actual_paid_pct ?? 0}%` },
    { key: 'revenue_target_rupees', header: 'Rev Target', render: (r) => `Rs ${r.revenue_target_rupees ?? 0}` },
    { key: 'actual_revenue_rupees', header: 'Actual Rev', render: (r) => `Rs ${r.actual_revenue_rupees ?? 0}` },
    { key: 'revenue_attainment_pct', header: 'Attainment', render: (r) => `${r.revenue_attainment_pct ?? 0}%` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'job_date', header: 'Date', render: (r) => r.job_date },
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email ?? '—' },
    { key: 'coverage_type', header: 'Coverage', render: (r) => r.coverage_type },
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category ?? '—' },
    { key: 'job_hours', header: 'Hours', render: (r) => r.job_hours },
    { key: 'revenue_rupees', header: 'Revenue', render: (r) => `Rs ${r.revenue_rupees ?? 0}` },
    { key: 'parts_cost_rupees', header: 'Parts', render: (r) => `Rs ${r.parts_cost_rupees ?? 0}` },
    { key: 'payout_rupees', header: 'Payout', render: (r) => `Rs ${r.payout_rupees ?? 0}` },
    { key: 'hospital_email', header: 'Hospital', render: (r) => r.hospital_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Warranty vs AMC Repair Mix</h1>
        <p className="text-sm text-gray-600 mt-1">
          Distribution of jobs by warranty vs AMC vs paid and revenue per engineer split (last 30 days).
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Total Jobs (30d)</div>
          <div className="text-xl font-semibold">{snapshot?.total_jobs ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Warranty Jobs</div>
          <div className="text-xl font-semibold">{snapshot?.warranty_jobs ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">AMC Jobs</div>
          <div className="text-xl font-semibold">{snapshot?.amc_jobs ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Paid Jobs</div>
          <div className="text-xl font-semibold">{snapshot?.paid_jobs ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-gray-500">Net Margin</div>
          <div className={`text-xl font-semibold ${(snapshot?.net_margin_rupees ?? 0) < 0 ? 'text-red-600' : 'text-green-600'}`}>
            Rs {snapshot?.net_margin_rupees ?? 0}
          </div>
        </div>
      </section>

      <section className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">Total Revenue (30d)</div>
          <div className="text-lg font-semibold">Rs {snapshot?.total_revenue_rupees ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">Total Payouts</div>
          <div className="text-lg font-semibold">Rs {snapshot?.total_payout_rupees ?? 0}</div>
        </div>
        <div className="rounded border p-3 bg-gray-50">
          <div className="text-xs text-gray-500">Parts Cost</div>
          <div className="text-lg font-semibold">Rs {snapshot?.total_parts_cost_rupees ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Coverage Distribution (30d)</h2>
        <DataTable
          rows={coverage}
          columns={coverageCols}
          emptyMessage="No coverage data."
          rowKey={(r) => r.coverage_type}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Revenue Split (30d)</h2>
        <DataTable
          rows={engineers}
          columns={engineerCols}
          emptyMessage="No engineer revenue data."
          rowKey={(r) => r.engineer_id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Trend (8 weeks)</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly trend data."
          rowKey={(r) => r.week_start}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Equipment Category Mix (30d)</h2>
        <DataTable
          rows={categories}
          columns={categoryCols}
          emptyMessage="No category data."
          rowKey={(r) => r.equipment_category}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Target vs Actual (Current Month)</h2>
        <DataTable
          rows={targets}
          columns={targetCols}
          emptyMessage="No targets set for current month."
          rowKey={(r) => r.engineer_id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Jobs (14d)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          emptyMessage="No recent jobs."
          rowKey={(r) => r.id}
        />
      </section>
    </div>
  );
}
