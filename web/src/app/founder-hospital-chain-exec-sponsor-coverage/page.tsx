import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    coverageRes,
    strengthRes,
    staleRes,
    atRiskRes,
    qbrRes,
    touchesRes,
    summaryRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2355_coverage_list'),
    supabase.rpc('founder_r2355_strength_distribution'),
    supabase.rpc('founder_r2355_stale_contacts'),
    supabase.rpc('founder_r2355_at_risk_chains'),
    supabase.rpc('founder_r2355_upcoming_qbrs'),
    supabase.rpc('founder_r2355_recent_touches'),
    supabase.rpc('founder_r2355_portfolio_summary'),
  ]);

  const coverage = (coverageRes.data ?? []) as any[];
  const strength = (strengthRes.data ?? []) as any[];
  const stale = (staleRes.data ?? []) as any[];
  const atRisk = (atRiskRes.data ?? []) as any[];
  const qbrs = (qbrRes.data ?? []) as any[];
  const touches = (touchesRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? [])[0] ?? null;

  const fmtAcv = (r: number) => {
    if (!r) return '₹0';
    if (r >= 10000000) return '₹' + (r / 10000000).toFixed(2) + ' Cr';
    if (r >= 100000) return '₹' + (r / 100000).toFixed(2) + ' L';
    return '₹' + r.toLocaleString('en-IN');
  };

  const fmtDate = (d: string | null) =>
    d ? new Date(d).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—';

  const coverageCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r: any) => r.chain_tier },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => r.hospital_count },
    { key: 'acv', header: 'ACV', render: (r: any) => fmtAcv(r.annual_contract_value_rupees) },
    { key: 'sponsor', header: 'Our Sponsor', render: (r: any) => r.sponsor_name + ' (' + (r.sponsor_title ?? '') + ')' },
    { key: 'counterpart', header: 'Their Side', render: (r: any) => r.counterpart_name + (r.counterpart_title ? ' (' + r.counterpart_title + ')' : '') },
    { key: 'strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    {
      key: 'last_contact',
      header: 'Last Contact',
      render: (r: any) => (r.days_since_contact == null ? 'never' : r.days_since_contact + 'd ago'),
    },
    { key: 'next_qbr', header: 'Next QBR', render: (r: any) => fmtDate(r.next_qbr_scheduled_at) },
  ];

  const strengthCols: Column<any>[] = [
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'hospitals', header: 'Hospitals', render: (r: any) => r.hospital_count_sum },
    { key: 'acv', header: 'ACV', render: (r: any) => fmtAcv(Number(r.acv_rupees_sum)) },
  ];

  const staleCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r: any) => r.chain_tier },
    { key: 'sponsor', header: 'Sponsor', render: (r: any) => r.sponsor_name },
    { key: 'counterpart', header: 'Counterpart', render: (r: any) => r.counterpart_name },
    {
      key: 'days',
      header: 'Days Since',
      render: (r: any) => (r.days_since_contact >= 9999 ? 'never' : r.days_since_contact + 'd'),
    },
    { key: 'strength', header: 'Strength', render: (r: any) => r.relationship_strength },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'tier', header: 'Tier', render: (r: any) => r.chain_tier },
    { key: 'acv', header: 'ACV at Risk', render: (r: any) => fmtAcv(r.annual_contract_value_rupees) },
    { key: 'sponsor', header: 'Sponsor', render: (r: any) => r.sponsor_name },
    { key: 'counterpart', header: 'Counterpart', render: (r: any) => r.counterpart_name },
    { key: 'last_contact', header: 'Last Contact', render: (r: any) => fmtDate(r.last_contact_at) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const qbrCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'tier', header: 'Tier', render: (r: any) => r.chain_tier },
    { key: 'sponsor', header: 'Sponsor', render: (r: any) => r.sponsor_name },
    { key: 'counterpart', header: 'Counterpart', render: (r: any) => r.counterpart_name },
    { key: 'when', header: 'Scheduled', render: (r: any) => fmtDate(r.next_qbr_scheduled_at) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => r.days_until + 'd' },
  ];

  const touchCols: Column<any>[] = [
    { key: 'when', header: 'When', render: (r: any) => fmtDate(r.touched_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'touch_type', header: 'Type', render: (r: any) => r.touch_type },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary },
    { key: 'by', header: 'Logged By', render: (r: any) => r.logged_by_email ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        Hospital Chain Exec-Sponsor Coverage
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Who on our side owns each chain, last contact, relationship strength, upcoming QBRs & touch log.
      </p>

      {summary && (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
            gap: 12,
            marginBottom: 24,
          }}
        >
          <Stat label="Active Chains" value={String(summary.active_chains ?? 0)} />
          <Stat label="Total Hospitals" value={String(summary.total_hospitals ?? 0)} />
          <Stat label="Portfolio ACV" value={fmtAcv(Number(summary.total_acv_rupees ?? 0))} />
          <Stat label="Champions" value={String(summary.champion_count ?? 0)} />
          <Stat label="At-Risk / Cold" value={String(summary.at_risk_count ?? 0)} />
          <Stat label="Stale Contact (30d+)" value={String(summary.stale_contact_count ?? 0)} />
          <Stat label="Unassigned" value={String(summary.unassigned_count ?? 0)} />
        </div>
      )}

      <Section title="Coverage Roster">
        <DataTable
          rows={coverage}
          columns={coverageCols}
          emptyMessage="No chain sponsor assignments recorded."
          rowKey={(r: any) => r.id}
        />
      </Section>

      <Section title="Relationship Strength Distribution">
        <DataTable
          rows={strength}
          columns={strengthCols}
          emptyMessage="No active assignments."
          rowKey={(r: any) => r.relationship_strength}
        />
      </Section>

      <Section title="Stale Contacts (no touch in 30d+)">
        <DataTable
          rows={stale}
          columns={staleCols}
          emptyMessage="All chains contacted within 30 days."
          rowKey={(r: any) => r.id}
        />
      </Section>

      <Section title="At-Risk / Cold Chains">
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          emptyMessage="No chains marked at-risk."
          rowKey={(r: any) => r.id}
        />
      </Section>

      <Section title="Upcoming QBRs (next 60 days)">
        <DataTable
          rows={qbrs}
          columns={qbrCols}
          emptyMessage="No QBRs scheduled in next 60 days."
          rowKey={(r: any) => r.id}
        />
      </Section>

      <Section title="Recent Touch Log (last 50)">
        <DataTable
          rows={touches}
          columns={touchCols}
          emptyMessage="No touches logged."
          rowKey={(r: any) => r.id}
        />
      </Section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        padding: 14,
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        background: '#fafafa',
      }}
    >
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>
        {label}
      </div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginTop: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
