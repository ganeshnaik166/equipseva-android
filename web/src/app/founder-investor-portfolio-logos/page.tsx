import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type WallRow = {
  investor_slug: string;
  investor_display_name: string;
  company_count: number;
  active_count: number;
  inactive_count: number;
  top_companies: string | null;
  last_updated: string | null;
};

type StatsRow = {
  total_investors: number;
  total_companies: number;
  active_companies: number;
  inactive_companies: number;
  sectors_covered: number;
  last_curated_at: string | null;
};

type EventRow = {
  id: string;
  investor_slug: string;
  event_type: string;
  payload: Record<string, unknown> | null;
  created_at: string;
};

export default async function FounderInvestorPortfolioLogosPage() {
  const sb = await getSupabaseServerClient();

  const wallRes = await sb.rpc('founder_investor_logo_wall', { p_limit: 200 });
  const statsRes = await sb.rpc('founder_investor_logo_stats');
  const eventsRes = await sb.rpc('founder_investor_logo_recent_events', { p_limit: 50 });

  const wall: WallRow[] = (wallRes.data as WallRow[] | null) ?? [];
  const stats: StatsRow | null = Array.isArray(statsRes.data)
    ? ((statsRes.data[0] as StatsRow) ?? null)
    : ((statsRes.data as StatsRow | null) ?? null);
  const events: EventRow[] = (eventsRes.data as EventRow[] | null) ?? [];

  const wallCols: Column<WallRow>[] = [
    { key: 'investor_display_name', header: 'Investor', render: (r) => r.investor_display_name ?? '—' },
    { key: 'investor_slug', header: 'Slug', render: (r) => r.investor_slug ?? '—' },
    { key: 'company_count', header: 'Companies', render: (r) => String(r.company_count ?? 0) },
    { key: 'active_count', header: 'Active', render: (r) => String(r.active_count ?? 0) },
    { key: 'inactive_count', header: 'Hidden', render: (r) => String(r.inactive_count ?? 0) },
    { key: 'top_companies', header: 'Top 5 marquee', render: (r) => r.top_companies ?? '—' },
    {
      key: 'last_updated',
      header: 'Updated',
      render: (r) => (r.last_updated ? new Date(r.last_updated).toLocaleString() : '—'),
    },
  ];

  const eventCols: Column<EventRow>[] = [
    {
      key: 'created_at',
      header: 'When',
      render: (r) => (r.created_at ? new Date(r.created_at).toLocaleString() : '—'),
    },
    { key: 'investor_slug', header: 'Investor', render: (r) => r.investor_slug ?? '—' },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type ?? '—' },
    {
      key: 'payload',
      header: 'Payload',
      render: (r) => (r.payload ? JSON.stringify(r.payload) : '—'),
    },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>
        Investor Portfolio Logo Wall
      </h1>
      <p style={{ color: '#555', marginBottom: 16, fontSize: 13 }}>
        Curated per-investor marquee companies (HCG, Apollo, Practo, etc.) for fundraise pitch decks.
      </p>

      <section style={{ marginBottom: 20 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>Coverage</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12 }}>
          <Stat label="Investors" value={stats?.total_investors ?? 0} />
          <Stat label="Companies" value={stats?.total_companies ?? 0} />
          <Stat label="Active" value={stats?.active_companies ?? 0} />
          <Stat label="Hidden" value={stats?.inactive_companies ?? 0} />
          <Stat label="Sectors" value={stats?.sectors_covered ?? 0} />
          <Stat
            label="Last curated"
            value={stats?.last_curated_at ? new Date(stats.last_curated_at).toLocaleDateString() : '—'}
          />
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>Per-investor wall</h2>
        <DataTable
          rows={wall}
          columns={wallCols}
          rowKey={(r: any, i: number) => String(r.investor_slug ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>Recent curation activity</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value ?? '—'}</div>
    </div>
  );
}
