import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalCustomerVoiceAggregatorPage() {
  const sb = await getSupabaseServerClient();

  const [voicesRes, sentimentRes, recentRes] = await Promise.all([
    sb.rpc('list_voices_r2035'),
    sb.rpc('by_sentiment_r2035'),
    sb.rpc('recent_actions_r2035'),
  ]);

  const voices: any[] = Array.isArray(voicesRes.data) ? voicesRes.data : [];
  const sentiments: any[] = Array.isArray(sentimentRes.data) ? sentimentRes.data : [];
  const recents: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const voiceCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'voice_source', header: 'Source', render: (r: any) => String(r.voice_source ?? '') },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => String(r.sentiment ?? '') },
    { key: 'voice_text_md', header: 'Voice', render: (r: any) => String(r.voice_text_md ?? '').slice(0, 120) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const sentimentCols: Column<any>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => String(r.sentiment ?? '') },
    { key: 'voice_count', header: 'Voices', render: (r: any) => String(r.voice_count ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => String(r.escalated_count ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 120) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Voice Aggregator</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Aggregate customer voice across surveys, calls, visits, social posts, email, and incidents. Track sentiment and follow-up actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Sentiment Roll-up</h2>
        <DataTable rows={sentiments} columns={sentimentCols} rowKey={(r: any, i: number) => String(r.sentiment ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Customer Voices</h2>
        <DataTable rows={voices} columns={voiceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Voice Actions</h2>
        <DataTable rows={recents} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
