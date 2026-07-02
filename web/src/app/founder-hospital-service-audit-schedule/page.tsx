import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AuditRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  audit_type: string;
  scheduled_date: string;
  status: string;
  completed_at: string | null;
  created_at: string;
};

type UpcomingRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  audit_type: string;
  scheduled_date: string;
  status: string;
  days_until: number | null;
};

type RecentActionRow = {
  id: string;
  schedule_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  audit_type: string | null;
  hospital_name: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, upcomingRes, actionsRes] = await Promise.all([
    sb.rpc('list_audits_r2099'),
    sb.rpc('upcoming_r2099'),
    sb.rpc('recent_actions_r2099'),
  ]);

  const audits: AuditRow[] = (auditsRes.data as AuditRow[] | null) ?? [];
  const upcoming: UpcomingRow[] = (upcomingRes.data as UpcomingRow[] | null) ?? [];
  const actions: RecentActionRow[] = (actionsRes.data as RecentActionRow[] | null) ?? [];

  const totalAudits = audits.length;
  const planned = audits.filter((a) => a.status === 'planned').length;
  const inProgress = audits.filter((a) => a.status === 'in_progress').length;
  const completed = audits.filter((a) => a.status === 'completed').length;
  const escalated = audits.filter((a) => a.status === 'escalated').length;

  const auditCols: Column<AuditRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? r.hospital_id },
    { key: 'audit_type', header: 'Type', render: (r: any) => r.audit_type },
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => r.scheduled_date },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'completed_at', header: 'Completed', render: (r: any) => (r.completed_at ? new Date(r.completed_at).toLocaleString() : '-') },
    { key: 'created_at', header: 'Created', render: (r: any) => new Date(r.created_at).toLocaleString() },
  ];

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? r.hospital_id },
    { key: 'audit_type', header: 'Type', render: (r: any) => r.audit_type },
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => r.scheduled_date },
    { key: 'days_until', header: 'Days Until', render: (r: any) => (r.days_until == null ? '-' : String(r.days_until)) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<RecentActionRow>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'audit_type', header: 'Audit Type', render: (r: any) => r.audit_type ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Audit Schedule</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Schedule and track service audits per hospital across operational, financial, quality, safety, regulatory, and customer satisfaction dimensions.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Stat label="Total Audits" value={totalAudits} />
        <Stat label="Planned" value={planned} />
        <Stat label="In Progress" value={inProgress} />
        <Stat label="Completed" value={completed} />
        <Stat label="Escalated" value={escalated} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Upcoming Audits</h2>
        <DataTable<UpcomingRow>
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Audits</h2>
        <DataTable<AuditRow>
          rows={audits}
          columns={auditCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable<RecentActionRow>
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
