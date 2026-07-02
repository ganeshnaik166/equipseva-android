import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SampleRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  sample_date: string | null;
  response_text_md: string | null;
  response_rating: number | null;
  sentiment: string | null;
  status: string | null;
  captured_at: string | null;
};

type LowRow = {
  id: string;
  hospital_id: string;
  hospital_name: string | null;
  response_rating: number | null;
  sentiment: string | null;
  status: string | null;
  captured_at: string | null;
};

type ActionRow = {
  id: string;
  sample_id: string;
  action_type: string;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [samplesRes, lowRes, actionsRes] = await Promise.all([
    sb.rpc('list_samples_r2163'),
    sb.rpc('low_ratings_r2163'),
    sb.rpc('recent_actions_r2163'),
  ]);

  const samples: SampleRow[] = (samplesRes.data as SampleRow[] | null) ?? [];
  const lows: LowRow[] = (lowRes.data as LowRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];

  const sampleCols: Column<SampleRow>[] = [
    { key: 'sample_date', header: 'Date', render: (r: any) => r.sample_date ?? '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? r.hospital_id?.slice(0, 8) ?? '' },
    { key: 'response_rating', header: 'Rating', render: (r: any) => (r.response_rating ?? '') + ' / 10' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'response_text_md', header: 'Response', render: (r: any) => (r.response_text_md ?? '').slice(0, 120) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ?? '').slice(0, 16).replace('T', ' ') },
  ];

  const lowCols: Column<LowRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? r.hospital_id?.slice(0, 8) ?? '' },
    { key: 'response_rating', header: 'Rating', render: (r: any) => String(r.response_rating ?? '') },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ?? '').slice(0, 16).replace('T', ' ') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ?? '').slice(0, 16).replace('T', ' ') },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'sample_id', header: 'Sample', render: (r: any) => (r.sample_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 120) },
  ];

  const totalSamples = samples.length;
  const lowCount = lows.length;
  const escalated = samples.filter((s) => s.status === 'escalated').length;
  const closed = samples.filter((s) => s.status === 'closed').length;

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Voice Sampling</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Random surveys capture customer voice. Track sentiment, follow up on low ratings, escalate concerns.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Recent Samples</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{totalSamples}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Low Ratings (rating &lt;= 5)</div>
          <div style={{ fontSize: 22, fontWeight: 600, color: '#c00' }}>{lowCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Escalated</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{escalated}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Closed</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{closed}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Voice Samples</h2>
        <DataTable rows={samples} columns={sampleCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Low Ratings — Needs Follow Up</h2>
        <p style={{ fontSize: 13, color: '#666', marginBottom: 8 }}>
          Samples with rating five or lower. Reach out, address concerns, then mark closed.
        </p>
        <DataTable rows={lows} columns={lowCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Action Log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
