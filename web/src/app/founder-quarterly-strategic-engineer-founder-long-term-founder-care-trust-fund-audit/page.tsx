import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Period = {
  id: string;
  fiscal_quarter: string;
  fiscal_year: number;
  period_start: string;
  period_end: string;
  audit_status: string;
  trust_fund_balance_rupees: number;
  total_contributions_rupees: number;
  total_disbursements_rupees: number;
  engineer_count_covered: number;
  governance_tier: string;
  signed_off_at: string | null;
};

type LineItem = {
  id: string;
  engineer_name: string;
  care_category: string;
  flow_direction: string;
  amount_rupees: number;
  recipient_relationship: string | null;
  long_term_horizon_years: number | null;
  founder_approval_status: string;
  audit_red_flag: boolean;
  audit_note: string | null;
};

type Rollup = {
  fiscal_year: number;
  fiscal_quarter: string;
  audit_status: string;
  total_contributions_rupees: number;
  total_disbursements_rupees: number;
  net_change_rupees: number;
  balance_rupees: number;
};

type Category = {
  care_category: string;
  disbursement_count: number;
  total_amount_rupees: number;
  red_flag_count: number;
};

type Pending = {
  id: string;
  engineer_name: string;
  care_category: string;
  amount_rupees: number;
  founder_approval_status: string;
  audit_note: string | null;
};

type Governance = {
  governance_tier: string;
  period_count: number;
  total_balance_rupees: number;
  signed_off_count: number;
};

type RedFlag = {
  total_line_items: number;
  red_flag_items: number;
  total_amount_flagged_rupees: number;
  pending_count: number;
  escalated_count: number;
};

type Horizon = {
  horizon_bucket: string;
  item_count: number;
  total_amount_rupees: number;
};

function fmt(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [periods, lineItems, rollup, categories, pending, governance, redFlag, horizon] = await Promise.all([
    supabase.rpc('founder_trust_fund_list_periods_r3085'),
    supabase.rpc('founder_trust_fund_list_line_items_r3085'),
    supabase.rpc('founder_trust_fund_rollup_by_quarter_r3085'),
    supabase.rpc('founder_trust_fund_category_breakdown_r3085'),
    supabase.rpc('founder_trust_fund_pending_approvals_r3085'),
    supabase.rpc('founder_trust_fund_governance_rollup_r3085'),
    supabase.rpc('founder_trust_fund_red_flag_summary_r3085'),
    supabase.rpc('founder_trust_fund_horizon_distribution_r3085'),
  ]);

  const periodsData = (periods.data ?? []) as Period[];
  const lineItemsData = (lineItems.data ?? []) as LineItem[];
  const rollupData = (rollup.data ?? []) as Rollup[];
  const categoriesData = (categories.data ?? []) as Category[];
  const pendingData = (pending.data ?? []) as Pending[];
  const governanceData = (governance.data ?? []) as Governance[];
  const redFlagData = (redFlag.data ?? []) as RedFlag[];
  const horizonData = (horizon.data ?? []) as Horizon[];

  const periodCols: Column<Period>[] = [
    { header: 'FY', accessor: (r) => String(r.fiscal_year) },
    { header: 'Quarter', accessor: (r) => r.fiscal_quarter },
    { header: 'Start', accessor: (r) => r.period_start },
    { header: 'End', accessor: (r) => r.period_end },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Balance', accessor: (r) => fmt(r.trust_fund_balance_rupees) },
    { header: 'Contrib', accessor: (r) => fmt(r.total_contributions_rupees) },
    { header: 'Disburse', accessor: (r) => fmt(r.total_disbursements_rupees) },
    { header: 'Engineers', accessor: (r) => String(r.engineer_count_covered) },
    { header: 'Governance', accessor: (r) => r.governance_tier },
  ];

  const lineCols: Column<LineItem>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Category', accessor: (r) => r.care_category },
    { header: 'Flow', accessor: (r) => r.flow_direction },
    { header: 'Amount', accessor: (r) => fmt(r.amount_rupees) },
    { header: 'Recipient', accessor: (r) => r.recipient_relationship ?? '-' },
    { header: 'Horizon yrs', accessor: (r) => r.long_term_horizon_years == null ? '-' : String(r.long_term_horizon_years) },
    { header: 'Approval', accessor: (r) => r.founder_approval_status },
    { header: 'Red flag', accessor: (r) => r.audit_red_flag ? 'YES' : 'no' },
  ];

  const rollupCols: Column<Rollup>[] = [
    { header: 'FY', accessor: (r) => String(r.fiscal_year) },
    { header: 'Quarter', accessor: (r) => r.fiscal_quarter },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Contrib', accessor: (r) => fmt(r.total_contributions_rupees) },
    { header: 'Disburse', accessor: (r) => fmt(r.total_disbursements_rupees) },
    { header: 'Net change', accessor: (r) => fmt(r.net_change_rupees) },
    { header: 'Balance', accessor: (r) => fmt(r.balance_rupees) },
  ];

  const categoryCols: Column<Category>[] = [
    { header: 'Category', accessor: (r) => r.care_category },
    { header: 'Disbursements', accessor: (r) => String(r.disbursement_count) },
    { header: 'Total', accessor: (r) => fmt(r.total_amount_rupees) },
    { header: 'Red flags', accessor: (r) => String(r.red_flag_count) },
  ];

  const pendingCols: Column<Pending>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Category', accessor: (r) => r.care_category },
    { header: 'Amount', accessor: (r) => fmt(r.amount_rupees) },
    { header: 'Status', accessor: (r) => r.founder_approval_status },
    { header: 'Note', accessor: (r) => r.audit_note ?? '-' },
  ];

  const govCols: Column<Governance>[] = [
    { header: 'Tier', accessor: (r) => r.governance_tier },
    { header: 'Periods', accessor: (r) => String(r.period_count) },
    { header: 'Total balance', accessor: (r) => fmt(r.total_balance_rupees) },
    { header: 'Signed off', accessor: (r) => String(r.signed_off_count) },
  ];

  const redFlagCols: Column<RedFlag>[] = [
    { header: 'Total items', accessor: (r) => String(r.total_line_items) },
    { header: 'Red flags', accessor: (r) => String(r.red_flag_items) },
    { header: 'Flagged amount', accessor: (r) => fmt(r.total_amount_flagged_rupees) },
    { header: 'Pending', accessor: (r) => String(r.pending_count) },
    { header: 'Escalated', accessor: (r) => String(r.escalated_count) },
  ];

  const horizonCols: Column<Horizon>[] = [
    { header: 'Horizon', accessor: (r) => r.horizon_bucket },
    { header: 'Items', accessor: (r) => String(r.item_count) },
    { header: 'Total', accessor: (r) => fmt(r.total_amount_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Quarterly Strategic Engineer-Founder Long-Term Founder-Care Trust-Fund Audit</h1>
        <p className="text-sm text-gray-600">Round 3085 · quarterly audit of the engineer long-term care trust fund</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit Periods</h2>
        <DataTable
          rows={periodsData}
          columns={periodCols}
          emptyMessage="No audit periods."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Rollup</h2>
        <DataTable
          rows={rollupData}
          columns={rollupCols}
          emptyMessage="No rollup data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Line Items</h2>
        <DataTable
          rows={lineItemsData}
          columns={lineCols}
          emptyMessage="No line items."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Care Category Breakdown</h2>
        <DataTable
          rows={categoriesData}
          columns={categoryCols}
          emptyMessage="No categories."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending & Escalated Approvals</h2>
        <DataTable
          rows={pendingData}
          columns={pendingCols}
          emptyMessage="No pending approvals."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Governance Tier Rollup</h2>
        <DataTable
          rows={governanceData}
          columns={govCols}
          emptyMessage="No governance data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Red Flag Summary</h2>
        <DataTable
          rows={redFlagData}
          columns={redFlagCols}
          emptyMessage="No summary."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Long-Term Horizon Distribution</h2>
        <DataTable
          rows={horizonData}
          columns={horizonCols}
          emptyMessage="No horizon data."
          rowKey={(r, i) => String(i)}
        />
      </section>
    </div>
  );
}
