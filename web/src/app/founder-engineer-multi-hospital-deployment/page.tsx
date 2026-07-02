import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const { data: deployments } = await sb.rpc('list_deployments_r2116');
  const { data: actives } = await sb.rpc('active_deployments_r2116');
  const { data: recents } = await sb.rpc('recent_actions_r2116');

  const deploymentRows: any[] = Array.isArray(deployments) ? deployments : [];
  const activeRows: any[] = Array.isArray(actives) ? actives : [];
  const recentRows: any[] = Array.isArray(recents) ? recents : [];

  const deploymentCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'deployment_role', header: 'Role', render: (r: any) => String(r.deployment_role ?? '') },
    { key: 'hospital_ids_array', header: 'Hospitals', render: (r: any) => String((r.hospital_ids_array ?? []).length) },
    { key: 'deployment_start_date', header: 'Start', render: (r: any) => String(r.deployment_start_date ?? '') },
    { key: 'deployment_end_date', header: 'End', render: (r: any) => String(r.deployment_end_date ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const activeCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'deployment_role', header: 'Role', render: (r: any) => String(r.deployment_role ?? '') },
    { key: 'hospital_ids_array', header: 'Hospital Count', render: (r: any) => String((r.hospital_ids_array ?? []).length) },
    { key: 'deployment_start_date', header: 'Since', render: (r: any) => String(r.deployment_start_date ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'deployment_id', header: 'Deployment', render: (r: any) => String(r.deployment_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => String(r.taken_at ?? '').slice(0, 19) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Multi-Hospital Deployment</h1>
        <p className="text-sm text-gray-600">Track engineers deployed across multiple hospitals plus action log.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Deployments</h2>
        <DataTable rows={deploymentRows} columns={deploymentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active Deployments</h2>
        <DataTable rows={activeRows} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable rows={recentRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
