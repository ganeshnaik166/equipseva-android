import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_requests: number;
  total_delta_rupees: number;
  avg_delta_rupees: number;
  disagree_count: number;
  full_agree_count: number;
  learning_logged_count: number;
  avg_satisfaction: number;
};

type RequestRow = {
  id: string;
  job_ref: string;
  customer_org: string;
  equipment_kind: string;
  first_engineer_name: string;
  first_quote_rupees: number;
  second_engineer_name: string;
  second_quote_rupees: number;
  delta_rupees: number;
  consensus_state: string;
  outcome: string;
  customer_satisfaction: number;
};

type ConsensusRow = {
  consensus_state: string;
  request_count: number;
  total_delta: number;
  avg_satisfaction: number;
};

type OutcomeRow = {
  outcome: string;
  request_count: number;
  total_delta: number;
};

type EngineerRow = {
  engineer_name: string;
  appearances: number;
  first_correct_count: number;
  total_delta_saved: number;
};

type LearningRow = {
  id: string;
  job_ref: string;
  root_cause_category: string;
  root_cause_detail: string;
  corrective_action: string;
  owner_team: string;
  status: string;
  impact_avoided_rupees: number;
  due_date: string;
};

type RootCauseRow = {
  root_cause_category: string;
  learning_count: number;
  total_impact: number;
  open_count: number;
  done_count: number;
};

type OwnerLoadRow = {
  owner_team: string;
  open_items: number;
  in_progress_items: number;
  done_items: number;
  total_impact: number;
};

function fmtINR(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, requestsRes, consensusRes, outcomeRes, engineerRes, learningRes, rootCauseRes, ownerLoadRes] = await Promise.all([
    supabase.rpc('founder_r2808_kpis'),
    supabase.rpc('founder_r2808_list_requests'),
    supabase.rpc('founder_r2808_consensus_breakdown'),
    supabase.rpc('founder_r2808_outcome_breakdown'),
    supabase.rpc('founder_r2808_engineer_scorecard'),
    supabase.rpc('founder_r2808_learning_catalog'),
    supabase.rpc('founder_r2808_root_cause_rollup'),
    supabase.rpc('founder_r2808_owner_team_load'),
  ]);

  const kpi: Kpi = (kpisRes.data?.[0] ?? {
    total_requests: 0,
    total_delta_rupees: 0,
    avg_delta_rupees: 0,
    disagree_count: 0,
    full_agree_count: 0,
    learning_logged_count: 0,
    avg_satisfaction: 0,
  }) as Kpi;

  const requests: RequestRow[] = (requestsRes.data ?? []) as RequestRow[];
  const consensus: ConsensusRow[] = (consensusRes.data ?? []) as ConsensusRow[];
  const outcomes: OutcomeRow[] = (outcomeRes.data ?? []) as OutcomeRow[];
  const engineers: EngineerRow[] = (engineerRes.data ?? []) as EngineerRow[];
  const learnings: LearningRow[] = (learningRes.data ?? []) as LearningRow[];
  const rootCauses: RootCauseRow[] = (rootCauseRes.data ?? []) as RootCauseRow[];
  const ownerLoad: OwnerLoadRow[] = (ownerLoadRes.data ?? []) as OwnerLoadRow[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer Monthly Engineer Second Opinion Request</h1>
        <p className="text-sm text-gray-600">
          Job × first engineer × second opinion engineer × delta × consensus × outcome × learning.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Total Requests</div>
          <div className="mt-1 text-2xl font-semibold">{kpi.total_requests}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Total Delta</div>
          <div className="mt-1 text-2xl font-semibold">{fmtINR(kpi.total_delta_rupees)}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Avg Delta / Request</div>
          <div className="mt-1 text-2xl font-semibold">{fmtINR(kpi.avg_delta_rupees)}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Disagree Cases</div>
          <div className="mt-1 text-2xl font-semibold">{kpi.disagree_count}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Full Agree Cases</div>
          <div className="mt-1 text-2xl font-semibold">{kpi.full_agree_count}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Learnings Logged</div>
          <div className="mt-1 text-2xl font-semibold">{kpi.learning_logged_count}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Avg Satisfaction</div>
          <div className="mt-1 text-2xl font-semibold">{Number(kpi.avg_satisfaction ?? 0).toFixed(2)} / 5</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Learning Coverage</div>
          <div className="mt-1 text-2xl font-semibold">
            {kpi.total_requests > 0
              ? Math.round((Number(kpi.learning_logged_count) / Number(kpi.total_requests)) * 100)
              : 0}
            %
          </div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Requests (sorted by delta)</h2>
        <DataTable
          rows={requests}
          columns={[
            { key: 'job_ref', header: 'Job', render: (r: RequestRow) => r.job_ref },
            { key: 'customer_org', header: 'Customer', render: (r: RequestRow) => r.customer_org },
            { key: 'equipment_kind', header: 'Equipment', render: (r: RequestRow) => r.equipment_kind },
            { key: 'first', header: 'First Eng / Quote', render: (r: RequestRow) => `${r.first_engineer_name} — ${fmtINR(r.first_quote_rupees)}` },
            { key: 'second', header: '2nd Eng / Quote', render: (r: RequestRow) => `${r.second_engineer_name} — ${fmtINR(r.second_quote_rupees)}` },
            { key: 'delta_rupees', header: 'Delta', render: (r: RequestRow) => fmtINR(r.delta_rupees) },
            { key: 'consensus_state', header: 'Consensus', render: (r: RequestRow) => r.consensus_state },
            { key: 'outcome', header: 'Outcome', render: (r: RequestRow) => r.outcome },
            { key: 'customer_satisfaction', header: 'CSAT', render: (r: RequestRow) => `${r.customer_satisfaction} / 5` },
          ]}
          emptyMessage="No data"
          rowKey={(r: RequestRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Consensus Breakdown</h2>
          <DataTable
            rows={consensus}
            columns={[
              { key: 'consensus_state', header: 'State', render: (r: ConsensusRow) => r.consensus_state },
              { key: 'request_count', header: 'Count', render: (r: ConsensusRow) => String(r.request_count) },
              { key: 'total_delta', header: 'Total Delta', render: (r: ConsensusRow) => fmtINR(r.total_delta) },
              { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: ConsensusRow) => Number(r.avg_satisfaction ?? 0).toFixed(2) },
            ]}
            emptyMessage="No data"
            rowKey={(r: ConsensusRow, i: number) => String(r.consensus_state ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Outcome Breakdown</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'request_count', header: 'Count', render: (r: OutcomeRow) => String(r.request_count) },
              { key: 'total_delta', header: 'Total Delta', render: (r: OutcomeRow) => fmtINR(r.total_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Engineer Scorecard</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'appearances', header: 'Appearances', render: (r: EngineerRow) => String(r.appearances) },
            { key: 'first_correct_count', header: 'Correct Calls', render: (r: EngineerRow) => String(r.first_correct_count) },
            { key: 'total_delta_saved', header: 'Delta Saved', render: (r: EngineerRow) => fmtINR(r.total_delta_saved) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Learning Catalog</h2>
        <DataTable
          rows={learnings}
          columns={[
            { key: 'job_ref', header: 'Job', render: (r: LearningRow) => r.job_ref },
            { key: 'root_cause_category', header: 'Category', render: (r: LearningRow) => r.root_cause_category },
            { key: 'root_cause_detail', header: 'Root Cause', render: (r: LearningRow) => r.root_cause_detail },
            { key: 'corrective_action', header: 'Action', render: (r: LearningRow) => r.corrective_action },
            { key: 'owner_team', header: 'Owner', render: (r: LearningRow) => r.owner_team },
            { key: 'status', header: 'Status', render: (r: LearningRow) => r.status },
            { key: 'impact_avoided_rupees', header: 'Impact', render: (r: LearningRow) => fmtINR(r.impact_avoided_rupees) },
            { key: 'due_date', header: 'Due', render: (r: LearningRow) => r.due_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: LearningRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Root Cause Rollup</h2>
          <DataTable
            rows={rootCauses}
            columns={[
              { key: 'root_cause_category', header: 'Category', render: (r: RootCauseRow) => r.root_cause_category },
              { key: 'learning_count', header: 'Items', render: (r: RootCauseRow) => String(r.learning_count) },
              { key: 'total_impact', header: 'Impact', render: (r: RootCauseRow) => fmtINR(r.total_impact) },
              { key: 'open_count', header: 'Open', render: (r: RootCauseRow) => String(r.open_count) },
              { key: 'done_count', header: 'Done', render: (r: RootCauseRow) => String(r.done_count) },
            ]}
            emptyMessage="No data"
            rowKey={(r: RootCauseRow, i: number) => String(r.root_cause_category ?? i)}
          />
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Owner Team Load</h2>
          <DataTable
            rows={ownerLoad}
            columns={[
              { key: 'owner_team', header: 'Team', render: (r: OwnerLoadRow) => r.owner_team },
              { key: 'open_items', header: 'Open', render: (r: OwnerLoadRow) => String(r.open_items) },
              { key: 'in_progress_items', header: 'In Progress', render: (r: OwnerLoadRow) => String(r.in_progress_items) },
              { key: 'done_items', header: 'Done', render: (r: OwnerLoadRow) => String(r.done_items) },
              { key: 'total_impact', header: 'Impact', render: (r: OwnerLoadRow) => fmtINR(r.total_impact) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OwnerLoadRow, i: number) => String(r.owner_team ?? i)}
          />
        </div>
      </section>
    </div>
  );
}
