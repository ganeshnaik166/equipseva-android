import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_notes: number;
  public_notes: number;
  total_views: number;
  avg_impact: number;
  total_arr_lift_rupees: number;
  outcomes_verified: number;
};

type ByEngineer = {
  engineer_name: string;
  engineer_tier: string;
  notes_sent: number;
  avg_impact: number;
  total_views: number;
  arr_lift_rupees: number;
};

type ByKind = { note_kind: string; notes: number; avg_impact: number; arr_lift_rupees: number };
type ByTheme = { theme: string; notes: number; avg_impact: number; arr_lift_rupees: number };
type PublicShare = {
  engineer_name: string;
  customer_name: string;
  customer_org: string;
  share_token: string;
  view_count: number;
  business_impact_score: number;
};
type Outcome = {
  engineer_name: string;
  customer_org: string;
  outcome_kind: string;
  outcome_value_rupees: number;
  verified: boolean;
  reply_excerpt: string | null;
};
type Impact = {
  engineer_name: string;
  customer_name: string;
  customer_org: string;
  theme: string;
  business_impact_score: number;
  estimated_arr_lift_rupees: number;
};
type Tier = { engineer_tier: string; notes: number; avg_impact: number; arr_lift_rupees: number };

function fmtINR(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, engRes, kindRes, themeRes, shareRes, outcomeRes, impactRes, tierRes] = await Promise.all([
    supabase.rpc('rpc_r2690_summary'),
    supabase.rpc('rpc_r2690_by_engineer'),
    supabase.rpc('rpc_r2690_by_kind'),
    supabase.rpc('rpc_r2690_by_theme'),
    supabase.rpc('rpc_r2690_public_share'),
    supabase.rpc('rpc_r2690_outcomes'),
    supabase.rpc('rpc_r2690_impact_ranked'),
    supabase.rpc('rpc_r2690_tier_breakdown'),
  ]);

  const summary: Summary = (summaryRes.data?.[0] as Summary) ?? {
    total_notes: 0,
    public_notes: 0,
    total_views: 0,
    avg_impact: 0,
    total_arr_lift_rupees: 0,
    outcomes_verified: 0,
  };
  const engineers: ByEngineer[] = (engRes.data as ByEngineer[]) ?? [];
  const kinds: ByKind[] = (kindRes.data as ByKind[]) ?? [];
  const themes: ByTheme[] = (themeRes.data as ByTheme[]) ?? [];
  const shares: PublicShare[] = (shareRes.data as PublicShare[]) ?? [];
  const outcomes: Outcome[] = (outcomeRes.data as Outcome[]) ?? [];
  const impacts: Impact[] = (impactRes.data as Impact[]) ?? [];
  const tiers: Tier[] = (tierRes.data as Tier[]) ?? [];

  return (
    <div style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>
        Engineer Monthly Customer Thank-You Notes
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Engineer × customer × note kind × theme × public share × business impact —
        tracks gratitude loops that lift renewals & referrals.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Notes" value={String(summary.total_notes)} />
        <KpiCard label="Public Shares" value={String(summary.public_notes)} />
        <KpiCard label="Public Views" value={summary.total_views.toLocaleString('en-IN')} />
        <KpiCard label="Avg Impact Score" value={String(summary.avg_impact ?? 0)} />
        <KpiCard label="ARR Lift" value={fmtINR(summary.total_arr_lift_rupees)} />
        <KpiCard label="Verified Outcomes" value={String(summary.outcomes_verified)} />
      </div>

      <Section title="By Engineer">
        <DataTable
          rows={engineers}
          rowKey={(r, i) => String((r as ByEngineer).engineer_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ByEngineer) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: ByEngineer) => r.engineer_tier },
            { key: 'notes_sent', header: 'Notes', render: (r: ByEngineer) => r.notes_sent },
            { key: 'avg_impact', header: 'Avg Impact', render: (r: ByEngineer) => r.avg_impact },
            { key: 'total_views', header: 'Views', render: (r: ByEngineer) => r.total_views },
            { key: 'arr_lift_rupees', header: 'ARR Lift', render: (r: ByEngineer) => fmtINR(r.arr_lift_rupees) },
          ]}
        />
      </Section>

      <Section title="By Note Kind">
        <DataTable
          rows={kinds}
          rowKey={(r, i) => String((r as ByKind).note_kind ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'note_kind', header: 'Kind', render: (r: ByKind) => r.note_kind },
            { key: 'notes', header: 'Notes', render: (r: ByKind) => r.notes },
            { key: 'avg_impact', header: 'Avg Impact', render: (r: ByKind) => r.avg_impact },
            { key: 'arr_lift_rupees', header: 'ARR Lift', render: (r: ByKind) => fmtINR(r.arr_lift_rupees) },
          ]}
        />
      </Section>

      <Section title="By Theme">
        <DataTable
          rows={themes}
          rowKey={(r, i) => String((r as ByTheme).theme ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'theme', header: 'Theme', render: (r: ByTheme) => r.theme },
            { key: 'notes', header: 'Notes', render: (r: ByTheme) => r.notes },
            { key: 'avg_impact', header: 'Avg Impact', render: (r: ByTheme) => r.avg_impact },
            { key: 'arr_lift_rupees', header: 'ARR Lift', render: (r: ByTheme) => fmtINR(r.arr_lift_rupees) },
          ]}
        />
      </Section>

      <Section title="Tier Breakdown">
        <DataTable
          rows={tiers}
          rowKey={(r, i) => String((r as Tier).engineer_tier ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_tier', header: 'Tier', render: (r: Tier) => r.engineer_tier },
            { key: 'notes', header: 'Notes', render: (r: Tier) => r.notes },
            { key: 'avg_impact', header: 'Avg Impact', render: (r: Tier) => r.avg_impact },
            { key: 'arr_lift_rupees', header: 'ARR Lift', render: (r: Tier) => fmtINR(r.arr_lift_rupees) },
          ]}
        />
      </Section>

      <Section title="Public Share Leaderboard">
        <DataTable
          rows={shares}
          rowKey={(r, i) => String((r as PublicShare).share_token ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: PublicShare) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: PublicShare) => r.customer_name },
            { key: 'customer_org', header: 'Org', render: (r: PublicShare) => r.customer_org },
            { key: 'view_count', header: 'Views', render: (r: PublicShare) => r.view_count },
            { key: 'business_impact_score', header: 'Impact', render: (r: PublicShare) => r.business_impact_score },
            { key: 'share_token', header: 'Token', render: (r: PublicShare) => r.share_token },
          ]}
        />
      </Section>

      <Section title="Outcomes (renewals, referrals, upsells)">
        <DataTable
          rows={outcomes}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Outcome) => r.engineer_name },
            { key: 'customer_org', header: 'Org', render: (r: Outcome) => r.customer_org },
            { key: 'outcome_kind', header: 'Outcome', render: (r: Outcome) => r.outcome_kind },
            { key: 'outcome_value_rupees', header: 'Value', render: (r: Outcome) => fmtINR(r.outcome_value_rupees) },
            { key: 'verified', header: 'Verified', render: (r: Outcome) => (r.verified ? 'yes' : 'no') },
            { key: 'reply_excerpt', header: 'Reply', render: (r: Outcome) => r.reply_excerpt ?? '-' },
          ]}
        />
      </Section>

      <Section title="Top 25 Notes by Business Impact">
        <DataTable
          rows={impacts}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Impact) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: Impact) => r.customer_name },
            { key: 'customer_org', header: 'Org', render: (r: Impact) => r.customer_org },
            { key: 'theme', header: 'Theme', render: (r: Impact) => r.theme },
            { key: 'business_impact_score', header: 'Impact', render: (r: Impact) => r.business_impact_score },
            { key: 'estimated_arr_lift_rupees', header: 'ARR Lift', render: (r: Impact) => fmtINR(r.estimated_arr_lift_rupees) },
          ]}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
