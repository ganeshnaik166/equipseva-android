import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCalendarAuditPage() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, topRes, actionsRes] = await Promise.all([
    sb.rpc('founder_calendar_audit_r2134_list_audits'),
    sb.rpc('founder_calendar_audit_r2134_top_weeks'),
    sb.rpc('founder_calendar_audit_r2134_recent_actions'),
  ]);

  const audits: any[] = Array.isArray(auditsRes.data) ? auditsRes.data : [];
  const topWeeks: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const totalAudits = audits.length;
  const avgScore = totalAudits
    ? Math.round(audits.reduce((s, r) => s + Number(r.audit_score || 0), 0) / totalAudits)
    : 0;
  const totalWasted = audits.reduce((s, r) => s + Number(r.wasted_hours || 0), 0);
  const totalProductive = audits.reduce((s, r) => s + Number(r.productive_hours || 0), 0);

  const auditCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'total_scheduled_hours', header: 'Scheduled hrs', render: (r: any) => String(r.total_scheduled_hours ?? 0) },
    { key: 'productive_hours', header: 'Productive hrs', render: (r: any) => String(r.productive_hours ?? 0) },
    { key: 'wasted_hours', header: 'Wasted hrs', render: (r: any) => String(r.wasted_hours ?? 0) },
    { key: 'audit_score', header: 'Score', render: (r: any) => String(r.audit_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'audit_score', header: 'Score', render: (r: any) => String(r.audit_score ?? 0) },
    { key: 'productive_hours', header: 'Productive hrs', render: (r: any) => String(r.productive_hours ?? 0) },
    { key: 'wasted_hours', header: 'Wasted hrs', render: (r: any) => String(r.wasted_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Founder Calendar Audit</h1>
        <p style={{ color: '#666' }}>
          Audit weekly calendar for wasted time and effective use. Track scheduled vs productive hours and log corrective actions.
        </p>
      </header>

      <section style={{ marginBottom: 28, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total audits</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalAudits}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Average score</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{avgScore}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total productive hrs</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalProductive}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total wasted hrs</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalWasted}</div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All weekly audits</h2>
        <DataTable rows={audits} columns={auditCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top scoring weeks</h2>
        <DataTable rows={topWeeks} columns={topCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent corrective actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <footer style={{ marginTop: 32, padding: 16, borderTop: '1px solid #e5e7eb', color: '#666', fontSize: 13 }}>
        Status legend uses excellent, good, needs work, and poor. Action types include meeting killed, batched, delegated, moved, escalated, and closed.
      </footer>
    </main>
  );
}
