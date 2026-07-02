import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [accessesRes, suspiciousRes, actionsRes] = await Promise.all([
    sb.rpc('list_accesses_r2061'),
    sb.rpc('suspicious_accesses_r2061'),
    sb.rpc('recent_actions_r2061'),
  ]);

  const accesses: any[] = (accessesRes.data as any[]) ?? [];
  const suspicious: any[] = (suspiciousRes.data as any[]) ?? [];
  const actions: any[] = (actionsRes.data as any[]) ?? [];

  const accessCols: Column<any>[] = [
    { key: 'document_label', header: 'Document', render: (r: any) => String(r.document_label ?? '') },
    { key: 'access_type', header: 'Access', render: (r: any) => String(r.access_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'ip_address', header: 'IP', render: (r: any) => String(r.ip_address ?? '') },
    { key: 'accessed_at', header: 'When', render: (r: any) => r.accessed_at ? new Date(r.accessed_at).toLocaleString() : '' },
  ];

  const suspiciousCols: Column<any>[] = [
    { key: 'document_label', header: 'Document', render: (r: any) => String(r.document_label ?? '') },
    { key: 'access_type', header: 'Access', render: (r: any) => String(r.access_type ?? '') },
    { key: 'status', header: 'Flag', render: (r: any) => String(r.status ?? '') },
    { key: 'ip_address', header: 'IP', render: (r: any) => String(r.ip_address ?? '') },
    { key: 'accessed_at', header: 'When', render: (r: any) => r.accessed_at ? new Date(r.accessed_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  const suspiciousCount = suspicious.length;

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Investor Data Room Audit Log</h1>
        <p className="text-sm text-gray-600">
          Every view, download, external share, and print of investor data room documents is logged here.
          Suspicious or blocked accesses are surfaced so founder can review and act.
        </p>
        <div className="text-sm">
          Total accesses: {accesses.length} · Suspicious or blocked: {suspiciousCount} · Recent actions: {actions.length}
        </div>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All accesses</h2>
        <DataTable rows={accesses} columns={accessCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Suspicious and blocked accesses</h2>
        <DataTable rows={suspicious} columns={suspiciousCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent founder actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
