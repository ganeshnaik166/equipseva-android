import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type NoteRow = {
  id: string;
  investor_label: string;
  note_md: string;
  sensitivity: string;
  captured_at: string;
  status: string;
};

type SensitiveRow = {
  id: string;
  investor_label: string;
  sensitivity: string;
  captured_at: string;
  status: string;
};

type ActionRow = {
  id: string;
  note_id: string;
  investor_label: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
};

export default async function FounderInvestorBackchannelNotesPage() {
  const sb = await getSupabaseServerClient();

  const [notesRes, sensitiveRes, actionsRes] = await Promise.all([
    sb.rpc('list_backchannel_notes_r2086'),
    sb.rpc('sensitive_backchannel_notes_r2086'),
    sb.rpc('recent_backchannel_actions_r2086'),
  ]);

  const notes: NoteRow[] = (notesRes.data as NoteRow[] | null) ?? [];
  const sensitive: SensitiveRow[] = (sensitiveRes.data as SensitiveRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];

  const noteCols: Column<NoteRow>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'investor_label', header: 'Investor', render: (r: any) => r.investor_label ?? '' },
    { key: 'sensitivity', header: 'Sensitivity', render: (r: any) => r.sensitivity ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'note_md', header: 'Note', render: (r: any) => {
      const s = String(r.note_md ?? '');
      return s.length > 160 ? s.slice(0, 160) + '...' : s;
    } },
  ];

  const sensitiveCols: Column<SensitiveRow>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'investor_label', header: 'Investor', render: (r: any) => r.investor_label ?? '' },
    { key: 'sensitivity', header: 'Sensitivity', render: (r: any) => r.sensitivity ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'investor_label', header: 'Investor', render: (r: any) => r.investor_label ?? '' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
  ];

  return (
    <main style={{ maxWidth: 1200, margin: '0 auto', padding: '24px' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Backchannel Notes</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Private notes from investor conversations. Founder-only view. Sensitivity flags gate downstream sharing.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Notes</h2>
        <DataTable
          rows={notes}
          columns={noteCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Sensitive Active Notes</h2>
        <p style={{ color: '#777', fontSize: 13, marginBottom: 8 }}>
          Founder-only and highly confidential notes currently active.
        </p>
        <DataTable
          rows={sensitive}
          columns={sensitiveCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
