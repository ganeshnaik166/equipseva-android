import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_assets: number;
  total_chains: number;
  avg_verdict: number;
  critical_assets: number;
  failing_assets: number;
  open_actions: number;
  total_remediation_inr: number;
  pass_rate_pct: number;
};

type ChainRollupRow = {
  chain_name: string;
  asset_count: number;
  avg_verdict: number;
  critical_assets: number;
  fail_or_remediation: number;
  total_remediation_inr: number;
};

type VulnRow = {
  vulnerability: string;
  asset_count: number;
  avg_verdict: number;
  total_pending_actions: number;
};

type OutcomeRow = {
  outcome: string;
  asset_count: number;
  share_pct: number;
};

type AtRiskRow = {
  id: string;
  chain_name: string;
  hospital_branch: string;
  asset_code: string;
  asset_category: string;
  monsoon_vulnerability: string;
  verdict_score: number;
  outcome_status: string;
  prep_actions_pending: number;
  estimated_remediation_inr: number;
  next_audit_due_on: string;
};

type ActionRow = {
  id: string;
  chain_name: string;
  asset_code: string;
  action_label: string;
  action_type: string;
  priority: string;
  owner_role: string;
  due_on: string;
  status: string;
  cost_inr: number;
};

type HeatmapRow = {
  asset_category: string;
  total_assets: number;
  avg_verdict: number;
  pending_actions: number;
  remediation_inr: number;
};

type UpcomingRow = {
  id: string;
  chain_name: string;
  hospital_branch: string;
  asset_code: string;
  next_audit_due_on: string;
  days_until_due: number;
  monsoon_vulnerability: string;
};

function inr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(v);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, chainRes, vulnRes, outcomeRes, atRiskRes, actionRes, heatmapRes, upcomingRes] = await Promise.all([
    supabase.rpc('r2875_kpi_snapshot'),
    supabase.rpc('r2875_chain_rollup'),
    supabase.rpc('r2875_vulnerability_mix'),
    supabase.rpc('r2875_outcome_funnel'),
    supabase.rpc('r2875_at_risk_assets'),
    supabase.rpc('r2875_action_board'),
    supabase.rpc('r2875_category_heatmap'),
    supabase.rpc('r2875_upcoming_audits'),
  ]);

  const kpi: KpiRow = (kpiRes.data?.[0] ?? {
    total_assets: 0, total_chains: 0, avg_verdict: 0, critical_assets: 0,
    failing_assets: 0, open_actions: 0, total_remediation_inr: 0, pass_rate_pct: 0,
  }) as KpiRow;
  const chainRows: ChainRollupRow[] = (chainRes.data ?? []) as ChainRollupRow[];
  const vulnRows: VulnRow[] = (vulnRes.data ?? []) as VulnRow[];
  const outcomeRows: OutcomeRow[] = (outcomeRes.data ?? []) as OutcomeRow[];
  const atRiskRows: AtRiskRow[] = (atRiskRes.data ?? []) as AtRiskRow[];
  const actionRows: ActionRow[] = (actionRes.data ?? []) as ActionRow[];
  const heatmapRows: HeatmapRow[] = (heatmapRes.data ?? []) as HeatmapRow[];
  const upcomingRows: UpcomingRow[] = (upcomingRes.data ?? []) as UpcomingRow[];

  const kpis = [
    { label: 'Total Assets Audited', value: String(kpi.total_assets ?? 0) },
    { label: 'Chains Covered', value: String(kpi.total_chains ?? 0) },
    { label: 'Avg Verdict Score', value: `${Number(kpi.avg_verdict ?? 0).toFixed(2)} / 100` },
    { label: 'Critical-Vuln Assets', value: String(kpi.critical_assets ?? 0) },
    { label: 'Failing / Remediation', value: String(kpi.failing_assets ?? 0) },
    { label: 'Open Prep Actions', value: String(kpi.open_actions ?? 0) },
    { label: 'Est. Remediation Spend', value: inr(kpi.total_remediation_inr) },
    { label: 'Pass Rate', value: `${Number(kpi.pass_rate_pct ?? 0).toFixed(1)}%` },
  ];

  return (
    <div style={{ padding: '24px', fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
          Hospital Chain Quarterly Equipment Fleet — Pre-Monsoon Audit
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Round r2875 · chain × asset × monsoon-vulnerable × checklist × prep × outcome × verdict.
          Surfaces critical-vulnerability assets, remediation spend, and audit cadence across hospital chain partners before monsoon onset.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e3e3e3', borderRadius: 8, padding: 14, background: '#fafafa' }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#666', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 6 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Chain Rollup</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>
          Per-chain audit posture — verdict average, critical-vulnerability count, and fail-or-remediation tally.
        </p>
        <DataTable
          rows={chainRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRollupRow) => r.chain_name },
            { key: 'asset_count', header: 'Assets', render: (r: ChainRollupRow) => String(r.asset_count) },
            { key: 'avg_verdict', header: 'Avg Verdict', render: (r: ChainRollupRow) => Number(r.avg_verdict ?? 0).toFixed(2) },
            { key: 'critical_assets', header: 'Critical Vuln', render: (r: ChainRollupRow) => String(r.critical_assets) },
            { key: 'fail_or_remediation', header: 'Fail / Remediation', render: (r: ChainRollupRow) => String(r.fail_or_remediation) },
            { key: 'total_remediation_inr', header: 'Remediation Spend', render: (r: ChainRollupRow) => inr(r.total_remediation_inr) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRollupRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(420px, 1fr))', gap: 16, marginBottom: 28 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Vulnerability Mix</h2>
          <DataTable
            rows={vulnRows}
            columns={[
              { key: 'vulnerability', header: 'Vulnerability', render: (r: VulnRow) => r.vulnerability },
              { key: 'asset_count', header: 'Assets', render: (r: VulnRow) => String(r.asset_count) },
              { key: 'avg_verdict', header: 'Avg Verdict', render: (r: VulnRow) => Number(r.avg_verdict ?? 0).toFixed(2) },
              { key: 'total_pending_actions', header: 'Pending Actions', render: (r: VulnRow) => String(r.total_pending_actions) },
            ]}
            emptyMessage="No data"
            rowKey={(r: VulnRow, i: number) => String(r.vulnerability ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Outcome Funnel</h2>
          <DataTable
            rows={outcomeRows}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'asset_count', header: 'Assets', render: (r: OutcomeRow) => String(r.asset_count) },
              { key: 'share_pct', header: 'Share %', render: (r: OutcomeRow) => `${Number(r.share_pct ?? 0).toFixed(2)}%` },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
          />
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>At-Risk Assets</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>
          Assets with verdict &lt;= 70, or with monsoon vulnerability marked critical, or with outcome failing &amp; needing remediation.
        </p>
        <DataTable
          rows={atRiskRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: AtRiskRow) => r.chain_name },
            { key: 'hospital_branch', header: 'Branch', render: (r: AtRiskRow) => r.hospital_branch },
            { key: 'asset_code', header: 'Asset', render: (r: AtRiskRow) => r.asset_code },
            { key: 'asset_category', header: 'Category', render: (r: AtRiskRow) => r.asset_category },
            { key: 'monsoon_vulnerability', header: 'Vuln', render: (r: AtRiskRow) => r.monsoon_vulnerability },
            { key: 'verdict_score', header: 'Verdict', render: (r: AtRiskRow) => Number(r.verdict_score ?? 0).toFixed(2) },
            { key: 'outcome_status', header: 'Outcome', render: (r: AtRiskRow) => r.outcome_status },
            { key: 'prep_actions_pending', header: 'Pending', render: (r: AtRiskRow) => String(r.prep_actions_pending) },
            { key: 'estimated_remediation_inr', header: 'Remediation', render: (r: AtRiskRow) => inr(r.estimated_remediation_inr) },
            { key: 'next_audit_due_on', header: 'Next Audit', render: (r: AtRiskRow) => r.next_audit_due_on },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRiskRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Prep & Remediation Action Board</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 10 }}>
          Ordered by priority (p0 → p3) then due date. Owner role tells founder whom to ping.
        </p>
        <DataTable
          rows={actionRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ActionRow) => r.chain_name },
            { key: 'asset_code', header: 'Asset', render: (r: ActionRow) => r.asset_code },
            { key: 'action_label', header: 'Action', render: (r: ActionRow) => r.action_label },
            { key: 'action_type', header: 'Type', render: (r: ActionRow) => r.action_type },
            { key: 'priority', header: 'Priority', render: (r: ActionRow) => r.priority },
            { key: 'owner_role', header: 'Owner', render: (r: ActionRow) => r.owner_role },
            { key: 'due_on', header: 'Due', render: (r: ActionRow) => r.due_on },
            { key: 'status', header: 'Status', render: (r: ActionRow) => r.status },
            { key: 'cost_inr', header: 'Cost', render: (r: ActionRow) => inr(r.cost_inr) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(420px, 1fr))', gap: 16, marginBottom: 28 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Category Heatmap</h2>
          <DataTable
            rows={heatmapRows}
            columns={[
              { key: 'asset_category', header: 'Category', render: (r: HeatmapRow) => r.asset_category },
              { key: 'total_assets', header: 'Assets', render: (r: HeatmapRow) => String(r.total_assets) },
              { key: 'avg_verdict', header: 'Avg Verdict', render: (r: HeatmapRow) => Number(r.avg_verdict ?? 0).toFixed(2) },
              { key: 'pending_actions', header: 'Pending', render: (r: HeatmapRow) => String(r.pending_actions) },
              { key: 'remediation_inr', header: 'Remediation', render: (r: HeatmapRow) => inr(r.remediation_inr) },
            ]}
            emptyMessage="No data"
            rowKey={(r: HeatmapRow, i: number) => String(r.asset_category ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Upcoming Audits</h2>
          <DataTable
            rows={upcomingRows}
            columns={[
              { key: 'chain_name', header: 'Chain', render: (r: UpcomingRow) => r.chain_name },
              { key: 'hospital_branch', header: 'Branch', render: (r: UpcomingRow) => r.hospital_branch },
              { key: 'asset_code', header: 'Asset', render: (r: UpcomingRow) => r.asset_code },
              { key: 'next_audit_due_on', header: 'Due', render: (r: UpcomingRow) => r.next_audit_due_on },
              { key: 'days_until_due', header: 'Days Left', render: (r: UpcomingRow) => String(r.days_until_due) },
              { key: 'monsoon_vulnerability', header: 'Vuln', render: (r: UpcomingRow) => r.monsoon_vulnerability },
            ]}
            emptyMessage="No data"
            rowKey={(r: UpcomingRow, i: number) => String(r.id ?? i)}
          />
        </div>
      </section>

      <footer style={{ color: '#888', fontSize: 12, marginTop: 24, borderTop: '1px solid #eee', paddingTop: 14 }}>
        Founder-only console. All RPCs gated by is_founder(). Quarterly cadence; next sweep window opens Jul 1.
      </footer>
    </div>
  );
}