import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Entry = {
  id: string;
  source_investor_name: string | null;
  source_investor_email: string | null;
  co_investor_name: string | null;
  co_investor_firm: string | null;
  round_label: string | null;
  commitment_rupees: number | null;
  status: string | null;
  intro_at: string | null;
  committed_at: string | null;
  wired_at: string | null;
};

type BySource = {
  source_investor_name: string | null;
  source_investor_email: string | null;
  intros_count: number | null;
  committed_count: number | null;
  wired_count: number | null;
  total_committed_rupees: number | null;
  total_wired_rupees: number | null;
};

type Thanks = {
  id: string;
  source_investor_name: string | null;
  source_investor_email: string | null;
  channel: string | null;
  message_excerpt: string | null;
  sent_at: string | null;
};

type Summary = {
  total_entries: number | null;
  unique_sources: number | null;
  committed_entries: number | null;
  wired_entries: number | null;
  total_committed_rupees: number | null;
  total_wired_rupees: number | null;
  thanks_sent: number | null;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  const d = new Date(s);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' });
}

export default async function FounderInvestorCoInvestRegistryPage() {
  const sb = await getSupabaseServerClient();

  const entriesRes = await sb.rpc('list_co_invest_entries');
  const bySourceRes = await sb.rpc('list_co_invest_by_source');
  const thanksRes = await sb.rpc('list_co_invest_thanks');
  const summaryRes = await sb.rpc('co_invest_summary');

  const entries: Entry[] = (entriesRes.data as Entry[] | null) ?? [];
  const bySource: BySource[] = (bySourceRes.data as BySource[] | null) ?? [];
  const thanks: Thanks[] = (thanksRes.data as Thanks[] | null) ?? [];
  const summary: Summary = ((summaryRes.data as Summary[] | null) ?? [])[0] ?? {
    total_entries: 0,
    unique_sources: 0,
    committed_entries: 0,
    wired_entries: 0,
    total_committed_rupees: 0,
    total_wired_rupees: 0,
    thanks_sent: 0,
  };

  const entriesCols: Column<Entry>[] = [
    { key: 'source_investor_name', header: 'Source', render: (r: Entry) => r.source_investor_name ?? '—' },
    { key: 'co_investor_name', header: 'Co-Investor', render: (r: Entry) => r.co_investor_name ?? '—' },
    { key: 'co_investor_firm', header: 'Firm', render: (r: Entry) => r.co_investor_firm ?? '—' },
    { key: 'round_label', header: 'Round', render: (r: Entry) => r.round_label ?? '—' },
    { key: 'commitment_rupees', header: 'Commit', render: (r: Entry) => inr(r.commitment_rupees) },
    { key: 'status', header: 'Status', render: (r: Entry) => r.status ?? '—' },
    { key: 'intro_at', header: 'Intro', render: (r: Entry) => fmtDate(r.intro_at) },
    { key: 'wired_at', header: 'Wired', render: (r: Entry) => fmtDate(r.wired_at) },
  ];

  const bySourceCols: Column<BySource>[] = [
    { key: 'source_investor_name', header: 'Source Investor', render: (r: BySource) => r.source_investor_name ?? '—' },
    { key: 'source_investor_email', header: 'Email', render: (r: BySource) => r.source_investor_email ?? '—' },
    { key: 'intros_count', header: 'Intros', render: (r: BySource) => String(r.intros_count ?? 0) },
    { key: 'committed_count', header: 'Committed', render: (r: BySource) => String(r.committed_count ?? 0) },
    { key: 'wired_count', header: 'Wired', render: (r: BySource) => String(r.wired_count ?? 0) },
    { key: 'total_committed_rupees', header: 'Total Committed', render: (r: BySource) => inr(r.total_committed_rupees) },
    { key: 'total_wired_rupees', header: 'Total Wired', render: (r: BySource) => inr(r.total_wired_rupees) },
  ];

  const thanksCols: Column<Thanks>[] = [
    { key: 'source_investor_name', header: 'Source', render: (r: Thanks) => r.source_investor_name ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: Thanks) => r.channel ?? '—' },
    { key: 'message_excerpt', header: 'Message', render: (r: Thanks) => r.message_excerpt ?? '—' },
    { key: 'sent_at', header: 'Sent', render: (r: Thanks) => fmtDate(r.sent_at) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor Co-Invest Registry</h1>
        <p style={{ fontSize: 13, color: '#666' }}>
          Log when an investor brings co-investors to our round. Track attribution and founder thank-yous.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Total Entries</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.total_entries ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Unique Sources</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.unique_sources ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Committed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.committed_entries ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Wired</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.wired_entries ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Total Committed</div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{inr(summary.total_committed_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Total Wired</div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{inr(summary.total_wired_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Thanks Sent</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{summary.thanks_sent ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>By Source Investor</h2>
        <DataTable
          columns={bySourceCols}
          rows={bySource}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Co-Invest Entries</h2>
        <DataTable
          columns={entriesCols}
          rows={entries}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Founder Thank-You Log</h2>
        <DataTable
          columns={thanksCols}
          rows={thanks}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
