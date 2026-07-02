import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function Card({ label, value }: Kpi) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4, color: '#111827' }}>{value}</div>
    </div>
  );
}

function fmt(n: any): string {
  if (n === null || n === undefined) return '—';
  if (typeof n === 'number') return n.toLocaleString('en-IN');
  return String(n);
}

function fmtDate(d: any): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); } catch { return String(d); }
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  let summary: any = {};
  let versions: any[] = [];
  let recent: any[] = [];
  let unsigned: any[] = [];
  let newHire: any[] = [];
  let byRole: any[] = [];
  let timeline: any[] = [];

  try {
    const r = await supabase.rpc('founder_culture_deck_summary');
    summary = (r.data && r.data[0]) || {};
  } catch { summary = {}; }

  try {
    const r = await supabase.rpc('founder_culture_deck_versions_list');
    versions = r.data || [];
  } catch { versions = []; }

  try {
    const r = await supabase.rpc('founder_culture_deck_recent_signatures');
    recent = r.data || [];
  } catch { recent = []; }

  try {
    const r = await supabase.rpc('founder_culture_deck_unsigned_team');
    unsigned = r.data || [];
  } catch { unsigned = []; }

  try {
    const r = await supabase.rpc('founder_culture_deck_new_hire_ladder');
    newHire = r.data || [];
  } catch { newHire = []; }

  try {
    const r = await supabase.rpc('founder_culture_deck_signatures_by_role');
    byRole = r.data || [];
  } catch { byRole = []; }

  try {
    const r = await supabase.rpc('founder_culture_deck_version_timeline');
    timeline = r.data || [];
  } catch { timeline = []; }

  const kpis: Kpi[] = [
    { label: 'Total Versions', value: fmt(summary.total_versions ?? 0) },
    { label: 'Active Versions', value: fmt(summary.active_versions ?? 0) },
    { label: 'Retired Versions', value: fmt(summary.retired_versions ?? 0) },
    { label: 'Active Label', value: summary.active_version_label ?? '—' },
    { label: 'Total Signatures', value: fmt(summary.total_signatures ?? 0) },
    { label: 'Signatures 30d', value: fmt(summary.signatures_last_30d ?? 0) },
    { label: 'New-Hire Signatures', value: fmt(summary.new_hire_signatures ?? 0) },
    { label: 'Unsigned Team', value: fmt(summary.unsigned_team_count ?? 0) },
    { label: 'Team Members', value: fmt(summary.total_team_members ?? 0) },
    { label: '% Team Signed', value: `${fmt(summary.pct_team_signed ?? 0)}%` },
    { label: 'Avg Word Count', value: fmt(summary.avg_word_count ?? 0) },
    { label: 'Onboarding Ladder', value: fmt(summary.onboarding_ladder_count ?? 0) },
    { label: 'Days Since Publish', value: fmt(summary.days_since_publish ?? 0) },
    { label: 'Hours Since Sign', value: fmt(summary.hours_since_sign ?? 0) },
    { label: 'Latest Publish', value: fmtDate(summary.latest_publish_at) },
    { label: 'Latest Signature', value: fmtDate(summary.latest_sign_at) },
  ];

  const versionCols: Column<any>[] = [
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label ?? '—' },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'is_active', header: 'Active', render: (r: any) => r.is_active ? 'Yes' : 'No' },
    { key: 'requires_signature', header: 'Sig Req', render: (r: any) => r.requires_signature ? 'Yes' : 'No' },
    { key: 'word_count', header: 'Words', render: (r: any) => fmt(r.word_count) },
    { key: 'signature_count', header: 'Sigs', render: (r: any) => fmt(r.signature_count) },
    { key: 'days_since_publish', header: 'Days Old', render: (r: any) => fmt(r.days_since_publish) },
    { key: 'published_at', header: 'Published', render: (r: any) => fmtDate(r.published_at) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label ?? '—' },
    { key: 'signer_email', header: 'Signer', render: (r: any) => r.signer_email ?? '—' },
    { key: 'signer_role', header: 'Role', render: (r: any) => r.signer_role ?? '—' },
    { key: 'is_new_hire', header: 'New Hire', render: (r: any) => r.is_new_hire ? 'Yes' : 'No' },
    { key: 'onboarding_step', header: 'Step', render: (r: any) => fmt(r.onboarding_step) },
    { key: 'hours_since', header: 'Hours Ago', render: (r: any) => fmt(r.hours_since) },
    { key: 'signed_at', header: 'Signed', render: (r: any) => fmtDate(r.signed_at) },
  ];

  const unsignedCols: Column<any>[] = [
    { key: 'email', header: 'Email', render: (r: any) => r.email ?? '—' },
    { key: 'full_name', header: 'Name', render: (r: any) => r.full_name ?? '—' },
    { key: 'active_version', header: 'Awaiting', render: (r: any) => r.active_version ?? '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => fmt(r.days_overdue) },
  ];

  const newHireCols: Column<any>[] = [
    { key: 'signer_email', header: 'New Hire', render: (r: any) => r.signer_email ?? '—' },
    { key: 'signer_role', header: 'Role', render: (r: any) => r.signer_role ?? '—' },
    { key: 'onboarding_step', header: 'Ladder Step', render: (r: any) => fmt(r.onboarding_step) },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label ?? '—' },
    { key: 'days_since_signing', header: 'Days Since', render: (r: any) => fmt(r.days_since_signing) },
    { key: 'signed_at', header: 'Signed', render: (r: any) => fmtDate(r.signed_at) },
  ];

  const byRoleCols: Column<any>[] = [
    { key: 'signer_role', header: 'Role', render: (r: any) => r.signer_role ?? '—' },
    { key: 'total_signatures', header: 'Sigs', render: (r: any) => fmt(r.total_signatures) },
    { key: 'new_hire_signatures', header: 'New Hires', render: (r: any) => fmt(r.new_hire_signatures) },
    { key: 'avg_onboarding_step', header: 'Avg Step', render: (r: any) => fmt(r.avg_onboarding_step) },
    { key: 'latest_signed_at', header: 'Latest', render: (r: any) => fmtDate(r.latest_signed_at) },
  ];

  return (
    <div style={{ padding: 20, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <div style={{ marginBottom: 16 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, color: '#111827' }}>Culture Deck Versioning</h1>
        <div style={{ fontSize: 13, color: '#6b7280', marginTop: 4 }}>
          Track culture deck versions, team acknowledgement signatures, who hasn't signed, and new-hire onboarding ladder. r1496.
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 10, marginBottom: 20 }}>
        {kpis.map((k, i) => <Card key={i} label={k.label} value={k.value} />)}
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8, color: '#111827' }}>Versions Registry</h2>
        <DataTable columns={versionCols} rows={versions} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8, color: '#111827' }}>Recent Signatures</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8, color: '#111827' }}>Unsigned Team (Active Version)</h2>
        <DataTable columns={unsignedCols} rows={unsigned} rowKey={(r: any) => r.user_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8, color: '#111827' }}>New-Hire Onboarding Ladder</h2>
        <DataTable columns={newHireCols} rows={newHire} rowKey={(r: any) => `${r.signer_email}-${r.signed_at}`} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8, color: '#111827' }}>Signatures by Role</h2>
        <DataTable columns={byRoleCols} rows={byRole} rowKey={(r: any) => r.signer_role} />
      </section>

      <section style={{ fontSize: 12, color: '#6b7280', marginTop: 16 }}>
        {timeline.length} weeks of publish-timeline data on file.
      </section>
    </div>
  );
}
