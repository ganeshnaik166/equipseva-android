import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorAuditTrailCompliancePage() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, overdueRes, recentRes] = await Promise.all([
    sb.rpc('list_audits_r1981'),
    sb.rpc('overdue_audits_r1981'),
    sb.rpc('recent_actions_r1981'),
  ]);

  const audits = (auditsRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const totalAudits = audits.length;
  const openAudits = audits.filter((a) => a.status === 'open' || a.status === 'in_progress').length;
  const completedAudits = audits.filter((a) => a.status === 'complete').length;
  const escalated = audits.filter((a) => a.status === 'escalated').length;

  const auditCols: Column<any>[] = [
    { key: 'audit_label', header: 'Audit', render: (r: any) => r.audit_label ?? '' },
    { key: 'audit_type', header: 'Type', render: (r: any) => r.audit_type ?? '' },
    { key: 'fy_year', header: 'FY', render: (r: any) => r.fy_year ?? '' },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '' },
    { key: 'deadline_date', header: 'Deadline', render: (r: any) => r.deadline_date ?? '' },
    {
      key: 'days_to_deadline',
      header: 'Days left',
      render: (r: any) => (r.days_to_deadline === null || r.days_to_deadline === undefined ? '' : String(r.days_to_deadline)),
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    {
      key: 'requested_at',
      header: 'Requested',
      render: (r: any) => (r.requested_at ? new Date(r.requested_at).toLocaleDateString() : ''),
    },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'audit_label', header: 'Audit', render: (r: any) => r.audit_label ?? '' },
    { key: 'audit_type', header: 'Type', render: (r: any) => r.audit_type ?? '' },
    { key: 'fy_year', header: 'FY', render: (r: any) => r.fy_year ?? '' },
    { key: 'deadline_date', header: 'Deadline', render: (r: any) => r.deadline_date ?? '' },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => String(r.days_overdue ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'audit_label', header: 'Audit', render: (r: any) => r.audit_label ?? '' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    {
      key: 'taken_at',
      header: 'Taken at',
      render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : ''),
    },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Investor Audit Trail Compliance
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track audit requests per investor across financial, operational, regulatory, governance
        and security categories. Log actions and surface overdue items.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Summary</h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: '12px',
          }}
        >
          <Stat label="Total audits" value={String(totalAudits)} />
          <Stat label="Open or in progress" value={String(openAudits)} />
          <Stat label="Completed" value={String(completedAudits)} />
          <Stat label="Escalated" value={String(escalated)} />
          <Stat label="Overdue" value={String(overdue.length)} />
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Overdue audits (deadline past and not complete)
        </h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All audits</h2>
        <DataTable
          rows={audits}
          columns={auditCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Recent audit actions
        </h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: '8px',
        padding: '12px 16px',
        background: '#fff',
      }}
    >
      <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700 }}>{value}</div>
    </div>
  );
}
