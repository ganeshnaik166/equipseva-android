import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type NoteRow = {
  id: string;
  investor_id: string;
  round_label: string;
  negotiation_topic: string;
  our_position: string;
  their_position: string;
  status: string;
  resolution_at: string | null;
  change_count: number;
  created_at: string;
};

type SummaryRow = {
  investor_id: string;
  round_label: string;
  total_topics: number;
  pending_count: number;
  aligned_count: number;
  concerns_count: number;
  blocked_count: number;
};

type ChangeRow = {
  id: string;
  note_id: string;
  investor_id: string;
  round_label: string;
  negotiation_topic: string;
  version: number;
  change_at: string;
  change_by_email: string | null;
  change_summary: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [notesRes, summaryRes, recentRes] = await Promise.all([
    sb.rpc('list_notes_r1773'),
    sb.rpc('open_negotiations_summary_r1773'),
    sb.rpc('recent_changes_r1773'),
  ]);

  const notes: NoteRow[] = (notesRes.data as NoteRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const recent: ChangeRow[] = (recentRes.data as ChangeRow[] | null) ?? [];

  const noteCols: Column<NoteRow>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label },
    { key: 'negotiation_topic', header: 'Topic', render: (r: any) => r.negotiation_topic },
    { key: 'our_position', header: 'Our position', render: (r: any) => r.our_position ?? '—' },
    { key: 'their_position', header: 'Their position', render: (r: any) => r.their_position ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'change_count', header: 'Changes', render: (r: any) => r.change_count },
    { key: 'resolution_at', header: 'Resolved', render: (r: any) => r.resolution_at ?? '—' },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label },
    { key: 'total_topics', header: 'Total topics', render: (r: any) => r.total_topics },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
    { key: 'aligned_count', header: 'Aligned', render: (r: any) => r.aligned_count },
    { key: 'concerns_count', header: 'Concerns', render: (r: any) => r.concerns_count },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => r.blocked_count },
  ];

  const recentCols: Column<ChangeRow>[] = [
    { key: 'change_at', header: 'When', render: (r: any) => r.change_at },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
    { key: 'round_label', header: 'Round', render: (r: any) => r.round_label },
    { key: 'negotiation_topic', header: 'Topic', render: (r: any) => r.negotiation_topic },
    { key: 'version', header: 'Ver', render: (r: any) => r.version },
    { key: 'change_by_email', header: 'By', render: (r: any) => r.change_by_email ?? '—' },
    { key: 'change_summary', header: 'Summary', render: (r: any) => r.change_summary ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Round Negotiation Notes</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round-specific term-sheet negotiation tracker per investor. Topics include valuation, board seat, preferred terms,
        pro-rata, protective provisions, and anti-dilution. Each note carries our position vs theirs and a status flag.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open negotiations summary ({summary.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Per investor + round, count of topics in each status bucket. Use this to spot rounds with many blocked or concerns rows.
        </p>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String((r.investor_id ?? '') + '-' + (r.round_label ?? '') + '-' + i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All negotiation notes ({notes.length})</h2>
        <DataTable
          rows={notes}
          columns={noteCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent changes ({recent.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Last 50 change entries across all notes, newest first. Each row is one version bump on a single note.
        </p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
