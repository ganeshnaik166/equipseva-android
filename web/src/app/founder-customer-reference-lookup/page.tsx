import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerReferenceLookupPage() {
  const sb = await getSupabaseServerClient();

  const [refsRes, invRes, availRes, cooldownRes] = await Promise.all([
    sb.rpc('list_references_r1778'),
    sb.rpc('list_invocations_r1778'),
    sb.rpc('available_references_r1778'),
    sb.rpc('cooldown_releases_r1778'),
  ]);

  const refs: any[] = Array.isArray(refsRes.data) ? refsRes.data : [];
  const invocations: any[] = Array.isArray(invRes.data) ? invRes.data : [];
  const available: any[] = Array.isArray(availRes.data) ? availRes.data : [];
  const cooldowns: any[] = Array.isArray(cooldownRes.data) ? cooldownRes.data : [];

  const strongCount = refs.filter((r) => r.reference_strength === 'strong').length;
  const availableCount = available.length;
  const usedRecentlyCount = refs.filter((r) => r.status === 'used_recently').length;
  const blacklistedCount = refs.filter((r) => r.status === 'blacklisted').length;

  const refColumns: Column<any>[] = [
    { key: 'org_name', header: 'Hospital', render: (r: any) => <span>{r.org_name ?? r.hospital_email ?? '-'}</span> },
    { key: 'city', header: 'City', render: (r: any) => <span>{r.city ?? '-'}</span> },
    {
      key: 'reference_strength',
      header: 'Strength',
      render: (r: any) => {
        const s = String(r.reference_strength ?? '');
        const color =
          s === 'strong' ? '#15803d' : s === 'moderate' ? '#0369a1' : s === 'willing' ? '#a16207' : '#b91c1c';
        return <span style={{ color, fontWeight: 600 }}>{s}</span>;
      },
    },
    {
      key: 'can_speak_about',
      header: 'Can Speak About',
      render: (r: any) => {
        const arr: string[] = Array.isArray(r.can_speak_about) ? r.can_speak_about : [];
        return <span>{arr.length ? arr.join(', ') : '-'}</span>;
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => {
        const s = String(r.status ?? '');
        const color =
          s === 'available' ? '#15803d' : s === 'used_recently' ? '#a16207' : s === 'cooldown' ? '#0369a1' : '#b91c1c';
        return <span style={{ color, fontWeight: 600 }}>{s}</span>;
      },
    },
    {
      key: 'do_not_contact_until',
      header: 'No Contact Until',
      render: (r: any) => <span>{r.do_not_contact_until ?? '-'}</span>,
    },
    {
      key: 'last_invoked_at',
      header: 'Last Invoked',
      render: (r: any) =>
        r.last_invoked_at ? <span>{new Date(r.last_invoked_at).toLocaleDateString()}</span> : <span>never</span>,
    },
  ];

  const invColumns: Column<any>[] = [
    { key: 'org_name', header: 'Hospital', render: (r: any) => <span>{r.org_name ?? r.hospital_email ?? '-'}</span> },
    { key: 'investor_label', header: 'Investor', render: (r: any) => <span>{r.investor_label ?? '-'}</span> },
    {
      key: 'invoked_at',
      header: 'Invoked',
      render: (r: any) =>
        r.invoked_at ? <span>{new Date(r.invoked_at).toLocaleString()}</span> : <span>-</span>,
    },
    {
      key: 'prep_call_done',
      header: 'Prep',
      render: (r: any) => <span>{r.prep_call_done ? 'yes' : 'no'}</span>,
    },
    {
      key: 'reference_call_outcome',
      header: 'Outcome',
      render: (r: any) => {
        const s = String(r.reference_call_outcome ?? '');
        const color = s === 'positive' ? '#15803d' : s === 'neutral' ? '#a16207' : s === 'concerning' ? '#b91c1c' : '#64748b';
        return <span style={{ color, fontWeight: 600 }}>{s || 'pending'}</span>;
      },
    },
    {
      key: 'founder_post_thanks_sent',
      header: 'Thanks Sent',
      render: (r: any) => <span>{r.founder_post_thanks_sent ? 'yes' : 'no'}</span>,
    },
    { key: 'notes', header: 'Notes', render: (r: any) => <span>{r.notes ?? '-'}</span> },
  ];

  const availColumns: Column<any>[] = [
    { key: 'org_name', header: 'Hospital', render: (r: any) => <span>{r.org_name ?? r.hospital_email ?? '-'}</span> },
    { key: 'city', header: 'City', render: (r: any) => <span>{r.city ?? '-'}</span> },
    {
      key: 'reference_strength',
      header: 'Strength',
      render: (r: any) => {
        const s = String(r.reference_strength ?? '');
        const color = s === 'strong' ? '#15803d' : s === 'moderate' ? '#0369a1' : '#a16207';
        return <span style={{ color, fontWeight: 600 }}>{s}</span>;
      },
    },
    {
      key: 'can_speak_about',
      header: 'Topics',
      render: (r: any) => {
        const arr: string[] = Array.isArray(r.can_speak_about) ? r.can_speak_about : [];
        return <span>{arr.length ? arr.join(', ') : '-'}</span>;
      },
    },
    {
      key: 'last_invoked_at',
      header: 'Last Used',
      render: (r: any) =>
        r.last_invoked_at ? <span>{new Date(r.last_invoked_at).toLocaleDateString()}</span> : <span>never</span>,
    },
  ];

  const cooldownColumns: Column<any>[] = [
    { key: 'org_name', header: 'Hospital', render: (r: any) => <span>{r.org_name ?? r.hospital_email ?? '-'}</span> },
    {
      key: 'reference_strength',
      header: 'Strength',
      render: (r: any) => <span>{r.reference_strength ?? '-'}</span>,
    },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status ?? '-'}</span> },
    {
      key: 'do_not_contact_until',
      header: 'Release Date',
      render: (r: any) => <span>{r.do_not_contact_until ?? '-'}</span>,
    },
    {
      key: 'days_until_release',
      header: 'Days Until Release',
      render: (r: any) => {
        const d = Number(r.days_until_release ?? 0);
        const color = d === 0 ? '#15803d' : d <= 7 ? '#a16207' : '#64748b';
        return <span style={{ color, fontWeight: 600 }}>{d}</span>;
      },
    },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Customer Reference Lookup</h1>
      <p style={{ color: '#64748b', marginBottom: 24 }}>
        Curated customer reference list for investor diligence. Tracks strength, cooldowns, and invocation outcomes.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, background: '#f0fdf4', border: '1px solid #15803d', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#15803d', textTransform: 'uppercase', fontWeight: 600 }}>Strong References</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{strongCount}</div>
        </div>
        <div style={{ padding: 16, background: '#f0f9ff', border: '1px solid #0369a1', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#0369a1', textTransform: 'uppercase', fontWeight: 600 }}>Available Now</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{availableCount}</div>
        </div>
        <div style={{ padding: 16, background: '#fefce8', border: '1px solid #a16207', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#a16207', textTransform: 'uppercase', fontWeight: 600 }}>Used Recently</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{usedRecentlyCount}</div>
        </div>
        <div style={{ padding: 16, background: '#fef2f2', border: '1px solid #b91c1c', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#b91c1c', textTransform: 'uppercase', fontWeight: 600 }}>Blacklisted</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{blacklistedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Available References (Ready to Invoke)</h2>
        <p style={{ color: '#64748b', marginBottom: 12, fontSize: 14 }}>
          Strong, moderate, and willing references with no active cooldown. Sorted by strength then last-used.
        </p>
        <DataTable
          rows={available}
          columns={availColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All References</h2>
        <p style={{ color: '#64748b', marginBottom: 12, fontSize: 14 }}>
          Full curated list including blacklisted and unwilling entries.
        </p>
        <DataTable
          rows={refs}
          columns={refColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Invocation Log</h2>
        <p style={{ color: '#64748b', marginBottom: 12, fontSize: 14 }}>
          Track every reference call given to investors, with prep status and outcome.
        </p>
        <DataTable
          rows={invocations}
          columns={invColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Cooldown Releases</h2>
        <p style={{ color: '#64748b', marginBottom: 12, fontSize: 14 }}>
          References currently in cooldown. Zero days means ready to release.
        </p>
        <DataTable
          rows={cooldowns}
          columns={cooldownColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
