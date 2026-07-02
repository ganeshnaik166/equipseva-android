import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type VoiceRow = {
  id: string;
  hospital_id: string;
  hospital_name: string;
  voice_text_md: string;
  voice_source: string;
  status: string;
  captured_at: string;
};

type SourceRow = {
  voice_source: string;
  voice_count: number;
  open_count: number;
};

type ActionRow = {
  id: string;
  voice_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  voice_source: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [voicesRes, sourcesRes, actionsRes] = await Promise.all([
    sb.rpc('list_voices_r2127'),
    sb.rpc('by_source_r2127'),
    sb.rpc('recent_actions_r2127'),
  ]);

  const voices: VoiceRow[] = (voicesRes.data as VoiceRow[] | null) ?? [];
  const sources: SourceRow[] = (sourcesRes.data as SourceRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];

  const voiceCols: Column<VoiceRow>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'voice_source', header: 'Source', render: (r: any) => String(r.voice_source ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'voice_text_md', header: 'Voice', render: (r: any) => String(r.voice_text_md ?? '').slice(0, 160) },
  ];

  const sourceCols: Column<SourceRow>[] = [
    { key: 'voice_source', header: 'Source', render: (r: any) => String(r.voice_source ?? '') },
    { key: 'voice_count', header: 'Voices', render: (r: any) => String(r.voice_count ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'voice_source', header: 'Source', render: (r: any) => String(r.voice_source ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'voice_id', header: 'Voice', render: (r: any) => String(r.voice_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Customer Voice of Operations</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Capture voice of ops at hospitals. Sources include daily huddle, incident review, quarterly check-in, audit, and staff meeting.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Voices by source</h2>
        <DataTable
          rows={sources}
          columns={sourceCols}
          rowKey={(r: any, i: number) => String(r.voice_source ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent captured voices</h2>
        <DataTable
          rows={voices}
          columns={voiceCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions taken</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
