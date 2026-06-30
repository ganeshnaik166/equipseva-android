import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_visits: number; clean_visits: number; needs_followup: number; escalated: number; reopened: number; total_spillage_ml: number };
type Severity = { severity: string; visit_count: number; total_ml: number };
type Agent = { agent: string; visits: number; avg_duration: number; spillage_total: number };
type Ppe = { ppe_level: string; visits: number; spillage_incidents: number };
type Tier = { tier_name: string; engineer_count: number; avg_score: number };
type Region = { region_name: string; scorecards: number; avg_score: number; watchlist_count: number };
type Remediation = { status: string; count_scorecards: number; coaching_required_count: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [summary, severity, agent, ppe, tier, region, remediation] = await Promise.all([
    sb.rpc('r3086_monthly_summary'),
    sb.rpc('r3086_spillage_by_severity'),
    sb.rpc('r3086_agent_type_breakdown'),
    sb.rpc('r3086_ppe_compliance'),
    sb.rpc('r3086_tier_distribution'),
    sb.rpc('r3086_regional_discipline'),
    sb.rpc('r3086_remediation_status'),
  ]);

  const summaryRows: Summary[] = (summary.data ?? []) as Summary[];
  const severityRows: Severity[] = (severity.data ?? []) as Severity[];
  const agentRows: Agent[] = (agent.data ?? []) as Agent[];
  const ppeRows: Ppe[] = (ppe.data ?? []) as Ppe[];
  const tierRows: Tier[] = (tier.data ?? []) as Tier[];
  const regionRows: Region[] = (region.data ?? []) as Region[];
  const remediationRows: Remediation[] = (remediation.data ?? []) as Remediation[];

  const summaryCols: Column<Summary>[] = [
    { header: 'Total Visits', accessor: (r) => r.total_visits },
    { header: 'Clean', accessor: (r) => r.clean_visits },
    { header: 'Followup', accessor: (r) => r.needs_followup },
    { header: 'Escalated', accessor: (r) => r.escalated },
    { header: 'Reopened', accessor: (r) => r.reopened },
    { header: 'Spillage ml', accessor: (r) => r.total_spillage_ml },
  ];

  const severityCols: Column<Severity>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Visits', accessor: (r) => r.visit_count },
    { header: 'Total ml', accessor: (r) => r.total_ml },
  ];

  const agentCols: Column<Agent>[] = [
    { header: 'Agent', accessor: (r) => r.agent },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Avg Duration', accessor: (r) => r.avg_duration },
    { header: 'Spillage Total', accessor: (r) => r.spillage_total },
  ];

  const ppeCols: Column<Ppe>[] = [
    { header: 'PPE Level', accessor: (r) => r.ppe_level },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Spillage Incidents', accessor: (r) => r.spillage_incidents },
  ];

  const tierCols: Column<Tier>[] = [
    { header: 'Tier', accessor: (r) => r.tier_name },
    { header: 'Engineers', accessor: (r) => r.engineer_count },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
  ];

  const regionCols: Column<Region>[] = [
    { header: 'Region', accessor: (r) => r.region_name },
    { header: 'Scorecards', accessor: (r) => r.scorecards },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Watchlist', accessor: (r) => r.watchlist_count },
  ];

  const remediationCols: Column<Remediation>[] = [
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Scorecards', accessor: (r) => r.count_scorecards },
    { header: 'Coaching Required', accessor: (r) => r.coaching_required_count },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Monthly Customer Site Anaesthesia Vaporizer Refill Spillage & Cleaning Discipline</h1>
        <p style={{ color: '#666' }}>Round r3086 — spillage telemetry & cleaning discipline scorecards across engineer monthly visits.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Summary</h2>
        <DataTable rows={summaryRows} columns={summaryCols} emptyMessage="No summary" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Spillage by Severity</h2>
        <DataTable rows={severityRows} columns={severityCols} emptyMessage="No severity data" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Agent Type Breakdown</h2>
        <DataTable rows={agentRows} columns={agentCols} emptyMessage="No agent data" rowKey={(r, i) => String(r.agent ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>PPE Compliance</h2>
        <DataTable rows={ppeRows} columns={ppeCols} emptyMessage="No PPE data" rowKey={(r, i) => String(r.ppe_level ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier Distribution</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No tier data" rowKey={(r, i) => String(r.tier_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Regional Discipline</h2>
        <DataTable rows={regionRows} columns={regionCols} emptyMessage="No region data" rowKey={(r, i) => String(r.region_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Remediation Status</h2>
        <DataTable rows={remediationRows} columns={remediationCols} emptyMessage="No remediation data" rowKey={(r, i) => String(r.status ?? i)} />
      </section>
    </main>
  );
}
