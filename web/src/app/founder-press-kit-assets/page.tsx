import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmt(n: any): string {
  if (n === null || n === undefined) return '—';
  if (typeof n === 'number') return n.toLocaleString('en-IN');
  return String(n);
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return String(s); }
}

function fmtBytes(b: any): string {
  if (b === null || b === undefined) return '—';
  const n = Number(b);
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB';
  return (n / 1024 / 1024).toFixed(2) + ' MB';
}

export default async function FounderPressKitAssetsPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let assets: any[] = [];
  let downloads: any[] = [];
  let recipients: any[] = [];
  let embargo: any[] = [];

  try {
    const r = await sb.rpc('founder_press_kit_overview');
    overview = (r.data && r.data[0]) || null;
  } catch {}
  try {
    const r = await sb.rpc('founder_press_kit_list_assets');
    assets = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_press_kit_recent_downloads');
    downloads = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_press_kit_top_recipients');
    recipients = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_press_kit_embargo_watch');
    embargo = r.data || [];
  } catch {}
  try { await sb.rpc('log_founder_press_kit_view', { p_section: 'main' }); } catch {}

  const kpis: Kpi[] = [
    { label: 'Total Assets', value: fmt(overview?.total_assets) },
    { label: 'Published', value: fmt(overview?.published_assets) },
    { label: 'Embargoed', value: fmt(overview?.embargoed_assets) },
    { label: 'Bios', value: fmt(overview?.bios_count) },
    { label: 'Logos', value: fmt(overview?.logos_count) },
    { label: 'Screenshots', value: fmt(overview?.screenshots_count) },
    { label: 'Fact Sheets', value: fmt(overview?.fact_sheets_count) },
    { label: 'Announcements', value: fmt(overview?.announcements_count) },
    { label: 'Total Downloads', value: fmt(overview?.total_downloads) },
    { label: 'Downloads (7d)', value: fmt(overview?.downloads_7d) },
    { label: 'Downloads (30d)', value: fmt(overview?.downloads_30d) },
    { label: 'Unique Recipients', value: fmt(overview?.unique_recipients) },
    { label: 'Unique Orgs', value: fmt(overview?.unique_orgs) },
    { label: 'Share-link DLs', value: fmt(overview?.share_link_downloads) },
    { label: 'Email DLs', value: fmt(overview?.email_downloads) },
    { label: 'Avg DL/Asset', value: fmt(overview?.avg_downloads_per_asset) },
  ];

  const assetCols: Column<any>[] = [
    { key: 'asset_title', header: 'Title', render: (r: any) => r.asset_title ?? '—' },
    { key: 'asset_category', header: 'Category', render: (r: any) => r.asset_category ?? '—' },
    { key: 'is_embargoed', header: 'Embargo', render: (r: any) => r.is_embargoed ? 'YES' : 'no' },
    { key: 'is_published', header: 'Pub', render: (r: any) => r.is_published ? 'YES' : 'no' },
    { key: 'byte_size', header: 'Size', render: (r: any) => fmtBytes(r.byte_size) },
    { key: 'download_count', header: 'Downloads', render: (r: any) => fmt(r.download_count) },
    { key: 'last_downloaded_at', header: 'Last DL', render: (r: any) => fmtDate(r.last_downloaded_at) },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const downloadCols: Column<any>[] = [
    { key: 'asset_title', header: 'Asset', render: (r: any) => r.asset_title ?? '—' },
    { key: 'asset_category', header: 'Category', render: (r: any) => r.asset_category ?? '—' },
    { key: 'recipient_name', header: 'Recipient', render: (r: any) => r.recipient_name ?? '—' },
    { key: 'recipient_email', header: 'Email', render: (r: any) => r.recipient_email ?? '—' },
    { key: 'recipient_org', header: 'Org', render: (r: any) => r.recipient_org ?? '—' },
    { key: 'download_source', header: 'Source', render: (r: any) => r.download_source ?? '—' },
    { key: 'downloaded_at', header: 'When', render: (r: any) => fmtDate(r.downloaded_at) },
  ];

  const recipientCols: Column<any>[] = [
    { key: 'recipient_name', header: 'Recipient', render: (r: any) => r.recipient_name ?? '—' },
    { key: 'recipient_email', header: 'Email', render: (r: any) => r.recipient_email ?? '—' },
    { key: 'recipient_org', header: 'Org', render: (r: any) => r.recipient_org ?? '—' },
    { key: 'download_count', header: 'Downloads', render: (r: any) => fmt(r.download_count) },
    { key: 'distinct_assets', header: 'Assets', render: (r: any) => fmt(r.distinct_assets) },
    { key: 'last_downloaded_at', header: 'Last', render: (r: any) => fmtDate(r.last_downloaded_at) },
  ];

  const embargoCols: Column<any>[] = [
    { key: 'asset_title', header: 'Asset', render: (r: any) => r.asset_title ?? '—' },
    { key: 'asset_category', header: 'Category', render: (r: any) => r.asset_category ?? '—' },
    { key: 'embargo_until', header: 'Lifts At', render: (r: any) => fmtDate(r.embargo_until) },
    { key: 'hours_until_lift', header: 'Hours Left', render: (r: any) => fmt(r.hours_until_lift) },
    { key: 'is_published', header: 'Pub', render: (r: any) => r.is_published ? 'YES' : 'no' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Press Kit Assets</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Central asset library for press: bios, logos, screenshots, fact sheets, embargoed announcements. Per-recipient download tracking.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: '#888', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Asset Library</h2>
        <DataTable columns={assetCols} rows={assets} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Downloads</h2>
        <DataTable columns={downloadCols} rows={downloads} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Recipients</h2>
        <DataTable columns={recipientCols} rows={recipients} rowKey={(r: any) => (r.recipient_email || r.recipient_name) + '|' + (r.recipient_org || '')} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Embargo Watch</h2>
        <DataTable columns={embargoCols} rows={embargo} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
