import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_chains: number;
  active_cycles: number;
  total_proposed_rupees: number;
  total_approved_rupees: number;
  total_disbursed_rupees: number;
  approval_rate: number;
  utilisation_avg: number;
};

type Contact = {
  id: string;
  chain_name: string;
  cfo_name: string;
  cfo_email: string;
  hq_city: string;
  bed_count: number;
  fy_budget_rupees: number;
  relationship_tier: string;
  last_touch_at: string;
};

type Cycle = {
  id: string;
  chain_name: string;
  cfo_name: string;
  cycle_month: string;
  proposed_amount_rupees: number;
  approved_amount_rupees: number;
  disbursed_amount_rupees: number;
  approval_status: string;
  outcome_status: string;
  utilisation_pct: number;
  variance_rupees: number;
  proposal_owner: string;
  finance_reviewer: string;
};

type Funnel = { approval_status: string; cycle_count: number; proposed_sum: number; approved_sum: number };
type Outcome = { outcome_status: string; cycle_count: number; disbursed_sum: number; avg_utilisation: number };
type Variance = { chain_name: string; cycle_month: string; variance_rupees: number; utilisation_pct: number; outcome_status: string };
type Tier = { relationship_tier: string; chain_count: number; fy_budget_sum: number; bed_count_sum: number };
type Pending = { chain_name: string; cycle_month: string; approval_status: string; proposed_amount_rupees: number; proposal_owner: string; finance_reviewer: string; days_in_status: number };

function rupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, contactsRes, cyclesRes, funnelRes, outcomeRes, varianceRes, tierRes, pendingRes] = await Promise.all([
    supabase.rpc('r2715_kpi_summary'),
    supabase.rpc('r2715_list_contacts'),
    supabase.rpc('r2715_list_cycles'),
    supabase.rpc('r2715_approval_funnel'),
    supabase.rpc('r2715_outcome_distribution'),
    supabase.rpc('r2715_top_variance'),
    supabase.rpc('r2715_tier_mix'),
    supabase.rpc('r2715_pending_actions'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_chains: 0, active_cycles: 0, total_proposed_rupees: 0, total_approved_rupees: 0,
    total_disbursed_rupees: 0, approval_rate: 0, utilisation_avg: 0,
  }) as Kpi;
  const contacts: Contact[] = (contactsRes.data ?? []) as Contact[];
  const cycles: Cycle[] = (cyclesRes.data ?? []) as Cycle[];
  const funnel: Funnel[] = (funnelRes.data ?? []) as Funnel[];
  const outcomes: Outcome[] = (outcomeRes.data ?? []) as Outcome[];
  const variances: Variance[] = (varianceRes.data ?? []) as Variance[];
  const tiers: Tier[] = (tierRes.data ?? []) as Tier[];
  const pending: Pending[] = (pendingRes.data ?? []) as Pending[];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Monthly Finance Team Budget Cycle</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track CFO contact & monthly proposal &rarr; approval &rarr; disbursement &rarr; outcome across hospital chains.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Chains</div>
          <div className="text-2xl font-semibold">{kpi.total_chains}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Active cycles</div>
          <div className="text-2xl font-semibold">{kpi.active_cycles}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Proposed</div>
          <div className="text-2xl font-semibold">{rupees(kpi.total_proposed_rupees)}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Approved</div>
          <div className="text-2xl font-semibold">{rupees(kpi.total_approved_rupees)}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Disbursed</div>
          <div className="text-2xl font-semibold">{rupees(kpi.total_disbursed_rupees)}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Approval rate</div>
          <div className="text-2xl font-semibold">{Number(kpi.approval_rate ?? 0).toFixed(2)}%</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Avg utilisation</div>
          <div className="text-2xl font-semibold">{Number(kpi.utilisation_avg ?? 0).toFixed(2)}%</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs uppercase text-gray-500">Disbursed / Approved</div>
          <div className="text-2xl font-semibold">
            {kpi.total_approved_rupees > 0
              ? ((kpi.total_disbursed_rupees / kpi.total_approved_rupees) * 100).toFixed(1) + '%'
              : '-'}
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">CFO contacts</h2>
        <DataTable
          rows={contacts}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Contact) => r.chain_name },
            { key: 'cfo_name', header: 'CFO', render: (r: Contact) => r.cfo_name },
            { key: 'cfo_email', header: 'Email', render: (r: Contact) => r.cfo_email },
            { key: 'hq_city', header: 'HQ', render: (r: Contact) => r.hq_city },
            { key: 'bed_count', header: 'Beds', render: (r: Contact) => r.bed_count.toLocaleString('en-IN') },
            { key: 'fy_budget_rupees', header: 'FY budget', render: (r: Contact) => rupees(r.fy_budget_rupees) },
            { key: 'relationship_tier', header: 'Tier', render: (r: Contact) => r.relationship_tier },
          ]}
          emptyMessage="No data"
          rowKey={(r: Contact, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly budget cycles</h2>
        <DataTable
          rows={cycles}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Cycle) => r.chain_name },
            { key: 'cycle_month', header: 'Month', render: (r: Cycle) => String(r.cycle_month).slice(0, 7) },
            { key: 'proposed_amount_rupees', header: 'Proposed', render: (r: Cycle) => rupees(r.proposed_amount_rupees) },
            { key: 'approved_amount_rupees', header: 'Approved', render: (r: Cycle) => rupees(r.approved_amount_rupees) },
            { key: 'disbursed_amount_rupees', header: 'Disbursed', render: (r: Cycle) => rupees(r.disbursed_amount_rupees) },
            { key: 'approval_status', header: 'Approval', render: (r: Cycle) => r.approval_status },
            { key: 'outcome_status', header: 'Outcome', render: (r: Cycle) => r.outcome_status },
            { key: 'utilisation_pct', header: 'Utilisation', render: (r: Cycle) => Number(r.utilisation_pct).toFixed(2) + '%' },
            { key: 'variance_rupees', header: 'Variance', render: (r: Cycle) => rupees(r.variance_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Cycle, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Approval funnel</h2>
          <DataTable
            rows={funnel}
            columns={[
              { key: 'approval_status', header: 'Status', render: (r: Funnel) => r.approval_status },
              { key: 'cycle_count', header: 'Cycles', render: (r: Funnel) => String(r.cycle_count) },
              { key: 'proposed_sum', header: 'Proposed', render: (r: Funnel) => rupees(r.proposed_sum) },
              { key: 'approved_sum', header: 'Approved', render: (r: Funnel) => rupees(r.approved_sum) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Funnel, i: number) => String(r.approval_status ?? i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Outcome distribution</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome_status', header: 'Outcome', render: (r: Outcome) => r.outcome_status },
              { key: 'cycle_count', header: 'Cycles', render: (r: Outcome) => String(r.cycle_count) },
              { key: 'disbursed_sum', header: 'Disbursed', render: (r: Outcome) => rupees(r.disbursed_sum) },
              { key: 'avg_utilisation', header: 'Avg util', render: (r: Outcome) => Number(r.avg_utilisation).toFixed(2) + '%' },
            ]}
            emptyMessage="No data"
            rowKey={(r: Outcome, i: number) => String(r.outcome_status ?? i)}
          />
        </div>
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Top variance cycles</h2>
          <DataTable
            rows={variances}
            columns={[
              { key: 'chain_name', header: 'Chain', render: (r: Variance) => r.chain_name },
              { key: 'cycle_month', header: 'Month', render: (r: Variance) => String(r.cycle_month).slice(0, 7) },
              { key: 'variance_rupees', header: 'Variance', render: (r: Variance) => rupees(r.variance_rupees) },
              { key: 'utilisation_pct', header: 'Util', render: (r: Variance) => Number(r.utilisation_pct).toFixed(2) + '%' },
              { key: 'outcome_status', header: 'Outcome', render: (r: Variance) => r.outcome_status },
            ]}
            emptyMessage="No data"
            rowKey={(r: Variance, i: number) => String(i)}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Relationship tier mix</h2>
          <DataTable
            rows={tiers}
            columns={[
              { key: 'relationship_tier', header: 'Tier', render: (r: Tier) => r.relationship_tier },
              { key: 'chain_count', header: 'Chains', render: (r: Tier) => String(r.chain_count) },
              { key: 'fy_budget_sum', header: 'FY budget', render: (r: Tier) => rupees(r.fy_budget_sum) },
              { key: 'bed_count_sum', header: 'Beds', render: (r: Tier) => r.bed_count_sum.toLocaleString('en-IN') },
            ]}
            emptyMessage="No data"
            rowKey={(r: Tier, i: number) => String(r.relationship_tier ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending action queue</h2>
        <p className="text-sm text-gray-600 mb-2">
          Cycles where approval &lt; closed or disbursement &lt; approved — oldest first.
        </p>
        <DataTable
          rows={pending}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Pending) => r.chain_name },
            { key: 'cycle_month', header: 'Month', render: (r: Pending) => String(r.cycle_month).slice(0, 7) },
            { key: 'approval_status', header: 'Status', render: (r: Pending) => r.approval_status },
            { key: 'proposed_amount_rupees', header: 'Proposed', render: (r: Pending) => rupees(r.proposed_amount_rupees) },
            { key: 'proposal_owner', header: 'Owner', render: (r: Pending) => r.proposal_owner },
            { key: 'finance_reviewer', header: 'Reviewer', render: (r: Pending) => r.finance_reviewer },
            { key: 'days_in_status', header: 'Days', render: (r: Pending) => String(r.days_in_status) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Pending, i: number) => String(i)}
        />
      </section>
    </div>
  );
}
