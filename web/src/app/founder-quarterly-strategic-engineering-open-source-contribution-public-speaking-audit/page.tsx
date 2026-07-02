import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type OssSummary = { quarter: string; contributions: number; prs_merged_total: number; hours_total: number; endorsed: number };
type TopOss = { engineer_name: string; contributions: number; avg_score: number; total_lines: number };
type OssByType = { contribution_type: string; n: number; endorsed: number; avg_hours: number };
type SpeakQ = { quarter: string; talks: number; attendees: number; views: number; pipeline_inr_total: number };
type TopTalk = { speaker_name: string; event_name: string; event_city: string; pipeline_inr: number; brand_lift_score: number };
type ByCountry = { event_country: string; talks: number; attendees: number; avg_brand_lift: number };
type Combined = { engineer_name: string; oss_contribs: number; talks: number; total_pipeline_inr: number; avg_strategic_score: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [a, b, c, d, e, f, g] = await Promise.all([
    supabase.rpc('r3021_quarterly_oss_summary'),
    supabase.rpc('r3021_top_oss_engineers'),
    supabase.rpc('r3021_oss_by_type'),
    supabase.rpc('r3021_speaking_quarterly'),
    supabase.rpc('r3021_top_talks_by_pipeline'),
    supabase.rpc('r3021_speaking_by_country'),
    supabase.rpc('r3021_engineer_combined_impact'),
  ]);

  const ossSummary = (a.data ?? []) as OssSummary[];
  const topOss = (b.data ?? []) as TopOss[];
  const ossByType = (c.data ?? []) as OssByType[];
  const speakQ = (d.data ?? []) as SpeakQ[];
  const topTalks = (e.data ?? []) as TopTalk[];
  const byCountry = (f.data ?? []) as ByCountry[];
  const combined = (g.data ?? []) as Combined[];

  const cOss: Column<OssSummary>[] = [
    { key: 'quarter', header: 'Quarter' },
    { key: 'contributions', header: 'Contribs' },
    { key: 'prs_merged_total', header: 'PRs merged' },
    { key: 'hours_total', header: 'Hours' },
    { key: 'endorsed', header: 'CEO endorsed' },
  ];

  const cTop: Column<TopOss>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'contributions', header: 'Contribs' },
    { key: 'avg_score', header: 'Avg score' },
    { key: 'total_lines', header: 'Total lines' },
  ];

  const cType: Column<OssByType>[] = [
    { key: 'contribution_type', header: 'Type' },
    { key: 'n', header: 'N' },
    { key: 'endorsed', header: 'Endorsed' },
    { key: 'avg_hours', header: 'Avg hours' },
  ];

  const cSpeak: Column<SpeakQ>[] = [
    { key: 'quarter', header: 'Quarter' },
    { key: 'talks', header: 'Talks' },
    { key: 'attendees', header: 'Attendees' },
    { key: 'views', header: 'Video views' },
    { key: 'pipeline_inr_total', header: 'Pipeline INR' },
  ];

  const cTalk: Column<TopTalk>[] = [
    { key: 'speaker_name', header: 'Speaker' },
    { key: 'event_name', header: 'Event' },
    { key: 'event_city', header: 'City' },
    { key: 'pipeline_inr', header: 'Pipeline INR' },
    { key: 'brand_lift_score', header: 'Brand lift' },
  ];

  const cCountry: Column<ByCountry>[] = [
    { key: 'event_country', header: 'Country' },
    { key: 'talks', header: 'Talks' },
    { key: 'attendees', header: 'Attendees' },
    { key: 'avg_brand_lift', header: 'Avg brand lift' },
  ];

  const cCombined: Column<Combined>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'oss_contribs', header: 'OSS' },
    { key: 'talks', header: 'Talks' },
    { key: 'total_pipeline_inr', header: 'Pipeline INR' },
    { key: 'avg_strategic_score', header: 'Avg score' },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Quarterly Strategic Engineering OSS &amp; Public-Speaking Audit</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Founder review of engineer open-source contributions &amp; conference talks. Strategic score &gt;= 75 =&gt; CEO endorsement track.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>OSS quarterly summary</h2>
        <DataTable rows={ossSummary} columns={cOss} emptyMessage="No OSS rows" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top OSS engineers</h2>
        <DataTable rows={topOss} columns={cTop} emptyMessage="No engineers" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>OSS by contribution type</h2>
        <DataTable rows={ossByType} columns={cType} emptyMessage="No types" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Speaking quarterly</h2>
        <DataTable rows={speakQ} columns={cSpeak} emptyMessage="No talks" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top talks by pipeline</h2>
        <DataTable rows={topTalks} columns={cTalk} emptyMessage="No top talks" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Speaking by country</h2>
        <DataTable rows={byCountry} columns={cCountry} emptyMessage="No countries" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer combined impact</h2>
        <DataTable rows={combined} columns={cCombined} emptyMessage="No data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </main>
  );
}
