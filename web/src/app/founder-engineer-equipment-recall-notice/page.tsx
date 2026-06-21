import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerEquipmentRecallNoticePage() {
  const sb = await getSupabaseServerClient();

  const [recallsRes, activeRes, summaryRes, responsesRes] = await Promise.all([
    sb.rpc('list_recalls_r1860'),
    sb.rpc('active_recalls_r1860'),
    sb.rpc('response_summary_r1860'),
    sb.rpc('list_responses_r1860', { p_recall_id: null }),
  ]);

  const recalls: any[] = Array.isArray(recallsRes.data) ? recallsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const responses: any[] = Array.isArray(responsesRes.data) ? responsesRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;

  const recallColumns: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => <span>{String(r.equipment_name ?? '')}</span> },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => <span>{String(r.manufacturer ?? '')}</span> },
    { key: 'recall_severity', header: 'Severity', render: (r: any) => <span style={{ textTransform: 'uppercase', fontWeight: 600 }}>{String(r.recall_severity ?? '')}</span> },
    { key: 'affected_units_count', header: 'Units', render: (r: any) => <span>{Number(r.affected_units_count ?? 0)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{String(r.status ?? '')}</span> },
    { key: 'deadline', header: 'Deadline', render: (r: any) => <span>{r.deadline ? String(r.deadline) : '—'}</span> },
    { key: 'recall_notice_at', header: 'Notice At', render: (r: any) => <span>{r.recall_notice_at ? new Date(r.recall_notice_at).toLocaleString() : '—'}</span> },
  ];

  const activeColumns: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => <span>{String(r.equipment_name ?? '')}</span> },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => <span>{String(r.manufacturer ?? '')}</span> },
    { key: 'recall_severity', header: 'Severity', render: (r: any) => <span style={{ textTransform: 'uppercase', fontWeight: 600 }}>{String(r.recall_severity ?? '')}</span> },
    { key: 'affected_units_count', header: 'Units', render: (r: any) => <span>{Number(r.affected_units_count ?? 0)}</span> },
    { key: 'deadline', header: 'Deadline', render: (r: any) => <span>{r.deadline ? String(r.deadline) : '—'}</span> },
    { key: 'days_to_deadline', header: 'Days Left', render: (r: any) => <span>{r.days_to_deadline === null || r.days_to_deadline === undefined ? '—' : Number(r.days_to_deadline)}</span> },
    { key: 'recall_notice_at', header: 'Notice At', render: (r: any) => <span>{r.recall_notice_at ? new Date(r.recall_notice_at).toLocaleString() : '—'}</span> },
  ];

  const responseColumns: Column<any>[] = [
    { key: 'recall_id', header: 'Recall', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: '0.85em' }}>{String(r.recall_id ?? '').slice(0, 8)}</span> },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: '0.85em' }}>{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: '0.85em' }}>{r.hospital_id ? String(r.hospital_id).slice(0, 8) : '—'}</span> },
    { key: 'response_status', header: 'Response', render: (r: any) => <span style={{ textTransform: 'uppercase', fontWeight: 600 }}>{String(r.response_status ?? '')}</span> },
    { key: 'action_taken_at', header: 'Action At', render: (r: any) => <span>{r.action_taken_at ? new Date(r.action_taken_at).toLocaleString() : '—'}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span>{r.notes ? String(r.notes) : '—'}</span> },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
          Engineer Equipment Recall Notice
        </h1>
        <p style={{ color: '#666', fontSize: '0.95rem' }}>
          Track equipment recall notices issued & engineer response across the fleet.
        </p>
      </header>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '0.75rem' }}>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Total Recalls</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{summary ? Number(summary.total_recalls ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Active</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{summary ? Number(summary.active_recalls ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Cleared</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{summary ? Number(summary.cleared_recalls ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #fecaca', background: '#fef2f2', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#991b1b' }}>Critical Active</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700, color: '#991b1b' }}>{summary ? Number(summary.critical_active ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Total Responses</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{summary ? Number(summary.total_responses ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Identified</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 700 }}>{summary ? Number(summary.identified_count ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Secured</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 700 }}>{summary ? Number(summary.secured_count ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Replaced</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 700 }}>{summary ? Number(summary.replaced_count ?? 0) : 0}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.8rem', color: '#666' }}>Documented</div>
            <div style={{ fontSize: '1.25rem', fontWeight: 700 }}>{summary ? Number(summary.documented_count ?? 0) : 0}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Active Recalls (priority by severity & deadline)
        </h2>
        <DataTable
          rows={active}
          columns={activeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>All Recall Notices</h2>
        <DataTable
          rows={recalls}
          columns={recallColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Engineer Response Log</h2>
        <DataTable
          rows={responses}
          columns={responseColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
