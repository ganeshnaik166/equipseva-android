import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CoverageRow = { city: string; month: string; target_sites: number; tested_sites: number; passed_sites: number; pass_pct: number | null; required_pass_pct: number };
type FailedRow = { site_code: string; site_name: string; city: string; ups_model: string; measured_backup_minutes: number; required_backup_minutes: number; battery_health_pct: number; tested_at: string };
type MarginalRow = { site_code: string; site_name: string; city: string; battery_health_pct: number; load_pct: number; measured_backup_minutes: number; notes: string | null };
type BucketRow = { bucket: string; site_count: number };
type SkippedRow = { site_code: string; site_name: string; city: string; test_month: string; test_result: string; notes: string | null };
type SlaRow = { city: string; sla_minutes: number; tested: number; breached: number; breach_pct: number | null };
type ModelRow = { ups_model: string; tests: number; pass_count: number; fail_count: number; avg_backup_minutes: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, failed, marginal, buckets, skipped, sla, models] = await Promise.all([
    supabase.rpc('r2926_ups_coverage_overview'),
    supabase.rpc('r2926_failed_sites_this_month'),
    supabase.rpc('r2926_marginal_watchlist'),
    supabase.rpc('r2926_battery_health_distribution'),
    supabase.rpc('r2926_skipped_or_overdue'),
    supabase.rpc('r2926_city_sla_breach'),
    supabase.rpc('r2926_ups_model_reliability'),
  ]);

  const overviewCols: Column<CoverageRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'month', header: 'Month', render: (r) => r.month },
    { key: 'target_sites', header: 'Target', render: (r) => r.target_sites },
    { key: 'tested_sites', header: 'Tested', render: (r) => r.tested_sites },
    { key: 'passed_sites', header: 'Passed', render: (r) => r.passed_sites },
    { key: 'pass_pct', header: 'Pass %', render: (r) => r.pass_pct ?? '—' },
    { key: 'required_pass_pct', header: 'Required %', render: (r) => r.required_pass_pct },
  ];

  const failedCols: Column<FailedRow>[] = [
    { key: 'site_code', header: 'Code', render: (r) => r.site_code },
    { key: 'site_name', header: 'Site', render: (r) => r.site_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'ups_model', header: 'UPS Model', render: (r) => r.ups_model },
    { key: 'measured_backup_minutes', header: 'Measured (min)', render: (r) => r.measured_backup_minutes },
    { key: 'required_backup_minutes', header: 'Required (min)', render: (r) => r.required_backup_minutes },
    { key: 'battery_health_pct', header: 'Battery %', render: (r) => r.battery_health_pct },
    { key: 'tested_at', header: 'Tested At', render: (r) => r.tested_at },
  ];

  const marginalCols: Column<MarginalRow>[] = [
    { key: 'site_code', header: 'Code', render: (r) => r.site_code },
    { key: 'site_name', header: 'Site', render: (r) => r.site_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'battery_health_pct', header: 'Battery %', render: (r) => r.battery_health_pct },
    { key: 'load_pct', header: 'Load %', render: (r) => r.load_pct },
    { key: 'measured_backup_minutes', header: 'Backup (min)', render: (r) => r.measured_backup_minutes },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const bucketCols: Column<BucketRow>[] = [
    { key: 'bucket', header: 'Battery Bucket', render: (r) => r.bucket },
    { key: 'site_count', header: 'Sites', render: (r) => r.site_count },
  ];

  const skippedCols: Column<SkippedRow>[] = [
    { key: 'site_code', header: 'Code', render: (r) => r.site_code },
    { key: 'site_name', header: 'Site', render: (r) => r.site_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'test_month', header: 'Month', render: (r) => r.test_month },
    { key: 'test_result', header: 'Result', render: (r) => r.test_result },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const slaCols: Column<SlaRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'sla_minutes', header: 'SLA (min)', render: (r) => r.sla_minutes },
    { key: 'tested', header: 'Tested', render: (r) => r.tested },
    { key: 'breached', header: 'Breached', render: (r) => r.breached },
    { key: 'breach_pct', header: 'Breach %', render: (r) => r.breach_pct ?? '—' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'ups_model', header: 'UPS Model', render: (r) => r.ups_model },
    { key: 'tests', header: 'Tests', render: (r) => r.tests },
    { key: 'pass_count', header: 'Pass', render: (r) => r.pass_count },
    { key: 'fail_count', header: 'Fail', render: (r) => r.fail_count },
    { key: 'avg_backup_minutes', header: 'Avg Backup (min)', render: (r) => r.avg_backup_minutes },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer-Site UPS Backup Coverage</h1>
        <p className="text-sm text-gray-600">Round r2926 — tested backup minutes vs SLA & battery health across hospital sites.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Coverage Overview</h2>
        <DataTable
          rows={(overview.data ?? []) as CoverageRow[]}
          columns={overviewCols}
          emptyMessage="No coverage targets defined."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failed Sites This Month</h2>
        <DataTable
          rows={(failed.data ?? []) as FailedRow[]}
          columns={failedCols}
          emptyMessage="No failed UPS tests this month."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Marginal Watchlist</h2>
        <DataTable
          rows={(marginal.data ?? []) as MarginalRow[]}
          columns={marginalCols}
          emptyMessage="No marginal sites — healthy fleet."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Battery Health Distribution</h2>
        <DataTable
          rows={(buckets.data ?? []) as BucketRow[]}
          columns={bucketCols}
          emptyMessage="No tests recorded."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Skipped / Overdue Tests</h2>
        <DataTable
          rows={(skipped.data ?? []) as SkippedRow[]}
          columns={skippedCols}
          emptyMessage="No skipped tests."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City SLA Breach (backup &lt; SLA minutes)</h2>
        <DataTable
          rows={(sla.data ?? []) as SlaRow[]}
          columns={slaCols}
          emptyMessage="No SLA data available."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">UPS Model Reliability</h2>
        <DataTable
          rows={(models.data ?? []) as ModelRow[]}
          columns={modelCols}
          emptyMessage="No model data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
