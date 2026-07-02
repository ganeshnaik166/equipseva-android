import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_matches: number;
  active_matches: number;
  paused_matches: number;
  closed_matches: number;
  flagged_matches: number;
  avg_match_score: number;
};

type TierRow = {
  mentor_tier: string;
  match_count: number;
  avg_score: number;
  avg_certs: number;
  avg_satisfaction: number;
};

type TopMatch = {
  mentor_name: string;
  mentee_name: string;
  mentor_city: string;
  mentor_tier: string;
  match_score: number;
  mentee_satisfaction_score: number;
  jobs_co_serviced: number;
  certifications_progressed: number;
};

type FlaggedRow = {
  mentor_name: string;
  mentee_name: string;
  mentor_tier: string;
  match_score: number;
  match_status: string;
  flagged_reason: string | null;
  sessions_completed: number;
  sessions_scheduled: number;
};

type GeoRow = {
  bucket: string;
  match_count: number;
  avg_score: number;
  avg_sessions: number;
};

type SeverityRow = {
  severity: string;
  open_count: number;
  in_review_count: number;
  accepted_count: number;
  total_uplift_pct: number;
  total_cost_rupees: number;
};

type ActionRow = {
  finding_title: string;
  finding_category: string;
  severity: string;
  owner_role: string;
  affected_matches: number;
  expected_uplift_pct: number;
  estimated_cost_rupees: number;
  recommended_action: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, tierRes, topRes, flaggedRes, geoRes, sevRes, actionRes] = await Promise.all([
    supabase.rpc('r3017_match_overview'),
    supabase.rpc('r3017_tier_breakdown'),
    supabase.rpc('r3017_top_matches'),
    supabase.rpc('r3017_flagged_matches'),
    supabase.rpc('r3017_geo_proximity_buckets'),
    supabase.rpc('r3017_findings_by_severity'),
    supabase.rpc('r3017_open_action_items'),
  ]);

  const overview: Overview | null = (overviewRes.data?.[0] as Overview) ?? null;
  const tierRows: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const topRows: TopMatch[] = (topRes.data as TopMatch[]) ?? [];
  const flaggedRows: FlaggedRow[] = (flaggedRes.data as FlaggedRow[]) ?? [];
  const geoRows: GeoRow[] = (geoRes.data as GeoRow[]) ?? [];
  const sevRows: SeverityRow[] = (sevRes.data as SeverityRow[]) ?? [];
  const actionRows: ActionRow[] = (actionRes.data as ActionRow[]) ?? [];

  const tierCols: Column<TierRow>[] = [
    { header: 'Tier', cell: (r) => r.mentor_tier },
    { header: 'Matches', cell: (r) => r.match_count },
    { header: 'Avg Score', cell: (r) => r.avg_score },
    { header: 'Avg Certs', cell: (r) => r.avg_certs },
    { header: 'Avg Mentee Sat', cell: (r) => r.avg_satisfaction },
  ];

  const topCols: Column<TopMatch>[] = [
    { header: 'Mentor', cell: (r) => r.mentor_name },
    { header: 'Mentee', cell: (r) => r.mentee_name },
    { header: 'City', cell: (r) => r.mentor_city },
    { header: 'Tier', cell: (r) => r.mentor_tier },
    { header: 'Score', cell: (r) => r.match_score },
    { header: 'Mentee Sat', cell: (r) => r.mentee_satisfaction_score },
    { header: 'Jobs Co-Served', cell: (r) => r.jobs_co_serviced },
    { header: 'Certs', cell: (r) => r.certifications_progressed },
  ];

  const flaggedCols: Column<FlaggedRow>[] = [
    { header: 'Mentor', cell: (r) => r.mentor_name },
    { header: 'Mentee', cell: (r) => r.mentee_name },
    { header: 'Tier', cell: (r) => r.mentor_tier },
    { header: 'Score', cell: (r) => r.match_score },
    { header: 'Status', cell: (r) => r.match_status },
    { header: 'Reason', cell: (r) => r.flagged_reason ?? '—' },
    { header: 'Sessions', cell: (r) => `${r.sessions_completed}/${r.sessions_scheduled}` },
  ];

  const geoCols: Column<GeoRow>[] = [
    { header: 'Distance Bucket', cell: (r) => r.bucket },
    { header: 'Matches', cell: (r) => r.match_count },
    { header: 'Avg Score', cell: (r) => r.avg_score },
    { header: 'Avg Sessions Done', cell: (r) => r.avg_sessions },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Open', cell: (r) => r.open_count },
    { header: 'In Review', cell: (r) => r.in_review_count },
    { header: 'Accepted', cell: (r) => r.accepted_count },
    { header: 'Total Uplift %', cell: (r) => r.total_uplift_pct },
    { header: 'Total Cost (Rs)', cell: (r) => r.total_cost_rupees.toLocaleString('en-IN') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { header: 'Finding', cell: (r) => r.finding_title },
    { header: 'Category', cell: (r) => r.finding_category },
    { header: 'Sev', cell: (r) => r.severity },
    { header: 'Owner', cell: (r) => r.owner_role },
    { header: 'Affected', cell: (r) => r.affected_matches },
    { header: 'Uplift %', cell: (r) => r.expected_uplift_pct },
    { header: 'Cost (Rs)', cell: (r) => r.estimated_cost_rupees.toLocaleString('en-IN') },
    { header: 'Action', cell: (r) => r.recommended_action },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Quarterly Strategic Engineer-Apprenticeship Mentor-Mentee Match Quality Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round r3017 — quarterly review of mentor-mentee pair health, audit findings & open action items.
      </p>

      {overview && (
        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Quarter Overview</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(140px,1fr))', gap: 12 }}>
            <Stat label="Total" value={overview.total_matches} />
            <Stat label="Active" value={overview.active_matches} />
            <Stat label="Paused" value={overview.paused_matches} />
            <Stat label="Closed" value={overview.closed_matches} />
            <Stat label="Flagged" value={overview.flagged_matches} />
            <Stat label="Avg Match Score" value={overview.avg_match_score} />
          </div>
        </section>
      )}

      <Section title="Tier Breakdown — score & satisfaction by mentor tier">
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier data."
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Top Active Matches — score >= 80, ranked">
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No top matches."
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Flagged / At-Risk Matches — satisfaction < 70 or status flagged/paused">
        <DataTable
          rows={flaggedRows}
          columns={flaggedCols}
          emptyMessage="No flagged matches."
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Geo Proximity Buckets — does distance hurt engagement?">
        <DataTable
          rows={geoRows}
          columns={geoCols}
          emptyMessage="No geo data."
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Audit Findings by Severity">
        <DataTable
          rows={sevRows}
          columns={sevCols}
          emptyMessage="No findings."
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Open Action Items — sorted by severity then uplift">
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No open actions."
          rowKey={(r, i) => String(i)}
        />
      </Section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 11, color: '#777', textTransform: 'uppercase' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
