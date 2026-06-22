import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [validationsRes, expiringRes, actionsRes, recentRes] = await Promise.all([
    sb.rpc('list_skill_validations_r1944'),
    sb.rpc('expiring_skill_validations_r1944'),
    sb.rpc('list_skill_actions_r1944'),
    sb.rpc('recent_skill_actions_r1944'),
  ]);

  const validations: any[] = Array.isArray(validationsRes.data) ? validationsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalValid = validations.filter((v) => v.status === 'valid').length;
  const totalExpired = validations.filter((v) => v.status === 'expired').length;
  const totalRevoked = validations.filter((v) => v.status === 'revoked').length;

  const validationCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id ?? '-' },
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '-' },
    { key: 'validation_method', header: 'Method', render: (r: any) => r.validation_method ?? '-' },
    { key: 'validated_at', header: 'Validated', render: (r: any) => r.validated_at ? new Date(r.validated_at).toLocaleDateString() : '-' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'validator_email', header: 'Validator', render: (r: any) => r.validator_email ?? '-' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '-' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '-' },
    { key: 'days_left', header: 'Days Left', render: (r: any) => String(r.days_left ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Engineer Skill Validation Audit</h1>
      <p style={{ color: '#666', marginBottom: 16, fontSize: 13 }}>
        Track which engineer skills validated and when. Round r1944.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 20 }}>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#6b7280' }}>Total Validations</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{validations.length}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#6b7280' }}>Valid</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#16a34a' }}>{totalValid}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#6b7280' }}>Expired</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#dc2626' }}>{totalExpired}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 11, color: '#6b7280' }}>Revoked</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#a16207' }}>{totalRevoked}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All Skill Validations</h2>
        <DataTable rows={validations} columns={validationCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Expiring Soon (next 60 days)</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Revalidation Action Log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Actions (last 30 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
