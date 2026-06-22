import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerEquipmentFieldTestLogPage() {
  const sb = await getSupabaseServerClient();

  const [testsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_field_tests_r1884'),
    sb.rpc('top_recommended_field_tests_r1884'),
    sb.rpc('recent_field_test_observations_r1884'),
  ]);

  const tests: any[] = Array.isArray(testsRes.data) ? testsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const ongoingCount = tests.filter((t) => t.status === 'ongoing').length;
  const passedCount = tests.filter((t) => t.status === 'passed').length;
  const failedCount = tests.filter((t) => t.status === 'failed').length;
  const withdrawnCount = tests.filter((t) => t.status === 'withdrawn').length;

  const testCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'primary_use_case', header: 'Use Case', render: (r: any) => String(r.primary_use_case ?? '') },
    { key: 'test_duration_days', header: 'Duration (d)', render: (r: any) => String(r.test_duration_days ?? '') },
    { key: 'performance_score', header: 'Score', render: (r: any) => r.performance_score == null ? '—' : `${r.performance_score}/10` },
    { key: 'would_recommend', header: 'Recommend', render: (r: any) => r.would_recommend == null ? '—' : (r.would_recommend ? 'Yes' : 'No') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'observation_count', header: 'Obs', render: (r: any) => String(r.observation_count ?? 0) },
    { key: 'test_started_at', header: 'Started', render: (r: any) => r.test_started_at ? new Date(r.test_started_at).toLocaleDateString() : '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '') },
    { key: 'performance_score', header: 'Score', render: (r: any) => r.performance_score == null ? '—' : `${r.performance_score}/10` },
    { key: 'would_recommend', header: 'Recommend', render: (r: any) => r.would_recommend ? 'Yes' : 'No' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'test_started_at', header: 'Started', render: (r: any) => r.test_started_at ? new Date(r.test_started_at).toLocaleDateString() : '—' },
  ];

  const obsCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'observation_type', header: 'Type', render: (r: any) => String(r.observation_type ?? '') },
    { key: 'observation_text', header: 'Observation', render: (r: any) => String(r.observation_text ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—' },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight">Engineer Equipment Field Test Log</h1>
        <p className="text-sm text-neutral-600">
          Pilot new equipment in the field before recommending to hospitals. Engineers test devices over weeks &
          log observations — only equipment that passes goes into the recommended catalog.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Ongoing</div>
          <div className="text-2xl font-semibold mt-1">{ongoingCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Passed</div>
          <div className="text-2xl font-semibold mt-1">{passedCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Failed</div>
          <div className="text-2xl font-semibold mt-1">{failedCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Withdrawn</div>
          <div className="text-2xl font-semibold mt-1">{withdrawnCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All field tests</h2>
        <p className="text-sm text-neutral-600">
          Every active &amp; historical equipment pilot. Tests with score &gt;= 8 and would_recommend = true graduate
          to the recommended catalog.
        </p>
        <DataTable
          rows={tests}
          columns={testCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top recommended</h2>
        <p className="text-sm text-neutral-600">
          Passed tests where the engineer would recommend the equipment — sorted by performance score.
        </p>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent observations</h2>
        <p className="text-sm text-neutral-600">
          Latest field notes across all active tests — flagged "critical" observations need founder
          review within 24h.
        </p>
        <DataTable
          rows={recent}
          columns={obsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
