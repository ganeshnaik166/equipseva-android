import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_chains: number;
  total_hospitals: number;
  current_acv_lakhs: number;
  target_acv_lakhs: number;
  uplift_lakhs: number;
  critical_count: number;
  signed_count: number;
  weighted_pipeline_lakhs: number;
};

type PipelineRow = {
  id: string;
  chain_name: string;
  chain_tier: string;
  city: string;
  hospital_count: number;
  current_acv_lakhs: number;
  renewal_target_lakhs: number;
  uplift_lakhs: number;
  contract_end_quarter: string;
  contract_end_date: string;
  renewal_stage: string;
  risk_level: string;
  churn_probability_pct: number;
  uptime_last_qtr_pct: number;
  satisfaction_score: number;
  competitor_threat: string;
  decision_maker: string;
  next_action: string;
  next_action_due: string;
  founder_decision: string;
};

type RiskRow = {
  risk_level: string;
  chain_count: number;
  target_acv_lakhs: number;
  avg_churn_pct: number;
  weighted_at_risk_lakhs: number;
};

type StageRow = {
  renewal_stage: string;
  chain_count: number;
  target_acv_lakhs: number;
  pct_of_total: number;
};

type QuarterRow = {
  contract_end_quarter: string;
  chain_count: number;
  target_acv_lakhs: number;
  at_risk_acv_lakhs: number;
};

type CompetitorRow = {
  competitor_threat: string;
  chain_count: number;
  target_acv_lakhs: number;
  avg_satisfaction: number;
};

type ActionRow = {
  id: string;
  chain_name: string;
  action_type: string;
  action_summary: string;
  action_owner: string;
  action_outcome: string;
  delta_acv_lakhs: number;
  action_date: string;
};

type AttentionRow = {
  chain_name: string;
  city: string;
  renewal_target_lakhs: number;
  risk_level: string;
  churn_probability_pct: number;
  competitor_threat: string;
  founder_decision: string;
  next_action: string;
  next_action_due: string;
  days_to_action: number;
};

function fmtLakhs(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return 'Rs ' + Number(n).toFixed(2) + 'L';
}

function fmtNum(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return String(n);
}

function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, pipelineRes, riskRes, stageRes, quarterRes, competitorRes, actionRes, attentionRes] = await Promise.all([
    supabase.rpc('founder_r2679_kpis'),
    supabase.rpc('founder_r2679_pipeline'),
    supabase.rpc('founder_r2679_risk_rollup'),
    supabase.rpc('founder_r2679_stage_funnel'),
    supabase.rpc('founder_r2679_quarter_breakdown'),
    supabase.rpc('founder_r2679_competitor_threats'),
    supabase.rpc('founder_r2679_action_ledger'),
    supabase.rpc('founder_r2679_attention_list'),
  ]);

  const kpi: Kpi | null = (kpiRes.data && kpiRes.data[0]) || null;
  const pipeline: PipelineRow[] = pipelineRes.data || [];
  const risk: RiskRow[] = riskRes.data || [];
  const stage: StageRow[] = stageRes.data || [];
  const quarter: QuarterRow[] = quarterRes.data || [];
  const competitor: CompetitorRow[] = competitorRes.data || [];
  const actions: ActionRow[] = actionRes.data || [];
  const attention: AttentionRow[] = attentionRes.data || [];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>
          Hospital Chain Quarterly Contract Renewal Pipeline
        </h1>
        <p style={{ color: '#666', marginTop: '6px' }}>
          Chain by chain ACV, renewal target, risk, action, founder decision. Round r2679.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total Chains" value={fmtNum(kpi?.total_chains)} />
        <KpiCard label="Hospitals Covered" value={fmtNum(kpi?.total_hospitals)} />
        <KpiCard label="Current ACV" value={fmtLakhs(kpi?.current_acv_lakhs)} />
        <KpiCard label="Target ACV" value={fmtLakhs(kpi?.target_acv_lakhs)} />
        <KpiCard label="Uplift Target" value={fmtLakhs(kpi?.uplift_lakhs)} accent="#16a34a" />
        <KpiCard label="Weighted Pipeline" value={fmtLakhs(kpi?.weighted_pipeline_lakhs)} accent="#2563eb" />
        <KpiCard label="Critical Risk" value={fmtNum(kpi?.critical_count)} accent="#dc2626" />
        <KpiCard label="Signed" value={fmtNum(kpi?.signed_count)} accent="#16a34a" />
      </section>

      <Section title="Critical Attention List" subtitle="Chains flagged high or critical risk, or marked escalate.">
        <DataTable
          rows={attention}
          rowKey={(r, i) => String((r as AttentionRow).chain_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: AttentionRow) => r.chain_name },
            { key: 'city', header: 'City', render: (r: AttentionRow) => r.city },
            { key: 'renewal_target_lakhs', header: 'Target', render: (r: AttentionRow) => fmtLakhs(r.renewal_target_lakhs) },
            { key: 'risk_level', header: 'Risk', render: (r: AttentionRow) => <RiskPill level={r.risk_level} /> },
            { key: 'churn_probability_pct', header: 'Churn %', render: (r: AttentionRow) => r.churn_probability_pct + '%' },
            { key: 'competitor_threat', header: 'Competitor', render: (r: AttentionRow) => r.competitor_threat },
            { key: 'founder_decision', header: 'Decision', render: (r: AttentionRow) => <DecisionPill decision={r.founder_decision} /> },
            { key: 'next_action', header: 'Next Action', render: (r: AttentionRow) => r.next_action },
            { key: 'next_action_due', header: 'Due', render: (r: AttentionRow) => r.next_action_due },
            { key: 'days_to_action', header: 'Days', render: (r: AttentionRow) => r.days_to_action + 'd' },
          ]}
        />
      </Section>

      <Section title="Full Renewal Pipeline" subtitle="Sorted by risk level then contract end date.">
        <DataTable
          rows={pipeline}
          rowKey={(r, i) => String((r as PipelineRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: PipelineRow) => r.chain_name },
            { key: 'chain_tier', header: 'Tier', render: (r: PipelineRow) => r.chain_tier },
            { key: 'city', header: 'City', render: (r: PipelineRow) => r.city },
            { key: 'hospital_count', header: 'Hosp', render: (r: PipelineRow) => String(r.hospital_count) },
            { key: 'current_acv_lakhs', header: 'Current', render: (r: PipelineRow) => fmtLakhs(r.current_acv_lakhs) },
            { key: 'renewal_target_lakhs', header: 'Target', render: (r: PipelineRow) => fmtLakhs(r.renewal_target_lakhs) },
            { key: 'uplift_lakhs', header: 'Uplift', render: (r: PipelineRow) => fmtLakhs(r.uplift_lakhs) },
            { key: 'contract_end_quarter', header: 'Qtr', render: (r: PipelineRow) => r.contract_end_quarter },
            { key: 'contract_end_date', header: 'End Date', render: (r: PipelineRow) => r.contract_end_date },
            { key: 'renewal_stage', header: 'Stage', render: (r: PipelineRow) => r.renewal_stage },
            { key: 'risk_level', header: 'Risk', render: (r: PipelineRow) => <RiskPill level={r.risk_level} /> },
            { key: 'churn_probability_pct', header: 'Churn', render: (r: PipelineRow) => r.churn_probability_pct + '%' },
            { key: 'uptime_last_qtr_pct', header: 'Uptime', render: (r: PipelineRow) => fmtPct(r.uptime_last_qtr_pct) },
            { key: 'satisfaction_score', header: 'CSAT', render: (r: PipelineRow) => String(r.satisfaction_score) },
            { key: 'competitor_threat', header: 'Compet', render: (r: PipelineRow) => r.competitor_threat },
            { key: 'decision_maker', header: 'DM', render: (r: PipelineRow) => r.decision_maker },
            { key: 'next_action', header: 'Next', render: (r: PipelineRow) => r.next_action },
            { key: 'next_action_due', header: 'Due', render: (r: PipelineRow) => r.next_action_due },
            { key: 'founder_decision', header: 'Decision', render: (r: PipelineRow) => <DecisionPill decision={r.founder_decision} /> },
          ]}
        />
      </Section>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(420px, 1fr))', gap: '24px' }}>
        <Section title="Risk Roll-up" subtitle="Weighted at-risk by churn probability.">
          <DataTable
            rows={risk}
            rowKey={(r, i) => String((r as RiskRow).risk_level ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'risk_level', header: 'Risk', render: (r: RiskRow) => <RiskPill level={r.risk_level} /> },
              { key: 'chain_count', header: 'Chains', render: (r: RiskRow) => String(r.chain_count) },
              { key: 'target_acv_lakhs', header: 'Target ACV', render: (r: RiskRow) => fmtLakhs(r.target_acv_lakhs) },
              { key: 'avg_churn_pct', header: 'Avg Churn', render: (r: RiskRow) => r.avg_churn_pct + '%' },
              { key: 'weighted_at_risk_lakhs', header: 'At Risk', render: (r: RiskRow) => fmtLakhs(r.weighted_at_risk_lakhs) },
            ]}
          />
        </Section>

        <Section title="Stage Funnel" subtitle="Pipeline distribution by renewal stage.">
          <DataTable
            rows={stage}
            rowKey={(r, i) => String((r as StageRow).renewal_stage ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'renewal_stage', header: 'Stage', render: (r: StageRow) => r.renewal_stage },
              { key: 'chain_count', header: 'Chains', render: (r: StageRow) => String(r.chain_count) },
              { key: 'target_acv_lakhs', header: 'Target ACV', render: (r: StageRow) => fmtLakhs(r.target_acv_lakhs) },
              { key: 'pct_of_total', header: 'Share', render: (r: StageRow) => r.pct_of_total + '%' },
            ]}
          />
        </Section>

        <Section title="Quarter Breakdown" subtitle="Renewals concentrated by quarter.">
          <DataTable
            rows={quarter}
            rowKey={(r, i) => String((r as QuarterRow).contract_end_quarter ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'contract_end_quarter', header: 'Quarter', render: (r: QuarterRow) => r.contract_end_quarter },
              { key: 'chain_count', header: 'Chains', render: (r: QuarterRow) => String(r.chain_count) },
              { key: 'target_acv_lakhs', header: 'Target ACV', render: (r: QuarterRow) => fmtLakhs(r.target_acv_lakhs) },
              { key: 'at_risk_acv_lakhs', header: 'At Risk', render: (r: QuarterRow) => fmtLakhs(r.at_risk_acv_lakhs) },
            ]}
          />
        </Section>

        <Section title="Competitor Threat Scan" subtitle="Which competitors stalk which book of business.">
          <DataTable
            rows={competitor}
            rowKey={(r, i) => String((r as CompetitorRow).competitor_threat ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'competitor_threat', header: 'Threat', render: (r: CompetitorRow) => r.competitor_threat },
              { key: 'chain_count', header: 'Chains', render: (r: CompetitorRow) => String(r.chain_count) },
              { key: 'target_acv_lakhs', header: 'Target ACV', render: (r: CompetitorRow) => fmtLakhs(r.target_acv_lakhs) },
              { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: CompetitorRow) => String(r.avg_satisfaction) },
            ]}
          />
        </Section>
      </div>

      <Section title="Action Ledger" subtitle="Recent touchpoints, outcomes, delta ACV impact.">
        <DataTable
          rows={actions}
          rowKey={(r, i) => String((r as ActionRow).id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'action_date', header: 'Date', render: (r: ActionRow) => r.action_date },
            { key: 'chain_name', header: 'Chain', render: (r: ActionRow) => r.chain_name },
            { key: 'action_type', header: 'Type', render: (r: ActionRow) => r.action_type },
            { key: 'action_summary', header: 'Summary', render: (r: ActionRow) => r.action_summary },
            { key: 'action_owner', header: 'Owner', render: (r: ActionRow) => r.action_owner },
            { key: 'action_outcome', header: 'Outcome', render: (r: ActionRow) => <OutcomePill outcome={r.action_outcome} /> },
            { key: 'delta_acv_lakhs', header: 'Delta ACV', render: (r: ActionRow) => fmtLakhs(r.delta_acv_lakhs) },
          ]}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div style={{
      border: '1px solid #e5e7eb',
      borderRadius: '10px',
      padding: '14px 16px',
      background: '#fff',
    }}>
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700, color: accent || '#111827', marginTop: '4px' }}>{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '24px' }}>
      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '0 0 4px 0' }}>{title}</h2>
      {subtitle ? <p style={{ color: '#6b7280', margin: '0 0 12px 0', fontSize: '13px' }}>{subtitle}</p> : null}
      <div style={{ overflowX: 'auto' }}>{children}</div>
    </section>
  );
}

function RiskPill({ level }: { level: string }) {
  const map: Record<string, string> = {
    critical: '#dc2626',
    high: '#ea580c',
    medium: '#ca8a04',
    low: '#16a34a',
  };
  const bg = map[level] || '#6b7280';
  return (
    <span style={{
      background: bg,
      color: '#fff',
      padding: '2px 8px',
      borderRadius: '999px',
      fontSize: '12px',
      fontWeight: 600,
    }}>{level}</span>
  );
}

function DecisionPill({ decision }: { decision: string }) {
  const map: Record<string, string> = {
    pursue_aggressively: '#2563eb',
    standard: '#6b7280',
    discount_allowed: '#ca8a04',
    walk_away: '#dc2626',
    escalate: '#dc2626',
  };
  const bg = map[decision] || '#6b7280';
  return (
    <span style={{
      background: bg,
      color: '#fff',
      padding: '2px 8px',
      borderRadius: '999px',
      fontSize: '12px',
      fontWeight: 600,
    }}>{decision.replace(/_/g, ' ')}</span>
  );
}

function OutcomePill({ outcome }: { outcome: string }) {
  const map: Record<string, string> = {
    positive: '#16a34a',
    negative: '#dc2626',
    neutral: '#6b7280',
    pending: '#ca8a04',
  };
  const bg = map[outcome] || '#6b7280';
  return (
    <span style={{
      background: bg,
      color: '#fff',
      padding: '2px 8px',
      borderRadius: '999px',
      fontSize: '12px',
      fontWeight: 600,
    }}>{outcome}</span>
  );
}
