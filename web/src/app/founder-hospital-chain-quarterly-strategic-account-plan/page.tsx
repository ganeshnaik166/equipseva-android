import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Plan = {
  id: string;
  quarter: string;
  chain_name: string;
  tier: string;
  current_arr_rupees: number;
  target_arr_rupees: number;
  white_space_rupees: number;
  arr_growth_pct: number | null;
  penetration_pct: number | null;
  hospitals_active: number;
  hospitals_total: number;
  wedge_product: string;
  wedge_rationale: string;
  primary_stakeholder: string;
  stakeholder_role: string;
  relationship_health: string;
  plan_status: string;
  owner: string;
  qbr_date: string;
};

type Summary = {
  total_chains: number;
  strategic_chains: number;
  growth_chains: number;
  at_risk_chains: number;
  total_current_arr: number;
  total_target_arr: number;
  total_white_space: number;
  avg_penetration_pct: number | null;
  champion_chains: number;
};

type WhiteSpace = { chain_name: string; white_space_rupees: number; wedge_product: string; primary_stakeholder: string; relationship_health: string; plan_status: string };
type Action = { id: string; chain_name: string; milestone_name: string; action_text: string; action_owner: string; due_date: string; action_type: string; value_unlock_rupees: number; blocker_text: string | null; status: string; completed_at: string | null };
type Blocked = { chain_name: string; milestone_name: string; action_text: string; blocker_text: string | null; value_unlock_rupees: number; due_date: string; relationship_health: string; primary_stakeholder: string };
type Health = { relationship_health: string; chain_count: number; total_arr: number; total_white_space: number };
type Qbr = { chain_name: string; qbr_date: string; days_until: number; owner: string; plan_status: string; current_arr_rupees: number; white_space_rupees: number };
type Progress = { action_type: string; total_actions: number; done_count: number; blocked_count: number; total_value_unlock: number; done_pct: number | null };

function fmtRupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}
function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return `${n}%`;
}
function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  return new Date(s).toLocaleDateString();
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [plans, summary, whitespace, actions, blocked, health, qbrs, progress] = await Promise.all([
    supabase.rpc('founder_list_account_plans_r2683'),
    supabase.rpc('founder_account_plan_summary_r2683'),
    supabase.rpc('founder_white_space_ranking_r2683'),
    supabase.rpc('founder_list_actions_r2683'),
    supabase.rpc('founder_blocked_actions_r2683'),
    supabase.rpc('founder_stakeholder_health_r2683'),
    supabase.rpc('founder_upcoming_qbrs_r2683'),
    supabase.rpc('founder_action_progress_r2683'),
  ]);

  const planRows: Plan[] = (plans.data as Plan[]) ?? [];
  const sum: Summary | null = ((summary.data as Summary[]) ?? [])[0] ?? null;
  const whitespaceRows: WhiteSpace[] = (whitespace.data as WhiteSpace[]) ?? [];
  const actionRows: Action[] = (actions.data as Action[]) ?? [];
  const blockedRows: Blocked[] = (blocked.data as Blocked[]) ?? [];
  const healthRows: Health[] = (health.data as Health[]) ?? [];
  const qbrRows: Qbr[] = (qbrs.data as Qbr[]) ?? [];
  const progressRows: Progress[] = (progress.data as Progress[]) ?? [];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Quarterly Strategic Account Plan</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Chain × white space × wedge × stakeholder × action × milestone — one operating plan per strategic chain.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Chains" value={sum?.total_chains ?? 0} />
        <KpiCard label="Strategic" value={sum?.strategic_chains ?? 0} />
        <KpiCard label="Growth" value={sum?.growth_chains ?? 0} />
        <KpiCard label="At-Risk" value={sum?.at_risk_chains ?? 0} />
        <KpiCard label="Champions" value={sum?.champion_chains ?? 0} />
        <KpiCard label="Current ARR" value={fmtRupees(sum?.total_current_arr)} />
        <KpiCard label="Target ARR" value={fmtRupees(sum?.total_target_arr)} />
        <KpiCard label="White Space" value={fmtRupees(sum?.total_white_space)} />
        <KpiCard label="Avg Penetration" value={fmtPct(sum?.avg_penetration_pct)} />
      </div>

      <Section title="Strategic Account Plans">
        <DataTable
          rows={planRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Plan) => r.chain_name },
            { key: 'tier', header: 'Tier', render: (r: Plan) => r.tier },
            { key: 'current_arr_rupees', header: 'Current ARR', render: (r: Plan) => fmtRupees(r.current_arr_rupees) },
            { key: 'target_arr_rupees', header: 'Target ARR', render: (r: Plan) => fmtRupees(r.target_arr_rupees) },
            { key: 'arr_growth_pct', header: 'Growth', render: (r: Plan) => fmtPct(r.arr_growth_pct) },
            { key: 'penetration_pct', header: 'Penetration', render: (r: Plan) => `${r.hospitals_active}/${r.hospitals_total} (${r.penetration_pct ?? '-'}%)` },
            { key: 'wedge_product', header: 'Wedge', render: (r: Plan) => r.wedge_product },
            { key: 'primary_stakeholder', header: 'Stakeholder', render: (r: Plan) => `${r.primary_stakeholder} (${r.stakeholder_role})` },
            { key: 'relationship_health', header: 'Health', render: (r: Plan) => r.relationship_health },
            { key: 'plan_status', header: 'Status', render: (r: Plan) => r.plan_status },
            { key: 'owner', header: 'Owner', render: (r: Plan) => r.owner },
            { key: 'qbr_date', header: 'QBR', render: (r: Plan) => fmtDate(r.qbr_date) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Plan, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="White Space Ranking">
        <DataTable
          rows={whitespaceRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: WhiteSpace) => r.chain_name },
            { key: 'white_space_rupees', header: 'White Space', render: (r: WhiteSpace) => fmtRupees(r.white_space_rupees) },
            { key: 'wedge_product', header: 'Wedge', render: (r: WhiteSpace) => r.wedge_product },
            { key: 'primary_stakeholder', header: 'Stakeholder', render: (r: WhiteSpace) => r.primary_stakeholder },
            { key: 'relationship_health', header: 'Health', render: (r: WhiteSpace) => r.relationship_health },
            { key: 'plan_status', header: 'Status', render: (r: WhiteSpace) => r.plan_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: WhiteSpace, i: number) => String(r.chain_name ?? i)}
        />
      </Section>

      <Section title="Stakeholder Health Roll-up">
        <DataTable
          rows={healthRows}
          columns={[
            { key: 'relationship_health', header: 'Health', render: (r: Health) => r.relationship_health },
            { key: 'chain_count', header: 'Chains', render: (r: Health) => String(r.chain_count) },
            { key: 'total_arr', header: 'Current ARR', render: (r: Health) => fmtRupees(r.total_arr) },
            { key: 'total_white_space', header: 'White Space', render: (r: Health) => fmtRupees(r.total_white_space) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Health, i: number) => String(r.relationship_health ?? i)}
        />
      </Section>

      <Section title="Upcoming QBRs (next 60 days)">
        <DataTable
          rows={qbrRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Qbr) => r.chain_name },
            { key: 'qbr_date', header: 'QBR Date', render: (r: Qbr) => fmtDate(r.qbr_date) },
            { key: 'days_until', header: 'Days', render: (r: Qbr) => String(r.days_until) },
            { key: 'owner', header: 'Owner', render: (r: Qbr) => r.owner },
            { key: 'plan_status', header: 'Status', render: (r: Qbr) => r.plan_status },
            { key: 'current_arr_rupees', header: 'Current ARR', render: (r: Qbr) => fmtRupees(r.current_arr_rupees) },
            { key: 'white_space_rupees', header: 'White Space', render: (r: Qbr) => fmtRupees(r.white_space_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Qbr, i: number) => String(r.chain_name ?? i)}
        />
      </Section>

      <Section title="Blocked Actions Needing Escalation">
        <DataTable
          rows={blockedRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Blocked) => r.chain_name },
            { key: 'milestone_name', header: 'Milestone', render: (r: Blocked) => r.milestone_name },
            { key: 'action_text', header: 'Action', render: (r: Blocked) => r.action_text },
            { key: 'blocker_text', header: 'Blocker', render: (r: Blocked) => r.blocker_text ?? '-' },
            { key: 'value_unlock_rupees', header: 'Value', render: (r: Blocked) => fmtRupees(r.value_unlock_rupees) },
            { key: 'due_date', header: 'Due', render: (r: Blocked) => fmtDate(r.due_date) },
            { key: 'relationship_health', header: 'Health', render: (r: Blocked) => r.relationship_health },
            { key: 'primary_stakeholder', header: 'Stakeholder', render: (r: Blocked) => r.primary_stakeholder },
          ]}
          emptyMessage="No data"
          rowKey={(r: Blocked, i: number) => String(r.chain_name + r.milestone_name)}
        />
      </Section>

      <Section title="All Milestones & Actions">
        <DataTable
          rows={actionRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Action) => r.chain_name },
            { key: 'milestone_name', header: 'Milestone', render: (r: Action) => r.milestone_name },
            { key: 'action_text', header: 'Action', render: (r: Action) => r.action_text },
            { key: 'action_owner', header: 'Owner', render: (r: Action) => r.action_owner },
            { key: 'due_date', header: 'Due', render: (r: Action) => fmtDate(r.due_date) },
            { key: 'action_type', header: 'Type', render: (r: Action) => r.action_type },
            { key: 'value_unlock_rupees', header: 'Value', render: (r: Action) => fmtRupees(r.value_unlock_rupees) },
            { key: 'status', header: 'Status', render: (r: Action) => r.status },
            { key: 'blocker_text', header: 'Blocker', render: (r: Action) => r.blocker_text ?? '-' },
            { key: 'completed_at', header: 'Completed', render: (r: Action) => r.completed_at ? fmtDate(r.completed_at) : '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Action, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Action Progress by Type">
        <DataTable
          rows={progressRows}
          columns={[
            { key: 'action_type', header: 'Type', render: (r: Progress) => r.action_type },
            { key: 'total_actions', header: 'Total', render: (r: Progress) => String(r.total_actions) },
            { key: 'done_count', header: 'Done', render: (r: Progress) => String(r.done_count) },
            { key: 'blocked_count', header: 'Blocked', render: (r: Progress) => String(r.blocked_count) },
            { key: 'done_pct', header: 'Done %', render: (r: Progress) => fmtPct(r.done_pct) },
            { key: 'total_value_unlock', header: 'Value Unlock', render: (r: Progress) => fmtRupees(r.total_value_unlock) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Progress, i: number) => String(r.action_type ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </div>
  );
}