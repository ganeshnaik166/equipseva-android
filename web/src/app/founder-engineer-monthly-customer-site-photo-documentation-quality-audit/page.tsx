import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: string; detail: string };
type LeaderRow = { engineer_code: string; engineer_name: string; hospital_name: string; visits_completed: number; photos_submitted: number; quality_score: number; reviewer_verdict: string };
type FailingRow = { engineer_code: string; engineer_name: string; hospital_name: string; city: string; quality_score: number; blurry_count: number; missing_serial_count: number; geotag_mismatch_count: number; reviewer_verdict: string };
type CategoryRow = { finding_category: string; total_count: number; critical_count: number; high_count: number; open_count: number; resolved_count: number };
type CriticalRow = { finding_date: string; engineer_name: string; hospital_name: string; finding_category: string; severity: string; description: string; remediation_status: string; coach_assigned: string };
type CityRow = { city: string; engineers: number; avg_quality: number; total_blurry: number; total_missing_serial: number; total_geotag_mismatch: number; failing_engineers: number };
type CoachRow = { coach_assigned: string; open_findings: number; critical_findings: number; retraining_cases: number; resolved_findings: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, leaderRes, failRes, catRes, critRes, cityRes, coachRes] = await Promise.all([
    supabase.rpc('r2910_kpi_summary'),
    supabase.rpc('r2910_engineer_leaderboard'),
    supabase.rpc('r2910_failing_engineers'),
    supabase.rpc('r2910_findings_by_category'),
    supabase.rpc('r2910_critical_findings'),
    supabase.rpc('r2910_city_rollup'),
    supabase.rpc('r2910_coach_workload'),
  ]);

  const kpis: KpiRow[] = (kpiRes.data ?? []) as KpiRow[];
  const leaders: LeaderRow[] = (leaderRes.data ?? []) as LeaderRow[];
  const failing: FailingRow[] = (failRes.data ?? []) as FailingRow[];
  const cats: CategoryRow[] = (catRes.data ?? []) as CategoryRow[];
  const crits: CriticalRow[] = (critRes.data ?? []) as CriticalRow[];
  const cities: CityRow[] = (cityRes.data ?? []) as CityRow[];
  const coaches: CoachRow[] = (coachRes.data ?? []) as CoachRow[];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'visits_completed', header: 'Visits', render: (r) => r.visits_completed },
    { key: 'photos_submitted', header: 'Photos', render: (r) => r.photos_submitted },
    { key: 'quality_score', header: 'Quality %', render: (r) => Number(r.quality_score).toFixed(1) },
    { key: 'reviewer_verdict', header: 'Verdict', render: (r) => r.reviewer_verdict },
  ];

  const failCols: Column<FailingRow>[] = [
    { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'quality_score', header: 'Quality %', render: (r) => Number(r.quality_score).toFixed(1) },
    { key: 'blurry_count', header: 'Blurry', render: (r) => r.blurry_count },
    { key: 'missing_serial_count', header: 'Missing Serial', render: (r) => r.missing_serial_count },
    { key: 'geotag_mismatch_count', header: 'Geotag Miss', render: (r) => r.geotag_mismatch_count },
    { key: 'reviewer_verdict', header: 'Verdict', render: (r) => r.reviewer_verdict },
  ];

  const catCols: Column<CategoryRow>[] = [
    { key: 'finding_category', header: 'Category', render: (r) => r.finding_category },
    { key: 'total_count', header: 'Total', render: (r) => r.total_count },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'high_count', header: 'High', render: (r) => r.high_count },
    { key: 'open_count', header: 'Open', render: (r) => r.open_count },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
  ];

  const critCols: Column<CriticalRow>[] = [
    { key: 'finding_date', header: 'Date', render: (r) => r.finding_date },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'finding_category', header: 'Category', render: (r) => r.finding_category },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'description', header: 'Issue', render: (r) => r.description },
    { key: 'remediation_status', header: 'Status', render: (r) => r.remediation_status },
    { key: 'coach_assigned', header: 'Coach', render: (r) => r.coach_assigned },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'engineers', header: 'Engineers', render: (r) => r.engineers },
    { key: 'avg_quality', header: 'Avg Quality %', render: (r) => Number(r.avg_quality).toFixed(2) },
    { key: 'total_blurry', header: 'Blurry', render: (r) => r.total_blurry },
    { key: 'total_missing_serial', header: 'Missing Serial', render: (r) => r.total_missing_serial },
    { key: 'total_geotag_mismatch', header: 'Geotag Miss', render: (r) => r.total_geotag_mismatch },
    { key: 'failing_engineers', header: 'Failing', render: (r) => r.failing_engineers },
  ];

  const coachCols: Column<CoachRow>[] = [
    { key: 'coach_assigned', header: 'Coach', render: (r) => r.coach_assigned },
    { key: 'open_findings', header: 'Open', render: (r) => r.open_findings },
    { key: 'critical_findings', header: 'Critical', render: (r) => r.critical_findings },
    { key: 'retraining_cases', header: 'Retraining', render: (r) => r.retraining_cases },
    { key: 'resolved_findings', header: 'Resolved', render: (r) => r.resolved_findings },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold">Engineer Monthly Customer Site Photo-Documentation Quality Audit</h1>
        <p className="text-gray-600">
          Founder console for grading every field engineer's monthly photo-documentation pack —
          quality scores, blurry/missing-serial/geotag findings, coach assignments & retraining flags.
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-3">KPI Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          {kpis.map((k, i) => (
            <div key={i} className="border rounded-lg p-3 bg-white shadow-sm">
              <div className="text-xs text-gray-500 uppercase">{k.metric}</div>
              <div className="text-2xl font-bold mt-1">{k.value}</div>
              <div className="text-xs text-gray-400 mt-1">{k.detail}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Engineer Quality Leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={leaderCols}
          emptyMessage="No engineer submissions this month."
          rowKey={(r, i) => String((r as { engineer_code?: string }).engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Failing Engineers — Rework Required</h2>
        <DataTable
          rows={failing}
          columns={failCols}
          emptyMessage="No engineers below quality threshold."
          rowKey={(r, i) => String((r as { engineer_code?: string }).engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Findings by Category</h2>
        <DataTable
          rows={cats}
          columns={catCols}
          emptyMessage="No findings recorded."
          rowKey={(r, i) => String((r as { finding_category?: string }).finding_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Critical & High-Severity Findings</h2>
        <DataTable
          rows={crits}
          columns={critCols}
          emptyMessage="No critical findings open."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">City Quality Rollup</h2>
        <DataTable
          rows={cities}
          columns={cityCols}
          emptyMessage="No city data."
          rowKey={(r, i) => String((r as { city?: string }).city ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Coach Workload</h2>
        <DataTable
          rows={coaches}
          columns={coachCols}
          emptyMessage="No coach assignments."
          rowKey={(r, i) => String((r as { coach_assigned?: string }).coach_assigned ?? i)}
        />
      </section>
    </div>
  );
}
