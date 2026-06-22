import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [innovationsRes, byStageRes, recentRes] = await Promise.all([
    sb.rpc('list_innovations_r2027'),
    sb.rpc('by_stage_r2027'),
    sb.rpc('recent_stages_r2027'),
  ]);

  const innovations: any[] = (innovationsRes.data as any[]) ?? [];
  const byStage: any[] = (byStageRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const innovationsCols: Column<any>[] = [
    { key: 'label', header: 'Innovation', render: (r: any) => String(r.innovation_label ?? '') },
    { key: 'hospital', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'stage', header: 'Stage', render: (r: any) => String(r.stage ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'value', header: 'Est. Value (rupees)', render: (r: any) => Number(r.estimated_value_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'captured', header: 'Captured At', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '' },
  ];

  const byStageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => String(r.stage ?? '') },
    { key: 'n', header: 'Count', render: (r: any) => String(r.n ?? 0) },
    { key: 'val', header: 'Total Value (rupees)', render: (r: any) => Number(r.total_value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'label', header: 'Innovation', render: (r: any) => String(r.innovation_label ?? '') },
    { key: 'action', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Service Innovation Pipeline</h1>
        <p className="text-sm text-gray-600">Track innovation pipeline per hospital from ideation to roll-out.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pipeline by Stage</h2>
        <DataTable rows={byStage} columns={byStageCols} rowKey={(r: any, i: number) => String(r.stage ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Innovations</h2>
        <DataTable rows={innovations} columns={innovationsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Stage Activity</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
