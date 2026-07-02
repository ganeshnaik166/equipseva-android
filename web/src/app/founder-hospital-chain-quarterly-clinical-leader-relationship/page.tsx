import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_leaders: number;
  deciders: number;
  champions: number;
  blockers: number;
  avg_warmth: number;
  touchpoints_this_q: number;
  open_commitments: number;
  pipeline_rupees: number;
};

type Leader = {
  id: string;
  chain_name: string;
  leader_name: string;
  leader_role: string;
  tenure_months: number;
  influence_tier: string;
  warmth_score: number;
  last_touchpoint_at: string | null;
  next_touchpoint_due_at: string | null;
};

type Touchpoint = {
  id: string;
  chain_name: string;
  leader_name: string;
  quarter: string;
  touchpoint_type: string;
  touchpoint_at: string;
  ask_summary: string;
  commitment_summary: string | null;
  commitment_status: string;
  outcome: string | null;
  revenue_impact_rupees: number;
  follow_up_due_at: string | null;
};

type Funnel = { outcome: string; touchpoints: number; total_impact_rupees: number };
type Overdue = {
  chain_name: string;
  leader_name: string;
  ask_summary: string;
  follow_up_due_at: string;
  days_overdue: number;
  commitment_status: string;
};
type WarmthByChain = {
  chain_name: string;
  leaders: number;
  avg_warmth: number;
  top_role: string;
  pipeline_rupees: number;
};
type TenureCohort = { cohort: string; leaders: number; avg_warmth: number; deciders: number };
type TouchpointEff = {
  touchpoint_type: string;
  events: number;
  delivered: number;
  delivered_pct: number;
  total_impact_rupees: number;
};

function rupees(n: number | null | undefined): string {
  if (!n) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtDate(d: string | null): string {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    leadersRes,
    touchpointsRes,
    funnelRes,
    overdueRes,
    warmthByChainRes,
    tenureCohortRes,
    touchpointEffRes,
  ] = await Promise.all([
    supabase.rpc('founder_chain_leader_kpi_r2751'),
    supabase.rpc('founder_chain_leaders_list_r2751'),
    supabase.rpc('founder_chain_touchpoints_log_r2751'),
    supabase.rpc('founder_chain_outcome_funnel_r2751'),
    supabase.rpc('founder_chain_overdue_followups_r2751'),
    supabase.rpc('founder_chain_warmth_by_chain_r2751'),
    supabase.rpc('founder_chain_tenure_cohort_r2751'),
    supabase.rpc('founder_chain_touchpoint_effectiveness_r2751'),
  ]);

  const kpi: Kpi | null = (kpiRes.data as Kpi[] | null)?.[0] ?? null;
  const leaders: Leader[] = (leadersRes.data as Leader[] | null) ?? [];
  const touchpoints: Touchpoint[] = (touchpointsRes.data as Touchpoint[] | null) ?? [];
  const funnel: Funnel[] = (funnelRes.data as Funnel[] | null) ?? [];
  const overdue: Overdue[] = (overdueRes.data as Overdue[] | null) ?? [];
  const warmthByChain: WarmthByChain[] = (warmthByChainRes.data as WarmthByChain[] | null) ?? [];
  const tenureCohort: TenureCohort[] = (tenureCohortRes.data as TenureCohort[] | null) ?? [];
  const touchpointEff: TouchpointEff[] = (touchpointEffRes.data as TouchpointEff[] | null) ?? [];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain — Quarterly Clinical Leader Relationship</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain × leader × tenure × touchpoint × ask × commitment × outcome.
          Track every CMO, head-of-biomed, and clinical decider relationship across the quarter.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Leaders" value={kpi?.total_leaders ?? 0} />
        <KpiCard label="Deciders" value={kpi?.deciders ?? 0} />
        <KpiCard label="Champions" value={kpi?.champions ?? 0} />
        <KpiCard label="Blockers" value={kpi?.blockers ?? 0} />
        <KpiCard label="Avg Warmth (0-10)" value={kpi?.avg_warmth ?? 0} />
        <KpiCard label="Touchpoints (this Q)" value={kpi?.touchpoints_this_q ?? 0} />
        <KpiCard label="Open Commitments" value={kpi?.open_commitments ?? 0} />
        <KpiCard label="Pipeline (INR)" value={rupees(kpi?.pipeline_rupees ?? 0)} />
      </section>

      <Section title="Leaders by Influence and Warmth">
        <DataTable
          rows={leaders}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No leaders"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'leader_name', header: 'Leader', render: (r) => r.leader_name },
            { key: 'leader_role', header: 'Role', render: (r) => r.leader_role },
            { key: 'tenure_months', header: 'Tenure (mo)', render: (r) => r.tenure_months },
            { key: 'influence_tier', header: 'Influence', render: (r) => r.influence_tier },
            { key: 'warmth_score', header: 'Warmth', render: (r) => r.warmth_score },
            { key: 'next_touchpoint_due_at', header: 'Next Touch', render: (r) => fmtDate(r.next_touchpoint_due_at) },
          ]}
        />
      </Section>

      <Section title="Touchpoint Log — Ask, Commitment, Outcome">
        <DataTable
          rows={touchpoints}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No touchpoints"
          columns={[
            { key: 'touchpoint_at', header: 'Date', render: (r) => fmtDate(r.touchpoint_at) },
            { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'leader_name', header: 'Leader', render: (r) => r.leader_name },
            { key: 'touchpoint_type', header: 'Type', render: (r) => r.touchpoint_type },
            { key: 'ask_summary', header: 'Ask', render: (r) => r.ask_summary },
            { key: 'commitment_summary', header: 'Commitment', render: (r) => r.commitment_summary ?? '-' },
            { key: 'commitment_status', header: 'Status', render: (r) => r.commitment_status },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome ?? '-' },
            { key: 'revenue_impact_rupees', header: 'Impact (INR)', render: (r) => rupees(r.revenue_impact_rupees) },
          ]}
        />
      </Section>

      <Section title="Outcome Funnel">
        <DataTable
          rows={funnel}
          rowKey={(r, i) => String(r.outcome ?? i)}
          emptyMessage="No outcomes"
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            { key: 'touchpoints', header: 'Touchpoints', render: (r) => r.touchpoints },
            { key: 'total_impact_rupees', header: 'Impact (INR)', render: (r) => rupees(r.total_impact_rupees) },
          ]}
        />
      </Section>

      <Section title="Overdue Follow-ups">
        <DataTable
          rows={overdue}
          rowKey={(r, i) => String(i)}
          emptyMessage="No overdue follow-ups"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'leader_name', header: 'Leader', render: (r) => r.leader_name },
            { key: 'ask_summary', header: 'Ask', render: (r) => r.ask_summary },
            { key: 'follow_up_due_at', header: 'Due', render: (r) => fmtDate(r.follow_up_due_at) },
            { key: 'days_overdue', header: 'Days Overdue', render: (r) => r.days_overdue },
            { key: 'commitment_status', header: 'Status', render: (r) => r.commitment_status },
          ]}
        />
      </Section>

      <Section title="Warmth by Chain">
        <DataTable
          rows={warmthByChain}
          rowKey={(r, i) => String(r.chain_name ?? i)}
          emptyMessage="No chains"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
            { key: 'leaders', header: 'Leaders', render: (r) => r.leaders },
            { key: 'avg_warmth', header: 'Avg Warmth', render: (r) => r.avg_warmth },
            { key: 'top_role', header: 'Top Role', render: (r) => r.top_role },
            { key: 'pipeline_rupees', header: 'Pipeline (INR)', render: (r) => rupees(r.pipeline_rupees) },
          ]}
        />
      </Section>

      <Section title="Tenure Cohort Warmth">
        <DataTable
          rows={tenureCohort}
          rowKey={(r, i) => String(r.cohort ?? i)}
          emptyMessage="No cohorts"
          columns={[
            { key: 'cohort', header: 'Cohort', render: (r) => r.cohort },
            { key: 'leaders', header: 'Leaders', render: (r) => r.leaders },
            { key: 'avg_warmth', header: 'Avg Warmth', render: (r) => r.avg_warmth },
            { key: 'deciders', header: 'Deciders', render: (r) => r.deciders },
          ]}
        />
      </Section>

      <Section title="Touchpoint Type Effectiveness">
        <DataTable
          rows={touchpointEff}
          rowKey={(r, i) => String(r.touchpoint_type ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'touchpoint_type', header: 'Type', render: (r) => r.touchpoint_type },
            { key: 'events', header: 'Events', render: (r) => r.events },
            { key: 'delivered', header: 'Delivered', render: (r) => r.delivered },
            { key: 'delivered_pct', header: 'Delivered %', render: (r) => r.delivered_pct },
            { key: 'total_impact_rupees', header: 'Impact (INR)', render: (r) => rupees(r.total_impact_rupees) },
          ]}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold">{title}</h2>
      {children}
    </section>
  );
}
