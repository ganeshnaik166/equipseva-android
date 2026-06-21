import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalQbrNotesPage() {
  const sb = await getSupabaseServerClient();

  const [qbrsRes, followupsRes, summaryRes, recentRes] = await Promise.all([
    sb.rpc('list_qbrs_r1819', { p_limit: 100 }),
    sb.rpc('list_followups_r1819', { p_qbr_id: null }),
    sb.rpc('hospital_qbr_summary_r1819'),
    sb.rpc('recent_qbrs_r1819', { p_days: 90 }),
  ]);

  const qbrs: any[] = Array.isArray(qbrsRes.data) ? qbrsRes.data : [];
  const followups: any[] = Array.isArray(followupsRes.data) ? followupsRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const errors = [qbrsRes.error, followupsRes.error, summaryRes.error, recentRes.error]
    .filter(Boolean)
    .map((e: any) => e?.message || String(e));

  const qbrCols: Column<any>[] = [
    { key: 'qbr_date', header: 'Date', render: (r: any) => String(r.qbr_date ?? '') },
    { key: 'quarter', header: 'Quarter', render: (r: any) => String(r.quarter ?? '') },
    { key: 'hospital_org', header: 'Hospital', render: (r: any) => String(r.hospital_org ?? r.hospital_email ?? '-') },
    { key: 'attendees', header: 'Attendees', render: (r: any) => Array.isArray(r.attendees) ? r.attendees.join(', ') : '-' },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: any) => r.satisfaction_score == null ? '-' : `${r.satisfaction_score}/10` },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '-' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'task_text', header: 'Task', render: (r: any) => String(r.task_text ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '-') },
    { key: 'quarter', header: 'Quarter', render: (r: any) => String(r.quarter ?? '-') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '-') },
    { key: 'due_date', header: 'Due', render: (r: any) => String(r.due_date ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleString() : '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'qbr_date', header: 'Date', render: (r: any) => String(r.qbr_date ?? '') },
    { key: 'quarter', header: 'Quarter', render: (r: any) => String(r.quarter ?? '') },
    { key: 'hospital_org', header: 'Hospital', render: (r: any) => String(r.hospital_org ?? r.hospital_email ?? '-') },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: any) => r.satisfaction_score == null ? '-' : `${r.satisfaction_score}/10` },
    { key: 'open_followup_count', header: 'Open Followups', render: (r: any) => String(r.open_followup_count ?? 0) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Hospital QBR Notes</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Detailed quarterly business review notes per hospital — wins, concerns, goals, action items, and follow-up tasks.
        </p>
      </header>

      {errors.length > 0 && (
        <section style={{ marginBottom: 24, padding: 12, background: '#fee', border: '1px solid #fbb', borderRadius: 6 }}>
          <strong style={{ color: '#900' }}>Errors:</strong>
          <ul style={{ marginTop: 8, paddingLeft: 20 }}>
            {errors.map((e, i) => (
              <li key={i} style={{ color: '#900', fontSize: 13 }}>{e}</li>
            ))}
          </ul>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <Stat label="Total QBRs" value={summary?.total_qbrs ?? 0} />
          <Stat label="Unique Hospitals" value={summary?.unique_hospitals ?? 0} />
          <Stat label="Avg CSAT" value={summary?.avg_satisfaction == null ? '-' : `${summary.avg_satisfaction}/10`} />
          <Stat label="Open Followups" value={summary?.open_followups ?? 0} />
          <Stat label="Overdue" value={summary?.overdue_followups ?? 0} accent="#c00" />
          <Stat label="Done" value={summary?.done_followups ?? 0} accent="#0a7" />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent QBRs (last 90 days)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All QBRs</h2>
        <DataTable
          rows={qbrs}
          columns={qbrCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Follow-up Tasks</h2>
        <DataTable
          rows={followups}
          columns={followupCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ marginTop: 32, paddingTop: 16, borderTop: '1px solid #eee', fontSize: 12, color: '#888' }}>
        Round 1819 — founder-only. Writes log to founder_action_log.
      </footer>
    </main>
  );
}

function Stat({ label, value, accent }: { label: string; value: any; accent?: string }) {
  return (
    <div style={{ padding: 12, background: '#fafafa', border: '1px solid #eee', borderRadius: 6 }}>
      <div style={{ fontSize: 11, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: accent ?? '#111', marginTop: 4 }}>{String(value)}</div>
    </div>
  );
}
