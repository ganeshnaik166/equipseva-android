import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalCoachingNotesPage() {
  const sb = await getSupabaseServerClient();

  const [notesRes, recentNotesRes, recentFollowupsRes] = await Promise.all([
    sb.rpc('list_coaching_notes_r2070'),
    sb.rpc('recent_coaching_notes_r2070', { p_limit: 25 }),
    sb.rpc('recent_coaching_followups_r2070', { p_limit: 50 }),
  ]);

  const notes: any[] = Array.isArray(notesRes.data) ? notesRes.data : [];
  const recentNotes: any[] = Array.isArray(recentNotesRes.data) ? recentNotesRes.data : [];
  const recentFollowups: any[] = Array.isArray(recentFollowupsRes.data) ? recentFollowupsRes.data : [];

  const fmtDate = (v: any) => {
    if (!v) return '';
    try { return new Date(String(v)).toLocaleDateString(); } catch { return String(v); }
  };
  const fmtDateTime = (v: any) => {
    if (!v) return '';
    try { return new Date(String(v)).toLocaleString(); } catch { return String(v); }
  };

  const notesColumns: Column<any>[] = [
    { key: 'session_date', header: 'Session', render: (r: any) => <span>{fmtDate(r.session_date)}</span> },
    { key: 'coach_name', header: 'Coach', render: (r: any) => <span>{r.coach_name ?? ''}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? ''}</span> },
    { key: 'key_themes_md', header: 'Themes', render: (r: any) => <span>{r.key_themes_md ?? ''}</span> },
    { key: 'breakthrough_md', header: 'Breakthrough', render: (r: any) => <span>{r.breakthrough_md ?? ''}</span> },
    { key: 'action_items_md', header: 'Action items', render: (r: any) => <span>{r.action_items_md ?? ''}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span>{fmtDateTime(r.captured_at)}</span> },
  ];

  const recentNotesColumns: Column<any>[] = [
    { key: 'session_date', header: 'Session', render: (r: any) => <span>{fmtDate(r.session_date)}</span> },
    { key: 'coach_name', header: 'Coach', render: (r: any) => <span>{r.coach_name ?? ''}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? ''}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span>{fmtDateTime(r.captured_at)}</span> },
  ];

  const recentFollowupsColumns: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => <span>{fmtDateTime(r.taken_at)}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span>{r.action_type ?? ''}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? ''}</span> },
    { key: 'note_id', header: 'Note', render: (r: any) => <span style={{ fontFamily: 'monospace', fontSize: 11 }}>{String(r.note_id ?? '').slice(0, 8)}</span> },
  ];

  const totalNotes = notes.length;
  const activeCount = notes.filter((n) => n.status === 'active').length;
  const closedCount = notes.filter((n) => n.status === 'closed').length;
  const archivedCount = notes.filter((n) => n.status === 'archived').length;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Personal Coaching Notes</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Notes captured from personal coaching sessions. Track themes, breakthroughs, and follow-up actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 6, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Total notes</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalNotes}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 6, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Active</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{activeCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 6, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Closed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{closedCount}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 6, minWidth: 140 }}>
            <div style={{ fontSize: 12, color: '#888' }}>Archived</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{archivedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All notes</h2>
        <DataTable
          rows={notes}
          columns={notesColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent notes</h2>
        <DataTable
          rows={recentNotes}
          columns={recentNotesColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent follow-ups</h2>
        <DataTable
          rows={recentFollowups}
          columns={recentFollowupsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
