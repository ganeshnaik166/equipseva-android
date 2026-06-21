import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v)) return '0';
  return v.toLocaleString('en-IN');
}

function fmtRupees(n: any): string {
  const v = Number(n ?? 0);
  if (!isFinite(v) || v === 0) return '₹0';
  if (v >= 1e7) return '₹' + (v / 1e7).toFixed(2) + ' Cr';
  if (v >= 1e5) return '₹' + (v / 1e5).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }); } catch { return String(s); }
}

export default async function FounderPitchDeckVersionsPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let versions: any[] = [];
  let canonical: any[] = [];
  let shares: any[] = [];
  let changelog: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_pitch_kpis');
    kpis = (r.data && r.data[0]) ? r.data[0] : {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('rpc_founder_pitch_versions_list');
    versions = Array.isArray(r.data) ? r.data : [];
  } catch { versions = []; }

  try {
    const r = await sb.rpc('rpc_founder_pitch_canonical_by_audience');
    canonical = Array.isArray(r.data) ? r.data : [];
  } catch { canonical = []; }

  try {
    const r = await sb.rpc('rpc_founder_pitch_recent_shares');
    shares = Array.isArray(r.data) ? r.data : [];
  } catch { shares = []; }

  try {
    const r = await sb.rpc('rpc_founder_pitch_version_change_log', { p_limit: 20 });
    changelog = Array.isArray(r.data) ? r.data : [];
  } catch { changelog = []; }

  const cards: Kpi[] = [
    { label: 'Total versions', value: fmtNum(kpis.total_versions) },
    { label: 'Canonical picks', value: fmtNum(kpis.canonical_versions) },
    { label: 'Draft', value: fmtNum(kpis.draft_versions) },
    { label: 'Approved', value: fmtNum(kpis.approved_versions) },
    { label: 'Archived', value: fmtNum(kpis.archived_versions) },
    { label: 'Investor cuts', value: fmtNum(kpis.investor_versions) },
    { label: 'Customer cuts', value: fmtNum(kpis.customer_versions) },
    { label: 'Press cuts', value: fmtNum(kpis.press_versions) },
    { label: 'Partner cuts', value: fmtNum(kpis.partner_versions) },
    { label: 'Internal cuts', value: fmtNum(kpis.internal_versions) },
    { label: 'Total shares', value: fmtNum(kpis.total_shares) },
    { label: 'Shares opened', value: fmtNum(kpis.shares_opened) },
    { label: 'Interested', value: fmtNum(kpis.shares_interested) },
    { label: 'Passed', value: fmtNum(kpis.shares_passed) },
    { label: 'Term sheets', value: fmtNum(kpis.shares_termsheet) },
    { label: 'Wired', value: fmtNum(kpis.shares_wired) },
  ];

  const versionCols: Column<any>[] = [
    { key: 'version_label', header: 'Version', render: (r: any) => String(r.version_label ?? '—') },
    { key: 'semver', header: 'Semver', render: (r: any) => String(r.semver ?? '—') },
    { key: 'audience', header: 'Audience', render: (r: any) => String(r.audience ?? '—') },
    { key: 'stage', header: 'Stage', render: (r: any) => String(r.stage ?? '—') },
    { key: 'slide_count', header: 'Slides', render: (r: any) => fmtNum(r.slide_count) },
    { key: 'is_canonical', header: 'Canonical', render: (r: any) => r.is_canonical ? 'YES' : '—' },
    { key: 'raise_target_rupees', header: 'Raise target', render: (r: any) => fmtRupees(r.raise_target_rupees) },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const canonicalCols: Column<any>[] = [
    { key: 'audience', header: 'Audience', render: (r: any) => String(r.audience ?? '—') },
    { key: 'version_label', header: 'Canonical version', render: (r: any) => String(r.version_label ?? '—') },
    { key: 'semver', header: 'Semver', render: (r: any) => String(r.semver ?? '—') },
    { key: 'slide_count', header: 'Slides', render: (r: any) => fmtNum(r.slide_count) },
    { key: 'approved_at', header: 'Approved', render: (r: any) => fmtDate(r.approved_at) },
  ];

  const shareCols: Column<any>[] = [
    { key: 'shared_at', header: 'When', render: (r: any) => fmtDate(r.shared_at) },
    { key: 'recipient_name', header: 'Recipient', render: (r: any) => String(r.recipient_name ?? '—') },
    { key: 'recipient_org', header: 'Org', render: (r: any) => String(r.recipient_org ?? '—') },
    { key: 'version_label', header: 'Version', render: (r: any) => String(r.version_label ?? '—') },
    { key: 'audience', header: 'Audience', render: (r: any) => String(r.audience ?? '—') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '—') },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? fmtDate(r.opened_at) : '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '—') },
  ];

  const changelogCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => fmtDate(r.created_at) },
    { key: 'version_label', header: 'Version', render: (r: any) => String(r.version_label ?? '—') },
    { key: 'audience', header: 'Audience', render: (r: any) => String(r.audience ?? '—') },
    { key: 'change_log', header: 'Change log', render: (r: any) => String(r.change_log ?? '—') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Pitch Deck Versions</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>Version control for fundraising decks; pick canonical per audience.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        {cards.map((c, i) => (
          <div key={i} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{c.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{c.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Canonical pick by audience</h2>
        <DataTable columns={canonicalCols} rows={canonical} rowKey={(r: any) => r.audience} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All versions</h2>
        <DataTable columns={versionCols} rows={versions} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent shares</h2>
        <DataTable columns={shareCols} rows={shares} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Change log</h2>
        <DataTable columns={changelogCols} rows={changelog} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
