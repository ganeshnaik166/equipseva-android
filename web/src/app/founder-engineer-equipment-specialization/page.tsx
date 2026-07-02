import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [specsRes, topRes, milestonesRes] = await Promise.all([
    sb.rpc('list_specializations_r1916'),
    sb.rpc('top_specializations_r1916'),
    sb.rpc('recent_milestones_r1916'),
  ]);

  const specs: any[] = Array.isArray(specsRes.data) ? specsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const milestones: any[] = Array.isArray(milestonesRes.data) ? milestonesRes.data : [];

  const specCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'certification_level', header: 'Cert level', render: (r: any) => r.certification_level ?? '—' },
    { key: 'jobs_completed_in_category', header: 'Jobs done', render: (r: any) => String(r.jobs_completed_in_category ?? 0) },
    { key: 'last_job_at', header: 'Last job', render: (r: any) => r.last_job_at ? new Date(r.last_job_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'certification_level', header: 'Cert level', render: (r: any) => r.certification_level ?? '—' },
    { key: 'engineer_count', header: 'Active engineers', render: (r: any) => String(r.engineer_count ?? 0) },
    { key: 'total_jobs', header: 'Total jobs', render: (r: any) => String(r.total_jobs ?? 0) },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'milestone_type', header: 'Milestone', render: (r: any) => r.milestone_type ?? '—' },
    { key: 'score', header: 'Score', render: (r: any) => r.score != null ? String(r.score) : '—' },
    { key: 'milestone_at', header: 'When', render: (r: any) => r.milestone_at ? new Date(r.milestone_at).toLocaleString() : '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Equipment Specialization</h1>
        <p className="text-sm text-gray-600">
          Track which equipment categories each engineer specializes in, with cert ladder from trainee through master.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top specializations by active engineer count</h2>
        <p className="text-sm text-gray-500">
          Grouped by category and cert level. Use to spot gaps where active engineer count is less than three.
        </p>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.equipment_category) + '-' + String(r.certification_level) + '-' + String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All specializations</h2>
        <p className="text-sm text-gray-500">
          Latest 200 records. Engineers at master or expert level with at least five jobs done qualify for chain-wide deployment.
        </p>
        <DataTable
          rows={specs}
          columns={specCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent milestones</h2>
        <p className="text-sm text-gray-500">
          Latest 50 milestone events. Score above 80 on expert review unlocks master review eligibility.
        </p>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
