import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_members: number;
  renewing: number;
  retiring: number;
  probation: number;
  rotating: number;
  avg_engagement: number;
  total_arr_rupees: number;
  total_contribution_value_rupees: number;
};

type Roster = {
  id: string;
  member_name: string;
  org_name: string;
  org_segment: string;
  tier: string;
  tenure_quarters: number;
  engagement_score: number;
  attendance_pct: number;
  nps_given: number | null;
  arr_rupees: number;
  decision: string;
};

type Contribution = {
  id: string;
  member_name: string;
  org_name: string;
  quarter_label: string;
  contribution_kind: string;
  contribution_summary: string;
  contribution_value_rupees: number;
  recorded_on: string;
};

type Ask = {
  id: string;
  member_name: string;
  org_name: string;
  ask_kind: string;
  ask_summary: string;
  ask_status: string;
  recorded_on: string;
};

type Decision = {
  id: string;
  member_name: string;
  org_name: string;
  tier: string;
  tenure_quarters: number;
  engagement_score: number;
  decision: string;
  decision_reason: string;
  decided_on: string;
};

type TierRow = {
  tier: string;
  members: number;
  avg_engagement: number;
  avg_attendance_pct: number;
  total_arr_rupees: number;
};

type TopContrib = {
  member_name: string;
  org_name: string;
  contributions: number;
  total_value_rupees: number;
  asks_open: number;
};

type RetireRow = {
  id: string;
  member_name: string;
  org_name: string;
  engagement_score: number;
  attendance_pct: number;
  decision: string;
  reason: string;
};

function rupees(n: number | null | undefined): string {
  if (!n) return '₹0';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    { data: summaryRows },
    { data: roster },
    { data: contributions },
    { data: asks },
    { data: decisions },
    { data: byTier },
    { data: topContrib },
    { data: retireRows },
  ] = await Promise.all([
    supabase.rpc('founder_cab_summary_r2717'),
    supabase.rpc('founder_cab_roster_r2717'),
    supabase.rpc('founder_cab_contributions_r2717'),
    supabase.rpc('founder_cab_asks_pipeline_r2717'),
    supabase.rpc('founder_cab_decisions_r2717'),
    supabase.rpc('founder_cab_engagement_by_tier_r2717'),
    supabase.rpc('founder_cab_top_contributors_r2717'),
    supabase.rpc('founder_cab_retire_candidates_r2717'),
  ]);

  const summary: Summary = (summaryRows && summaryRows[0]) || {
    total_members: 0,
    renewing: 0,
    retiring: 0,
    probation: 0,
    rotating: 0,
    avg_engagement: 0,
    total_arr_rupees: 0,
    total_contribution_value_rupees: 0,
  };

  const kpi = [
    { label: 'Total members', value: String(summary.total_members) },
    { label: 'Renewing', value: String(summary.renewing) },
    { label: 'Retiring', value: String(summary.retiring) },
    { label: 'Probation', value: String(summary.probation) },
    { label: 'Rotating', value: String(summary.rotating) },
    { label: 'Avg engagement (0-10)', value: String(summary.avg_engagement ?? 0) },
    { label: 'Member ARR', value: rupees(summary.total_arr_rupees) },
    { label: 'Contribution value', value: rupees(summary.total_contribution_value_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1240, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>
          Quarterly Customer Advisory Board
        </h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Member × tenure × contribution × ask × engagement → renew or retire.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpi.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Member roster</h2>
        <DataTable<Roster>
          rows={(roster as Roster[]) ?? []}
          columns={[
            { key: 'member_name', header: 'Member', render: (r) => r.member_name },
            { key: 'org_name', header: 'Org', render: (r) => r.org_name },
            { key: 'org_segment', header: 'Segment', render: (r) => r.org_segment },
            { key: 'tier', header: 'Tier', render: (r) => r.tier },
            { key: 'tenure_quarters', header: 'Tenure (Q)', render: (r) => String(r.tenure_quarters) },
            { key: 'engagement_score', header: 'Engagement', render: (r) => String(r.engagement_score) },
            { key: 'attendance_pct', header: 'Attendance %', render: (r) => String(r.attendance_pct) },
            { key: 'nps_given', header: 'NPS', render: (r) => (r.nps_given == null ? '-' : String(r.nps_given)) },
            { key: 'arr_rupees', header: 'ARR', render: (r) => rupees(r.arr_rupees) },
            { key: 'decision', header: 'Decision', render: (r) => r.decision },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Contributions feed</h2>
        <DataTable<Contribution>
          rows={(contributions as Contribution[]) ?? []}
          columns={[
            { key: 'member_name', header: 'Member', render: (r) => r.member_name },
            { key: 'org_name', header: 'Org', render: (r) => r.org_name },
            { key: 'quarter_label', header: 'Quarter', render: (r) => r.quarter_label },
            { key: 'contribution_kind', header: 'Kind', render: (r) => r.contribution_kind },
            { key: 'contribution_summary', header: 'Summary', render: (r) => r.contribution_summary },
            { key: 'contribution_value_rupees', header: 'Value', render: (r) => rupees(r.contribution_value_rupees) },
            { key: 'recorded_on', header: 'Recorded', render: (r) => r.recorded_on },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Asks pipeline</h2>
        <DataTable<Ask>
          rows={(asks as Ask[]) ?? []}
          columns={[
            { key: 'member_name', header: 'Member', render: (r) => r.member_name },
            { key: 'org_name', header: 'Org', render: (r) => r.org_name },
            { key: 'ask_kind', header: 'Kind', render: (r) => r.ask_kind },
            { key: 'ask_summary', header: 'Ask', render: (r) => r.ask_summary },
            { key: 'ask_status', header: 'Status', render: (r) => r.ask_status },
            { key: 'recorded_on', header: 'Recorded', render: (r) => r.recorded_on },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Renew or retire decisions</h2>
        <DataTable<Decision>
          rows={(decisions as Decision[]) ?? []}
          columns={[
            { key: 'member_name', header: 'Member', render: (r) => r.member_name },
            { key: 'org_name', header: 'Org', render: (r) => r.org_name },
            { key: 'tier', header: 'Tier', render: (r) => r.tier },
            { key: 'tenure_quarters', header: 'Tenure (Q)', render: (r) => String(r.tenure_quarters) },
            { key: 'engagement_score', header: 'Engagement', render: (r) => String(r.engagement_score) },
            { key: 'decision', header: 'Decision', render: (r) => r.decision },
            { key: 'decision_reason', header: 'Reason', render: (r) => r.decision_reason },
            { key: 'decided_on', header: 'Decided', render: (r) => r.decided_on },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Engagement by tier</h2>
        <DataTable<TierRow>
          rows={(byTier as TierRow[]) ?? []}
          columns={[
            { key: 'tier', header: 'Tier', render: (r) => r.tier },
            { key: 'members', header: 'Members', render: (r) => String(r.members) },
            { key: 'avg_engagement', header: 'Avg engagement', render: (r) => String(r.avg_engagement) },
            { key: 'avg_attendance_pct', header: 'Avg attendance %', render: (r) => String(r.avg_attendance_pct) },
            { key: 'total_arr_rupees', header: 'ARR', render: (r) => rupees(r.total_arr_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Top contributors</h2>
        <DataTable<TopContrib>
          rows={(topContrib as TopContrib[]) ?? []}
          columns={[
            { key: 'member_name', header: 'Member', render: (r) => r.member_name },
            { key: 'org_name', header: 'Org', render: (r) => r.org_name },
            { key: 'contributions', header: 'Contributions', render: (r) => String(r.contributions) },
            { key: 'total_value_rupees', header: 'Total value', render: (r) => rupees(r.total_value_rupees) },
            { key: 'asks_open', header: 'Open asks', render: (r) => String(r.asks_open) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.member_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Retire candidates (engagement &lt; 6.0)</h2>
        <DataTable<RetireRow>
          rows={(retireRows as RetireRow[]) ?? []}
          columns={[
            { key: 'member_name', header: 'Member', render: (r) => r.member_name },
            { key: 'org_name', header: 'Org', render: (r) => r.org_name },
            { key: 'engagement_score', header: 'Engagement', render: (r) => String(r.engagement_score) },
            { key: 'attendance_pct', header: 'Attendance %', render: (r) => String(r.attendance_pct) },
            { key: 'decision', header: 'Decision', render: (r) => r.decision },
            { key: 'reason', header: 'Reason', render: (r) => r.reason },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}