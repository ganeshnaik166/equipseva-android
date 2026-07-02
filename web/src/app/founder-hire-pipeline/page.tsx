import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHirePipelinePage() {
  const sb = await getSupabaseServerClient();

  const [pipelineRes, stageRes, topRes] = await Promise.all([
    sb.rpc('list_pipeline_r1786'),
    sb.rpc('stage_summary_r1786'),
    sb.rpc('top_priority_roles_r1786'),
  ]);

  const pipeline: any[] = Array.isArray(pipelineRes.data) ? pipelineRes.data : [];
  const stages: any[] = Array.isArray(stageRes.data) ? stageRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];

  const pipelineCols: Column<any>[] = [
    { key: 'role_title', header: 'Role', render: (r: any) => String(r.role_title ?? '') },
    { key: 'role_type', header: 'Type', render: (r: any) => String(r.role_type ?? '') },
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'candidate_email', header: 'Email', render: (r: any) => String(r.candidate_email ?? '—') },
    { key: 'current_stage', header: 'Stage', render: (r: any) => String(r.current_stage ?? '') },
    { key: 'founder_priority', header: 'Priority', render: (r: any) => String(r.founder_priority ?? '') },
    {
      key: 'expected_close',
      header: 'Expected Close',
      render: (r: any) => (r.expected_close ? String(r.expected_close) : '—'),
    },
    {
      key: 'created_at',
      header: 'Created',
      render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'),
    },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => String(r.stage ?? '') },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? 0) },
    { key: 'high_count', header: 'High', render: (r: any) => String(r.high_count ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'role_title', header: 'Role', render: (r: any) => String(r.role_title ?? '') },
    { key: 'role_type', header: 'Type', render: (r: any) => String(r.role_type ?? '') },
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'current_stage', header: 'Stage', render: (r: any) => String(r.current_stage ?? '') },
    { key: 'founder_priority', header: 'Priority', render: (r: any) => String(r.founder_priority ?? '') },
    {
      key: 'expected_close',
      header: 'Expected Close',
      render: (r: any) => (r.expected_close ? String(r.expected_close) : '—'),
    },
    {
      key: 'days_to_close',
      header: 'Days To Close',
      render: (r: any) => (r.days_to_close == null ? '—' : String(r.days_to_close)),
    },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Hire Pipeline</h1>
        <p className="text-sm text-gray-600">
          Founder-owned hiring funnel for key roles. Tracks candidates from sourced through hired/declined,
          with founder-set priority and note history.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Priority Roles (Critical & High, Open)</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stage Summary</h2>
        <DataTable
          rows={stages}
          columns={stageCols}
          rowKey={(r: any, i: number) => String(r.stage ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Pipeline Candidates</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
