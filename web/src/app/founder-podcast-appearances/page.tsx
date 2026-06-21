import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Appearance = {
  id: string;
  podcast_name: string;
  host_name: string | null;
  episode_title: string | null;
  episode_url: string | null;
  transcript_url: string | null;
  recorded_at: string;
  published_at: string | null;
  audience_size: number;
  topic: string | null;
  lead_count: number;
  total_audience: number;
};

type Lead = {
  id: string;
  appearance_id: string;
  podcast_name: string;
  lead_name: string;
  lead_org: string | null;
  lead_email: string | null;
  lead_phone: string | null;
  status: string;
  created_at: string;
};

type Summary = {
  total_appearances: number;
  total_audience: number;
  total_leads: number;
  converted_leads: number;
  last_recorded_at: string | null;
};

export default async function FounderPodcastAppearancesPage() {
  const sb = await getSupabaseServerClient();

  let appearances: Appearance[] = [];
  let leads: Lead[] = [];
  let summary: Summary | null = null;
  let errorMsg: string | null = null;

  try {
    const { data, error } = await sb.rpc('founder_list_podcast_appearances');
    if (error) throw error;
    appearances = (data ?? []) as Appearance[];
  } catch (e) {
    errorMsg = (e as Error).message;
  }

  try {
    const { data, error } = await sb.rpc('founder_list_podcast_leads');
    if (error) throw error;
    leads = (data ?? []) as Lead[];
  } catch (e) {
    errorMsg = errorMsg ?? (e as Error).message;
  }

  try {
    const { data, error } = await sb.rpc('founder_podcast_summary');
    if (error) throw error;
    const row = Array.isArray(data) ? data[0] : data;
    summary = (row ?? null) as Summary | null;
  } catch (e) {
    errorMsg = errorMsg ?? (e as Error).message;
  }

  const appearanceCols: Column<Appearance>[] = [
    { key: 'podcast_name', header: 'Podcast', render: (r) => r.podcast_name ?? '—' },
    { key: 'host_name', header: 'Host', render: (r) => r.host_name ?? '—' },
    { key: 'episode_title', header: 'Episode', render: (r) => r.episode_title ?? '—' },
    { key: 'topic', header: 'Topic', render: (r) => r.topic ?? '—' },
    { key: 'recorded_at', header: 'Recorded', render: (r) => new Date(r.recorded_at).toLocaleDateString() },
    { key: 'audience_size', header: 'Audience', render: (r) => r.audience_size.toLocaleString() },
    { key: 'lead_count', header: 'Leads', render: (r) => String(r.lead_count ?? 0) },
    {
      key: 'episode_url',
      header: 'Links',
      render: (r) => {
        const ep = r.episode_url;
        const tr = r.transcript_url;
        if (!ep && !tr) return '—';
        return (
          <span>
            {ep ? <a href={ep} target="_blank" rel="noreferrer" className="underline mr-2">episode</a> : null}
            {tr ? <a href={tr} target="_blank" rel="noreferrer" className="underline">transcript</a> : null}
          </span>
        );
      },
    },
  ];

  const leadCols: Column<Lead>[] = [
    { key: 'podcast_name', header: 'Podcast', render: (r) => r.podcast_name ?? '—' },
    { key: 'lead_name', header: 'Lead', render: (r) => r.lead_name ?? '—' },
    { key: 'lead_org', header: 'Org', render: (r) => r.lead_org ?? '—' },
    { key: 'lead_email', header: 'Email', render: (r) => r.lead_email ?? '—' },
    { key: 'lead_phone', header: 'Phone', render: (r) => r.lead_phone ?? '—' },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'created_at', header: 'Added', render: (r) => new Date(r.created_at).toLocaleDateString() },
  ];

  return (
    <main className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Founder Podcast Appearances</h1>
        <p className="text-sm text-gray-600">Log every podcast or interview — track audience reach, transcripts, and follow-up leads.</p>
      </div>

      {errorMsg ? (
        <div className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-700">{errorMsg}</div>
      ) : null}

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Appearances</div>
          <div className="text-xl font-semibold">{summary?.total_appearances ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total audience</div>
          <div className="text-xl font-semibold">{(summary?.total_audience ?? 0).toLocaleString()}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Follow-up leads</div>
          <div className="text-xl font-semibold">{summary?.total_leads ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Converted</div>
          <div className="text-xl font-semibold">{summary?.converted_leads ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Last recorded</div>
          <div className="text-sm font-semibold">{summary?.last_recorded_at ? new Date(summary.last_recorded_at).toLocaleDateString() : '—'}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Appearances</h2>
        <DataTable<Appearance> rows={appearances} columns={appearanceCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-up leads</h2>
        <DataTable<Lead> rows={leads} columns={leadCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
