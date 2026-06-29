import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_lends: number;
  total_billed_rupees: number;
  pending_settlement_rupees: number;
  overdue_count: number;
  disputed_count: number;
  capex_deferred_rupees: number;
  avg_utilization_pct: number;
  chains_active: number;
};

type ChainRow = {
  chain_code: string;
  branches: number;
  total_lends: number;
  gross_billed_rupees: number;
  avg_util_pct: number;
  capex_deferred_rupees: number;
  disputes_open: number;
};

type BranchRow = {
  chain_code: string;
  branch_code: string;
  branch_city: string;
  utilization_pct: number;
  net_rental_income_rupees: number;
  net_rental_expense_rupees: number;
  net_position_rupees: number;
  capex_deferred_rupees: number;
};

type RiskRow = {
  id: string;
  chain_code: string;
  lender_branch_code: string;
  borrower_branch_code: string;
  equipment_category: string;
  settlement_status: string;
  expected_return_at: string;
  days_overdue: number;
  total_billed_rupees: number;
  damage_chargeback_rupees: number;
};

type CategoryRow = {
  equipment_category: string;
  lend_count: number;
  total_billed_rupees: number;
  avg_daily_rate: number;
};

type LedgerRow = {
  id: string;
  chain_code: string;
  lender_branch_code: string;
  borrower_branch_code: string;
  equipment_category: string;
  equipment_serial: string;
  lent_at: string;
  expected_return_at: string;
  actual_return_at: string | null;
  daily_rental_rupees: number;
  total_billed_rupees: number;
  settlement_status: string;
  damage_chargeback_rupees: number;
};

type ReciprocityRow = {
  branch_code: string;
  chain_code: string;
  lends_given: number;
  lends_received: number;
  reciprocity_ratio: number;
  net_position_rupees: number;
};

const inr = (n: number | null | undefined) =>
  n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

const pct = (n: number | null | undefined) =>
  n == null ? '-' : Number(n).toFixed(1) + '%';

const fmtDate = (s: string | null | undefined) =>
  !s ? '-' : new Date(s).toLocaleDateString('en-IN');

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpiRes, chainRes, branchRes, riskRes, catRes, ledgerRes, recipRes] =
    await Promise.all([
      sb.rpc('founder_r2887_kpi_summary'),
      sb.rpc('founder_r2887_chain_rollup'),
      sb.rpc('founder_r2887_branch_leaderboard'),
      sb.rpc('founder_r2887_risk_queue'),
      sb.rpc('founder_r2887_category_mix'),
      sb.rpc('founder_r2887_recent_ledger'),
      sb.rpc('founder_r2887_reciprocity_score'),
    ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const chains: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const branches: BranchRow[] = (branchRes.data as BranchRow[]) ?? [];
  const risks: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];
  const cats: CategoryRow[] = (catRes.data as CategoryRow[]) ?? [];
  const ledger: LedgerRow[] = (ledgerRes.data as LedgerRow[]) ?? [];
  const recip: ReciprocityRow[] = (recipRes.data as ReciprocityRow[]) ?? [];

  const chainCols = [
    { key: 'chain_code', header: 'Chain', render: (r: ChainRow) => r.chain_code },
    { key: 'branches', header: 'Branches', render: (r: ChainRow) => r.branches },
    { key: 'lends', header: 'Lends', render: (r: ChainRow) => r.total_lends },
    { key: 'billed', header: 'Gross Billed', render: (r: ChainRow) => inr(r.gross_billed_rupees) },
    { key: 'util', header: 'Avg Util', render: (r: ChainRow) => pct(r.avg_util_pct) },
    { key: 'capex', header: 'Capex Deferred', render: (r: ChainRow) => inr(r.capex_deferred_rupees) },
    { key: 'disp', header: 'Disputes', render: (r: ChainRow) => r.disputes_open },
  ];

  const branchCols = [
    { key: 'chain', header: 'Chain', render: (r: BranchRow) => r.chain_code },
    { key: 'br', header: 'Branch', render: (r: BranchRow) => r.branch_code },
    { key: 'city', header: 'City', render: (r: BranchRow) => r.branch_city },
    { key: 'util', header: 'Util', render: (r: BranchRow) => pct(r.utilization_pct) },
    { key: 'inc', header: 'Rental Income', render: (r: BranchRow) => inr(r.net_rental_income_rupees) },
    { key: 'exp', header: 'Rental Expense', render: (r: BranchRow) => inr(r.net_rental_expense_rupees) },
    { key: 'net', header: 'Net Position', render: (r: BranchRow) => inr(r.net_position_rupees) },
    { key: 'capex', header: 'Capex Deferred', render: (r: BranchRow) => inr(r.capex_deferred_rupees) },
  ];

  const riskCols = [
    { key: 'chain', header: 'Chain', render: (r: RiskRow) => r.chain_code },
    { key: 'lend', header: 'Lender', render: (r: RiskRow) => r.lender_branch_code },
    { key: 'borr', header: 'Borrower', render: (r: RiskRow) => r.borrower_branch_code },
    { key: 'cat', header: 'Equipment', render: (r: RiskRow) => r.equipment_category },
    { key: 'st', header: 'Status', render: (r: RiskRow) => r.settlement_status },
    { key: 'eret', header: 'Expected Return', render: (r: RiskRow) => fmtDate(r.expected_return_at) },
    { key: 'over', header: 'Days Overdue', render: (r: RiskRow) => r.days_overdue },
    { key: 'bill', header: 'Billed', render: (r: RiskRow) => inr(r.total_billed_rupees) },
    { key: 'dmg', header: 'Chargeback', render: (r: RiskRow) => inr(r.damage_chargeback_rupees) },
  ];

  const catCols = [
    { key: 'cat', header: 'Category', render: (r: CategoryRow) => r.equipment_category },
    { key: 'n', header: 'Lends', render: (r: CategoryRow) => r.lend_count },
    { key: 'bill', header: 'Billed', render: (r: CategoryRow) => inr(r.total_billed_rupees) },
    { key: 'rate', header: 'Avg Daily Rate', render: (r: CategoryRow) => inr(Math.round(r.avg_daily_rate)) },
  ];

  const ledgerCols = [
    { key: 'chain', header: 'Chain', render: (r: LedgerRow) => r.chain_code },
    { key: 'lend', header: 'Lender', render: (r: LedgerRow) => r.lender_branch_code },
    { key: 'borr', header: 'Borrower', render: (r: LedgerRow) => r.borrower_branch_code },
    { key: 'cat', header: 'Equipment', render: (r: LedgerRow) => r.equipment_category },
    { key: 'sn', header: 'Serial', render: (r: LedgerRow) => r.equipment_serial },
    { key: 'lent', header: 'Lent', render: (r: LedgerRow) => fmtDate(r.lent_at) },
    { key: 'er', header: 'Exp. Return', render: (r: LedgerRow) => fmtDate(r.expected_return_at) },
    { key: 'ar', header: 'Actual Return', render: (r: LedgerRow) => fmtDate(r.actual_return_at) },
    { key: 'dr', header: 'Daily', render: (r: LedgerRow) => inr(r.daily_rental_rupees) },
    { key: 'tot', header: 'Total Billed', render: (r: LedgerRow) => inr(r.total_billed_rupees) },
    { key: 'st', header: 'Status', render: (r: LedgerRow) => r.settlement_status },
  ];

  const recipCols = [
    { key: 'br', header: 'Branch', render: (r: ReciprocityRow) => r.branch_code },
    { key: 'chain', header: 'Chain', render: (r: ReciprocityRow) => r.chain_code },
    { key: 'g', header: 'Lends Given', render: (r: ReciprocityRow) => r.lends_given },
    { key: 'r', header: 'Lends Received', render: (r: ReciprocityRow) => r.lends_received },
    { key: 'rat', header: 'Ratio (give/take)', render: (r: ReciprocityRow) => Number(r.reciprocity_ratio).toFixed(2) },
    { key: 'net', header: 'Net Position', render: (r: ReciprocityRow) => inr(r.net_position_rupees) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Hospital Chain Quarterly Cross-Branch Equipment Lending Ledger
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Multi-branch hospital chains lend high-value equipment across sister
          branches to absorb downtime and defer capex. This founder console
          rolls up the quarterly ledger — gross billings, settlement
          status, utilization, reciprocity, and chargeback risk — across
          all chains on EquipSeva.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Total Lends" value={kpi?.total_lends ?? 0} />
        <KpiCard label="Gross Billed" value={inr(kpi?.total_billed_rupees ?? 0)} />
        <KpiCard label="Pending Settlement" value={inr(kpi?.pending_settlement_rupees ?? 0)} />
        <KpiCard label="Overdue" value={kpi?.overdue_count ?? 0} accent="#c0392b" />
        <KpiCard label="Disputed" value={kpi?.disputed_count ?? 0} accent="#d68910" />
        <KpiCard label="Capex Deferred" value={inr(kpi?.capex_deferred_rupees ?? 0)} accent="#1e8449" />
        <KpiCard label="Avg Utilization" value={pct(kpi?.avg_utilization_pct ?? 0)} />
        <KpiCard label="Chains Active" value={kpi?.chains_active ?? 0} />
      </section>

      <Section title="Chain Rollup">
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chains yet"
          rowKey={(r, i) => String((r as ChainRow).chain_code ?? i)}
        />
      </Section>

      <Section title="Branch Leaderboard (net position this quarter)">
        <DataTable
          rows={branches}
          columns={branchCols}
          emptyMessage="No branches yet"
          rowKey={(r, i) => String((r as BranchRow).branch_code ?? i)}
        />
      </Section>

      <Section title="Risk Queue (overdue / disputed / unsettled)">
        <DataTable
          rows={risks}
          columns={riskCols}
          emptyMessage="No risk items — all settled"
          rowKey={(r, i) => String((r as RiskRow).id ?? i)}
        />
      </Section>

      <Section title="Equipment Category Mix">
        <DataTable
          rows={cats}
          columns={catCols}
          emptyMessage="No categories"
          rowKey={(r, i) => String((r as CategoryRow).equipment_category ?? i)}
        />
      </Section>

      <Section title="Reciprocity Score (give vs take)">
        <DataTable
          rows={recip}
          columns={recipCols}
          emptyMessage="No branches"
          rowKey={(r, i) => String((r as ReciprocityRow).branch_code ?? i)}
        />
      </Section>

      <Section title="Recent Lending Ledger (last 50)">
        <DataTable
          rows={ledger}
          columns={ledgerCols}
          emptyMessage="No lending activity"
          rowKey={(r, i) => String((r as LedgerRow).id ?? i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string | number; accent?: string }) {
  return (
    <div style={{
      border: '1px solid #e5e7eb',
      borderRadius: 10,
      padding: 14,
      background: '#fff',
      borderLeft: '4px solid ' + (accent ?? '#2563eb'),
    }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
