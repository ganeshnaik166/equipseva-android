import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AuditRow = {
  id: string;
  hospital_id: string;
  audit_label: string;
  audit_date: string;
  equipment_count: number;
  total_value_rupees: number;
  missing_count: number;
  status: string;
  captured_at: string;
};

type EscalatedRow = {
  id: string;
  hospital_id: string;
  audit_label: string;
  audit_date: string;
  missing_count: number;
  status: string;
};

type ActionRow = {
  id: string;
  audit_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, escalatedRes, actionsRes] = await Promise.all([
    sb.rpc('list_audits_r2023'),
    sb.rpc('escalated_audits_r2023'),
    sb.rpc('recent_actions_r2023'),
  ]);

  const audits: AuditRow[] = (auditsRes.data as AuditRow[]) ?? [];
  const escalated: EscalatedRow[] = (escalatedRes.data as EscalatedRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const auditCols: Column<AuditRow>[] = [
    { key: 'audit_label', header: 'Label', render: (r: any) => String(r.audit_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'audit_date', header: 'Date', render: (r: any) => String(r.audit_date ?? '') },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => String(r.equipment_count ?? 0) },
    { key: 'total_value_rupees', header: 'Value (Rs)', render: (r: any) => String(r.total_value_rupees ?? 0) },
    { key: 'missing_count', header: 'Missing', render: (r: any) => String(r.missing_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(String(r.captured_at)).toLocaleString() },
  ];

  const escalatedCols: Column<EscalatedRow>[] = [
    { key: 'audit_label', header: 'Label', render: (r: any) => String(r.audit_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'audit_date', header: 'Date', render: (r: any) => String(r.audit_date ?? '') },
    { key: 'missing_count', header: 'Missing', render: (r: any) => String(r.missing_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'audit_id', header: 'Audit', render: (r: any) => String(r.audit_id ?? '').slice(0, 8) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(String(r.taken_at)).toLocaleString() },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Equipment Inventory Audit</h1>
        <p className="text-sm text-gray-600">Periodic audits of hospital equipment inventory with status tracking and action log.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Audits</h2>
        <p className="text-sm text-gray-500 mb-2">Total audits tracked: {audits.length}</p>
        <DataTable rows={audits} columns={auditCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Escalated and Disputed</h2>
        <p className="text-sm text-gray-500 mb-2">Audits needing founder attention: {escalated.length}</p>
        <DataTable rows={escalated} columns={escalatedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <p className="text-sm text-gray-500 mb-2">Latest action log entries across all audits.</p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
