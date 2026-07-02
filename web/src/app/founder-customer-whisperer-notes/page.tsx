import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerWhispererNotesPage() {
  const sb = await getSupabaseServerClient();

  const [notesRes, linksRes, latestRes, distRes, recentRes] = await Promise.all([
    sb.rpc('list_notes_r1858'),
    sb.rpc('list_links_r1858'),
    sb.rpc('latest_per_hospital_r1858'),
    sb.rpc('sensitivity_distribution_r1858'),
    sb.rpc('recent_notes_r1858'),
  ]);

  const notes: any[] = Array.isArray(notesRes.data) ? notesRes.data : [];
  const links: any[] = Array.isArray(linksRes.data) ? linksRes.data : [];
  const latest: any[] = Array.isArray(latestRes.data) ? latestRes.data : [];
  const dist: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const notesCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: 'topic', header: 'Topic', render: (r: any) => <span>{r.note_topic}</span> },
    { key: 'sens', header: 'Sensitivity', render: (r: any) => <span className="text-xs">{r.sensitivity}</span> },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs">{String(r.note_md ?? '').slice(0, 100)}</span> },
    { key: 'when', header: 'Recorded', render: (r: any) => <span className="text-xs text-gray-500">{r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '-'}</span> },
  ];

  const linksCols: Column<any>[] = [
    { key: 'note', header: 'Note', render: (r: any) => <span className="font-mono text-xs">{String(r.note_id ?? '').slice(0, 8)}</span> },
    { key: 'linked', header: 'Linked Note', render: (r: any) => <span className="font-mono text-xs">{String(r.linked_note_id ?? '').slice(0, 8)}</span> },
    { key: 'type', header: 'Link Type', render: (r: any) => <span>{r.link_type}</span> },
    { key: 'when', header: 'Created', render: (r: any) => <span className="text-xs text-gray-500">{r.created_at ? new Date(r.created_at).toLocaleString() : '-'}</span> },
  ];

  const latestCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: 'count', header: 'Notes', render: (r: any) => <span className="font-mono">{r.note_count ?? 0}</span> },
    { key: 'topic', header: 'Last Topic', render: (r: any) => <span>{r.last_topic ?? '-'}</span> },
    { key: 'sens', header: 'Last Sensitivity', render: (r: any) => <span className="text-xs">{r.last_sensitivity ?? '-'}</span> },
    { key: 'when', header: 'Last Recorded', render: (r: any) => <span className="text-xs text-gray-500">{r.last_recorded_at ? new Date(r.last_recorded_at).toLocaleString() : '-'}</span> },
  ];

  const distCols: Column<any>[] = [
    { key: 'sens', header: 'Sensitivity', render: (r: any) => <span>{r.sensitivity}</span> },
    { key: 'count', header: 'Note Count', render: (r: any) => <span className="font-mono">{r.note_count ?? 0}</span> },
    { key: 'topics', header: 'Topic Breakdown', render: (r: any) => <span className="text-xs font-mono">{JSON.stringify(r.topic_breakdown ?? {})}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{r.hospital_email ?? r.hospital_user_id?.slice(0, 8)}</span> },
    { key: 'topic', header: 'Topic', render: (r: any) => <span>{r.note_topic}</span> },
    { key: 'sens', header: 'Sensitivity', render: (r: any) => <span className="text-xs">{r.sensitivity}</span> },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-xs">{String(r.note_md ?? '').slice(0, 80)}</span> },
    { key: 'hours', header: 'Hours Ago', render: (r: any) => <span className="font-mono text-xs">{r.hours_ago != null ? Number(r.hours_ago).toFixed(1) : '-'}</span> },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Customer Whisperer Notes</h1>
        <p className="text-sm text-gray-600 mt-1">
          Private founder notes per customer — relationship intelligence (decision-maker psych, family context, risk signals & champion moments).
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Latest per hospital</h2>
        <DataTable rows={latest} columns={latestCols} rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Sensitivity distribution</h2>
        <DataTable rows={dist} columns={distCols} rowKey={(r: any, i: number) => String(r.sensitivity ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent notes (last 14 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All notes</h2>
        <DataTable rows={notes} columns={notesCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Note links</h2>
        <DataTable rows={links} columns={linksCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
