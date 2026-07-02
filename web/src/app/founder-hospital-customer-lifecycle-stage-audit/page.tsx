import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AuditRow = {
  id: string;
  hospital_id: string;
  current_stage: string;
  days_in_current_stage: number;
  ideal_next_stage: string | null;
  status: string;
  captured_at: string;
};

type CriticalRow = {
  id: string;
  hospital_id: string;
  current_stage: string;
  days_in_current_stage: number;
  status: string;
  captured_at: string;
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

  const [auditsRes, criticalRes, actionsRes] = await Promise.all([
    sb.rpc('list_lifecycle_audits_r2143'),
    sb.rpc('critical_lifecycle_stages_r2143'),
    sb.rpc('recent_lifecycle_actions_r2143'),
  ]);

  const audits: AuditRow[] = (auditsRes.data as AuditRow[]) ?? [];
  const critical: CriticalRow[] = (criticalRes.data as CriticalRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const auditColumns: Column<AuditRow>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'current_stage', header: 'Current Stage', render: (r: any) => String(r.current_stage ?? '') },
    { key: 'days_in_current_stage', header: 'Days In Stage', render: (r: any) => String(r.days_in_current_stage ?? 0) },
    { key: 'ideal_next_stage', header: 'Ideal Next', render: (r: any) => String(r.ideal_next_stage ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 19) },
  ];

  const criticalColumns: Column<CriticalRow>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'current_stage', header: 'Stage', render: (r: any) => String(r.current_stage ?? '') },
    { key: 'days_in_current_stage', header: 'Days', render: (r: any) => String(r.days_in_current_stage ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 19) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'audit_id', header: 'Audit', render: (r: any) => String(r.audit_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => String(r.taken_at ?? '').slice(0, 19) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 600, marginBottom: 4 }}>
        Hospital Customer Lifecycle Stage Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 16, fontSize: 13 }}>
        Audit which lifecycle stage each hospital customer occupies. Stages flow trial to active to scaling, with at risk and churning as warning lanes.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>
          Recent Audits ({audits.length})
        </h2>
        <DataTable
          rows={audits}
          columns={auditColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>
          Critical and Concerning Stages ({critical.length})
        </h2>
        <p style={{ color: '#666', fontSize: 12, marginBottom: 8 }}>
          Hospitals flagged at risk or churning, plus any audit marked critical or concerning.
        </p>
        <DataTable
          rows={critical}
          columns={criticalColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>
          Recent Actions Taken ({actions.length})
        </h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
