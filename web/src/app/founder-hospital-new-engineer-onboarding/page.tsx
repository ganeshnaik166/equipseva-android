import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [onboardingsRes, inProgressRes, summaryRes] = await Promise.all([
    sb.rpc('list_onboardings_r1863'),
    sb.rpc('in_progress_r1863'),
    sb.rpc('satisfaction_summary_r1863'),
  ]);

  const onboardings: any[] = Array.isArray(onboardingsRes.data) ? onboardingsRes.data : [];
  const inProgress: any[] = Array.isArray(inProgressRes.data) ? inProgressRes.data : [];
  const summaryRow: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;

  const onboardingCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'started_on', header: 'Started', render: (r: any) => r.started_on ? String(r.started_on) : '-' },
    { key: 'first_30d_review_at', header: '30d Review', render: (r: any) => r.first_30d_review_at ? String(r.first_30d_review_at) : '-' },
    { key: 'hospital_satisfaction_score', header: 'Hosp Score', render: (r: any) => r.hospital_satisfaction_score != null ? `${r.hospital_satisfaction_score}/10` : '-' },
    { key: 'engineer_satisfaction_score', header: 'Eng Score', render: (r: any) => r.engineer_satisfaction_score != null ? `${r.engineer_satisfaction_score}/10` : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  const inProgressCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'started_on', header: 'Started', render: (r: any) => r.started_on ? String(r.started_on) : '-' },
    { key: 'first_30d_review_at', header: '30d Review Due', render: (r: any) => r.first_30d_review_at ? String(r.first_30d_review_at) : '-' },
    { key: 'days_elapsed', header: 'Days Elapsed', render: (r: any) => `${r.days_elapsed ?? 0}` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital New Engineer Onboarding</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track first 30 days when new engineer assigned to hospital. Round r1863.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Satisfaction Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Completed</div>
            <div className="text-2xl font-bold">{summaryRow?.total_completed ?? 0}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Avg Hospital Score</div>
            <div className="text-2xl font-bold">
              {summaryRow?.avg_hospital_score != null ? Number(summaryRow.avg_hospital_score).toFixed(2) : '-'}
            </div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Avg Engineer Score</div>
            <div className="text-2xl font-bold">
              {summaryRow?.avg_engineer_score != null ? Number(summaryRow.avg_engineer_score).toFixed(2) : '-'}
            </div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Withdrew</div>
            <div className="text-2xl font-bold">{summaryRow?.withdrew_count ?? 0}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">In Progress (Active &lt; 30 days)</h2>
        <DataTable
          rows={inProgress}
          columns={inProgressCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Onboardings (latest 200)</h2>
        <DataTable
          rows={onboardings}
          columns={onboardingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
