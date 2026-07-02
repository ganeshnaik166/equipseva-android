import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_members: number;
  avg_energy: number;
  red_count: number;
  amber_count: number;
  green_count: number;
  burnout_risk_count: number;
  flagged_followup: number;
  actions_in_progress: number;
  total_support_cost: number;
};

type Pulse = {
  team_member: string;
  role: string;
  energy_score: number;
  signal: string;
  morale_color: string;
  workload_load: number;
  sleep_quality: number;
  flagged_for_followup: boolean;
  signal_notes: string | null;
};

type AtRisk = {
  team_member: string;
  role: string;
  energy_score: number;
  signal: string;
  signal_notes: string | null;
  workload_load: number;
  sleep_quality: number;
};

type Action = {
  team_member: string;
  supportive_action: string;
  action_category: string;
  initiated_by: string;
  initiated_at: string;
  outcome: string;
  followup_status: string;
  cost_inr: number;
};

type Outcome = {
  outcome: string;
  action_count: number;
  total_cost: number;
};

type Followup = {
  team_member: string;
  supportive_action: string;
  followup_due: string;
  followup_status: string;
  days_until_due: number;
};

type Signal = {
  signal: string;
  member_count: number;
  avg_energy: number;
};

type Category = {
  action_category: string;
  action_count: number;
  total_cost: number;
  resolved_count: number;
};

function fmtINR(n: number | null | undefined) {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, pulsesRes, atRiskRes, actionsRes, outcomesRes, followupsRes, signalsRes, categoriesRes] =
    await Promise.all([
      supabase.rpc('founder_team_energy_kpis_r2697'),
      supabase.rpc('founder_team_energy_pulses_r2697'),
      supabase.rpc('founder_team_energy_at_risk_r2697'),
      supabase.rpc('founder_team_energy_actions_r2697'),
      supabase.rpc('founder_team_energy_outcomes_r2697'),
      supabase.rpc('founder_team_energy_followups_r2697'),
      supabase.rpc('founder_team_energy_signal_distribution_r2697'),
      supabase.rpc('founder_team_energy_action_categories_r2697'),
    ]);

  const kpi: Kpi = (kpisRes.data?.[0] as Kpi) ?? {
    total_members: 0,
    avg_energy: 0,
    red_count: 0,
    amber_count: 0,
    green_count: 0,
    burnout_risk_count: 0,
    flagged_followup: 0,
    actions_in_progress: 0,
    total_support_cost: 0,
  };

  const pulses: Pulse[] = (pulsesRes.data as Pulse[]) ?? [];
  const atRisk: AtRisk[] = (atRiskRes.data as AtRisk[]) ?? [];
  const actions: Action[] = (actionsRes.data as Action[]) ?? [];
  const outcomes: Outcome[] = (outcomesRes.data as Outcome[]) ?? [];
  const followups: Followup[] = (followupsRes.data as Followup[]) ?? [];
  const signals: Signal[] = (signalsRes.data as Signal[]) ?? [];
  const categories: Category[] = (categoriesRes.data as Category[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Quarterly Team Energy Pulse</h1>
        <p className="text-sm text-gray-600">
          Read each teammate's energy & signal, see what support landed, and what follow-up is owed.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Team Members" value={String(kpi.total_members)} />
        <KpiCard label="Avg Energy (1-10)" value={String(kpi.avg_energy ?? 0)} />
        <KpiCard label="Red" value={String(kpi.red_count)} accent="red" />
        <KpiCard label="Amber" value={String(kpi.amber_count)} accent="amber" />
        <KpiCard label="Green" value={String(kpi.green_count)} accent="green" />
        <KpiCard label="Burnout Risk" value={String(kpi.burnout_risk_count)} accent="red" />
        <KpiCard label="Flagged Follow-up" value={String(kpi.flagged_followup)} />
        <KpiCard label="Support Spend" value={fmtINR(kpi.total_support_cost)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">At-Risk Roster (energy &lt;= 5 or red/amber)</h2>
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'team_member', header: 'Member', render: (r: AtRisk) => r.team_member },
            { key: 'role', header: 'Role', render: (r: AtRisk) => r.role },
            { key: 'energy_score', header: 'Energy', render: (r: AtRisk) => String(r.energy_score) },
            { key: 'signal', header: 'Signal', render: (r: AtRisk) => r.signal },
            { key: 'workload_load', header: 'Workload', render: (r: AtRisk) => String(r.workload_load) },
            { key: 'sleep_quality', header: 'Sleep', render: (r: AtRisk) => String(r.sleep_quality) },
            { key: 'signal_notes', header: 'Notes', render: (r: AtRisk) => r.signal_notes ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRisk, i: number) => String(r.team_member ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Pulses This Quarter</h2>
        <DataTable
          rows={pulses}
          columns={[
            { key: 'team_member', header: 'Member', render: (r: Pulse) => r.team_member },
            { key: 'role', header: 'Role', render: (r: Pulse) => r.role },
            { key: 'energy_score', header: 'Energy', render: (r: Pulse) => String(r.energy_score) },
            { key: 'signal', header: 'Signal', render: (r: Pulse) => r.signal },
            { key: 'morale_color', header: 'Color', render: (r: Pulse) => r.morale_color },
            { key: 'workload_load', header: 'Workload', render: (r: Pulse) => String(r.workload_load) },
            { key: 'sleep_quality', header: 'Sleep', render: (r: Pulse) => String(r.sleep_quality) },
            { key: 'flagged_for_followup', header: 'Flagged', render: (r: Pulse) => (r.flagged_for_followup ? 'Yes' : 'No') },
            { key: 'signal_notes', header: 'Notes', render: (r: Pulse) => r.signal_notes ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Pulse, i: number) => String(r.team_member ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Supportive Actions Taken</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'team_member', header: 'Member', render: (r: Action) => r.team_member },
            { key: 'supportive_action', header: 'Action', render: (r: Action) => r.supportive_action },
            { key: 'action_category', header: 'Category', render: (r: Action) => r.action_category },
            { key: 'initiated_by', header: 'By', render: (r: Action) => r.initiated_by },
            { key: 'initiated_at', header: 'When', render: (r: Action) => r.initiated_at },
            { key: 'outcome', header: 'Outcome', render: (r: Action) => r.outcome },
            { key: 'followup_status', header: 'Follow-up', render: (r: Action) => r.followup_status },
            { key: 'cost_inr', header: 'Cost', render: (r: Action) => fmtINR(r.cost_inr) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Action, i: number) => String(i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-3">Outcome Breakdown</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: Outcome) => r.outcome },
              { key: 'action_count', header: 'Actions', render: (r: Outcome) => String(r.action_count) },
              { key: 'total_cost', header: 'Cost', render: (r: Outcome) => fmtINR(r.total_cost) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Outcome, i: number) => String(r.outcome ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-3">Signal Distribution</h2>
          <DataTable
            rows={signals}
            columns={[
              { key: 'signal', header: 'Signal', render: (r: Signal) => r.signal },
              { key: 'member_count', header: 'Members', render: (r: Signal) => String(r.member_count) },
              { key: 'avg_energy', header: 'Avg Energy', render: (r: Signal) => String(r.avg_energy) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Signal, i: number) => String(r.signal ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Follow-up Queue (pending & scheduled)</h2>
        <DataTable
          rows={followups}
          columns={[
            { key: 'team_member', header: 'Member', render: (r: Followup) => r.team_member },
            { key: 'supportive_action', header: 'Action', render: (r: Followup) => r.supportive_action },
            { key: 'followup_due', header: 'Due', render: (r: Followup) => r.followup_due },
            { key: 'followup_status', header: 'Status', render: (r: Followup) => r.followup_status },
            { key: 'days_until_due', header: 'Days Until Due', render: (r: Followup) => String(r.days_until_due) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Followup, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Support Action Category ROI</h2>
        <DataTable
          rows={categories}
          columns={[
            { key: 'action_category', header: 'Category', render: (r: Category) => r.action_category },
            { key: 'action_count', header: 'Count', render: (r: Category) => String(r.action_count) },
            { key: 'resolved_count', header: 'Resolved/Improved', render: (r: Category) => String(r.resolved_count) },
            { key: 'total_cost', header: 'Spend', render: (r: Category) => fmtINR(r.total_cost) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Category, i: number) => String(r.action_category ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string; accent?: 'red' | 'amber' | 'green' }) {
  const accentClass =
    accent === 'red'
      ? 'border-red-300 bg-red-50'
      : accent === 'amber'
      ? 'border-amber-300 bg-amber-50'
      : accent === 'green'
      ? 'border-green-300 bg-green-50'
      : 'border-gray-200 bg-white';
  return (
    <div className={`rounded-lg border p-4 ${accentClass}`}>
      <div className="text-xs uppercase tracking-wide text-gray-600">{label}</div>
      <div className="text-2xl font-semibold mt-1">{value}</div>
    </div>
  );
}
