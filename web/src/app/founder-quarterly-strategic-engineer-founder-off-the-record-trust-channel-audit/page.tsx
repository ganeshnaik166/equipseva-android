import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type Overview = { total_sessions: number; completed_sessions: number; avg_candor: number; avg_trust: number; action_required: number };
type RegionRow = { region: string; sessions: number; avg_candor: number; avg_trust: number; action_pct: number };
type TierRow = { engineer_tier: string; sessions: number; avg_candor: number; avg_themes: number };
type ChannelRow = { channel: string; sessions: number; avg_duration: number; avg_trust: number };
type ThemeRow = { theme_code: string; theme_title: string; category: string; mentions: number; urgency: string; status: string; blast: string };
type CategoryRow = { category: string; themes: number; total_mentions: number; open_themes: number; avg_impact: number };
type UrgentRow = { theme_code: string; theme_title: string; urgency: string; status: string; impact: number; surfaced: string; blast: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [overview, regions, tiers, channels, topThemes, categories, urgent] = await Promise.all([
    supabase.rpc('rpc_r3061_session_overview'),
    supabase.rpc('rpc_r3061_sessions_by_region'),
    supabase.rpc('rpc_r3061_sessions_by_tier'),
    supabase.rpc('rpc_r3061_channel_mix'),
    supabase.rpc('rpc_r3061_top_themes'),
    supabase.rpc('rpc_r3061_themes_by_category'),
    supabase.rpc('rpc_r3061_urgent_themes'),
  ]);

  const ov = (overview.data?.[0] ?? null) as Overview | null;
  const regionRows = (regions.data ?? []) as RegionRow[];
  const tierRows = (tiers.data ?? []) as TierRow[];
  const channelRows = (channels.data ?? []) as ChannelRow[];
  const themeRows = (topThemes.data ?? []) as ThemeRow[];
  const categoryRows = (categories.data ?? []) as CategoryRow[];
  const urgentRows = (urgent.data ?? []) as UrgentRow[];

  const regionCols: Column<RegionRow>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Avg candor', accessor: (r) => r.avg_candor },
    { header: 'Avg trust', accessor: (r) => r.avg_trust },
    { header: 'Action %', accessor: (r) => r.action_pct },
  ];

  const tierCols: Column<TierRow>[] = [
    { header: 'Tier', accessor: (r) => r.engineer_tier },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Avg candor', accessor: (r) => r.avg_candor },
    { header: 'Avg themes', accessor: (r) => r.avg_themes },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { header: 'Channel', accessor: (r) => r.channel },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Avg duration (min)', accessor: (r) => r.avg_duration },
    { header: 'Avg trust', accessor: (r) => r.avg_trust },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { header: 'Code', accessor: (r) => r.theme_code },
    { header: 'Title', accessor: (r) => r.theme_title },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Mentions', accessor: (r) => r.mentions },
    { header: 'Urgency', accessor: (r) => r.urgency },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Blast', accessor: (r) => r.blast },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Themes', accessor: (r) => r.themes },
    { header: 'Mentions', accessor: (r) => r.total_mentions },
    { header: 'Open', accessor: (r) => r.open_themes },
    { header: 'Avg impact', accessor: (r) => r.avg_impact },
  ];

  const urgentCols: Column<UrgentRow>[] = [
    { header: 'Code', accessor: (r) => r.theme_code },
    { header: 'Title', accessor: (r) => r.theme_title },
    { header: 'Urgency', accessor: (r) => r.urgency },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Impact', accessor: (r) => r.impact },
    { header: 'Surfaced', accessor: (r) => r.surfaced },
    { header: 'Blast', accessor: (r) => r.blast },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>
          Founder Quarterly Strategic Engineer-Founder Off-The-Record Trust Channel Audit
        </h1>
        <p style={{ color: '#666', fontSize: 13 }}>
          Round r3061 — off-record candor sessions between founder & engineers; redacted, founder-eyes-only.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12 }}>
        <Stat label="Total sessions" value={ov?.total_sessions ?? 0} />
        <Stat label="Completed" value={ov?.completed_sessions ?? 0} />
        <Stat label="Avg candor" value={ov?.avg_candor ?? 0} />
        <Stat label="Avg trust" value={ov?.avg_trust ?? 0} />
        <Stat label="Action required" value={ov?.action_required ?? 0} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Sessions by region</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No regional data"
          rowKey={(r, i) => String((r as { region?: string }).region ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Sessions by engineer tier</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier data"
          rowKey={(r, i) => String((r as { engineer_tier?: string }).engineer_tier ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Channel mix</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          emptyMessage="No channel data"
          rowKey={(r, i) => String((r as { channel?: string }).channel ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top themes (mentions &gt;= cutoff)</h2>
        <DataTable
          rows={themeRows}
          columns={themeCols}
          emptyMessage="No themes surfaced"
          rowKey={(r, i) => String((r as { theme_code?: string }).theme_code ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Themes by category</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category data"
          rowKey={(r, i) => String((r as { category?: string }).category ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Urgent themes (p0 & p1, unresolved)</h2>
        <DataTable
          rows={urgentRows}
          columns={urgentCols}
          emptyMessage="No urgent themes"
          rowKey={(r, i) => String((r as { theme_code?: string }).theme_code ?? i)}
        />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
